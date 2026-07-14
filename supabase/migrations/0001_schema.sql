-- ============================================================
-- MokuTomo schema
-- すべての日時はUTC(timestamptz)。表示時にprofiles.timezoneで変換する。
-- ============================================================

create extension if not exists pgcrypto;

-- ---------- 共通: updated_at 自動更新 ----------
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------- profiles ----------
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '名無しさん' check (char_length(display_name) between 1 and 30),
  avatar_url text,
  study_purpose text check (study_purpose in ('exam','certification','school','work','habit','other')),
  timezone text not null default 'Asia/Tokyo',
  role text not null default 'user' check (role in ('user','admin')),
  status text not null default 'active' check (status in ('active','suspended','deleted')),
  onboarding_completed_at timestamptz,
  terms_accepted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index profiles_role_idx on public.profiles(role);
create index profiles_status_idx on public.profiles(status);
create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

-- 一般ユーザーが自分のrole/statusを書き換えるのを防ぐ(RLSのUPDATE許可とは別の防衛線)
create or replace function public.protect_profile_columns()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (new.role is distinct from old.role or new.status is distinct from old.status) then
    if not exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'admin'
    ) and auth.uid() is not null then
      raise exception 'role/status cannot be changed by the user';
    end if;
  end if;
  return new;
end;
$$;
create trigger profiles_protect_columns before update on public.profiles
  for each row execute function public.protect_profile_columns();

-- ---------- user_stats (改ざん防止のため分離。書込はRPCのみ) ----------
create table public.user_stats (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  xp integer not null default 0,
  level integer not null default 1,
  current_streak integer not null default 0,
  longest_streak integer not null default 0,
  last_study_date date,
  total_focus_minutes integer not null default 0,
  total_completed_sessions integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger user_stats_updated_at before update on public.user_stats
  for each row execute function public.set_updated_at();

-- ---------- study_goals ----------
create table public.study_goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.profiles(id) on delete cascade,
  daily_minutes_goal integer not null default 50 check (daily_minutes_goal between 0 and 1440),
  weekly_minutes_goal integer not null default 300 check (weekly_minutes_goal between 0 and 10080),
  monthly_minutes_goal integer not null default 1200 check (monthly_minutes_goal between 0 and 44640),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger study_goals_updated_at before update on public.study_goals
  for each row execute function public.set_updated_at();

-- ---------- study_rooms ----------
create table public.study_rooms (
  id uuid primary key default gen_random_uuid(),
  status text not null default 'waiting' check (status in ('waiting','active','finished')),
  duration_minutes integer not null check (duration_minutes in (5,15,25,50)),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  max_participants integer not null default 6 check (max_participants between 2 and 6),
  is_trial boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index study_rooms_open_idx on public.study_rooms(status, duration_minutes, ends_at);
create trigger study_rooms_updated_at before update on public.study_rooms
  for each row execute function public.set_updated_at();

-- ---------- study_sessions ----------
create table public.study_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  room_id uuid references public.study_rooms(id) on delete set null,
  topic text not null default '' check (char_length(topic) <= 100),
  planned_minutes integer not null check (planned_minutes in (5,15,25,50)),
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  attended_seconds integer not null default 0,
  status text not null default 'active' check (status in ('active','completed','left_early','abandoned')),
  rating text check (rating in ('focused','normal','distracted')),
  memo text check (char_length(memo) <= 500),
  xp_awarded integer not null default 0,
  is_trial boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index study_sessions_user_started_idx on public.study_sessions(user_id, started_at desc);
create index study_sessions_room_idx on public.study_sessions(room_id);
-- 多重入室防止: activeなセッションはユーザーごとに1つ
create unique index study_sessions_one_active_per_user
  on public.study_sessions(user_id) where (status = 'active');
create trigger study_sessions_updated_at before update on public.study_sessions
  for each row execute function public.set_updated_at();

-- ---------- room_participants ----------
create table public.room_participants (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.study_rooms(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  session_id uuid references public.study_sessions(id) on delete set null,
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  camera_on boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (room_id, user_id)
);
create index room_participants_room_idx on public.room_participants(room_id);
create index room_participants_user_idx on public.room_participants(user_id);
create trigger room_participants_updated_at before update on public.room_participants
  for each row execute function public.set_updated_at();

-- ---------- reservations ----------
create table public.reservations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  starts_at timestamptz not null,
  duration_minutes integer not null check (duration_minutes in (5,15,25,50)),
  topic text not null default '' check (char_length(topic) <= 100),
  status text not null default 'scheduled' check (status in ('scheduled','completed','missed','cancelled')),
  recurring_reservation_id uuid,
  session_id uuid references public.study_sessions(id) on delete set null,
  notified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index reservations_user_starts_idx on public.reservations(user_id, starts_at);
create index reservations_status_idx on public.reservations(status, starts_at);
create trigger reservations_updated_at before update on public.reservations
  for each row execute function public.set_updated_at();

-- ---------- recurring_reservations ----------
create table public.recurring_reservations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  weekday integer not null check (weekday between 0 and 6), -- 0=日曜
  start_time time not null,
  timezone text not null default 'Asia/Tokyo',
  duration_minutes integer not null check (duration_minutes in (5,15,25,50)),
  topic text not null default '' check (char_length(topic) <= 100),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index recurring_reservations_user_idx on public.recurring_reservations(user_id);
create trigger recurring_reservations_updated_at before update on public.recurring_reservations
  for each row execute function public.set_updated_at();

alter table public.reservations
  add constraint reservations_recurring_fk
  foreign key (recurring_reservation_id) references public.recurring_reservations(id) on delete set null;

-- ---------- achievements (マスタ) ----------
create table public.achievements (
  id text primary key, -- slug
  name text not null,
  description text not null,
  condition_type text not null check (condition_type in ('first_session','completed_sessions','streak_days','weekly_goal','monthly_goal')),
  condition_value integer not null default 1,
  icon text not null default 'award',
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger achievements_updated_at before update on public.achievements
  for each row execute function public.set_updated_at();

-- ---------- user_achievements ----------
create table public.user_achievements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  achievement_id text not null references public.achievements(id) on delete cascade,
  earned_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (user_id, achievement_id)
);
create index user_achievements_user_idx on public.user_achievements(user_id);

-- ---------- supporters ----------
create table public.supporters (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  supporter_email text not null check (char_length(supporter_email) <= 254),
  supporter_name text not null default '' check (char_length(supporter_name) <= 50),
  status text not null default 'pending' check (status in ('pending','accepted','stopped')),
  invite_token uuid not null unique default gen_random_uuid(),
  consented_at timestamptz,
  notify_on_start boolean not null default true,
  notify_on_complete boolean not null default true,
  weekly_report boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, supporter_email)
);
create index supporters_user_idx on public.supporters(user_id);
create trigger supporters_updated_at before update on public.supporters
  for each row execute function public.set_updated_at();

-- ---------- supporter_notifications ----------
create table public.supporter_notifications (
  id uuid primary key default gen_random_uuid(),
  supporter_id uuid not null references public.supporters(id) on delete cascade,
  type text not null check (type in ('invite','session_start','session_complete','weekly_report')),
  channel text not null default 'email' check (channel in ('email','line')), -- lineは正式版
  payload jsonb not null default '{}',
  sent_at timestamptz,
  created_at timestamptz not null default now()
);
create index supporter_notifications_supporter_idx on public.supporter_notifications(supporter_id);

-- ---------- subscriptions ----------
create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.profiles(id) on delete cascade,
  plan text not null default 'free' check (plan in ('free','premium')),
  stripe_customer_id text,
  stripe_subscription_id text,
  status text not null default 'active' check (status in ('active','past_due','canceled','trialing')),
  current_period_end timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index subscriptions_stripe_customer_idx on public.subscriptions(stripe_customer_id);
create trigger subscriptions_updated_at before update on public.subscriptions
  for each row execute function public.set_updated_at();

-- ---------- reports ----------
create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reported_user_id uuid not null references public.profiles(id) on delete cascade,
  room_id uuid references public.study_rooms(id) on delete set null,
  category text not null check (category in ('inappropriate_behavior','camera_misuse','impersonation','harassment','other')),
  description text not null default '' check (char_length(description) <= 1000),
  status text not null default 'open' check (status in ('open','reviewing','resolved','dismissed')),
  resolved_by uuid references public.profiles(id) on delete set null,
  resolution_note text check (char_length(resolution_note) <= 1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index reports_status_idx on public.reports(status, created_at desc);
create index reports_reported_user_idx on public.reports(reported_user_id);
create trigger reports_updated_at before update on public.reports
  for each row execute function public.set_updated_at();

-- ---------- blocked_users ----------
create table public.blocked_users (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  blocked_user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, blocked_user_id),
  check (user_id <> blocked_user_id)
);
create index blocked_users_user_idx on public.blocked_users(user_id);

-- ---------- announcements ----------
create table public.announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) <= 100),
  body text not null check (char_length(body) <= 4000),
  is_published boolean not null default false,
  published_at timestamptz,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index announcements_published_idx on public.announcements(is_published, published_at desc);
create trigger announcements_updated_at before update on public.announcements
  for each row execute function public.set_updated_at();

-- ---------- notification_settings ----------
create table public.notification_settings (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  browser_reservation boolean not null default true,
  email_reservation boolean not null default false,
  email_weekly_summary boolean not null default false,
  sound_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger notification_settings_updated_at before update on public.notification_settings
  for each row execute function public.set_updated_at();

-- ---------- admin_audit_logs ----------
create table public.admin_audit_logs (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid references public.profiles(id) on delete set null,
  action text not null,
  target_type text not null,
  target_id text,
  detail jsonb not null default '{}',
  created_at timestamptz not null default now()
);
create index admin_audit_logs_created_idx on public.admin_audit_logs(created_at desc);

-- ---------- contact_messages ----------
create table public.contact_messages (
  id uuid primary key default gen_random_uuid(),
  name text not null default '' check (char_length(name) <= 50),
  email text not null check (char_length(email) <= 254),
  message text not null check (char_length(message) between 1 and 2000),
  status text not null default 'open' check (status in ('open','closed')),
  created_at timestamptz not null default now()
);

-- ---------- 新規ユーザー作成時の初期化 ----------
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name, terms_accepted_at)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data->>'display_name',''), '名無しさん'),
    case when (new.raw_user_meta_data->>'terms_accepted') = 'true' then now() else null end
  );
  insert into public.user_stats (user_id) values (new.id);
  insert into public.study_goals (user_id) values (new.id);
  insert into public.notification_settings (user_id) values (new.id);
  insert into public.subscriptions (user_id) values (new.id);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
