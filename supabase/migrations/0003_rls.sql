-- ============================================================
-- MokuTomo Row Level Security
-- 原則: 本人の行のみ。集計値・記録系はRPC(SECURITY DEFINER)経由でのみ書込。
-- ============================================================

alter table public.profiles enable row level security;
alter table public.user_stats enable row level security;
alter table public.study_goals enable row level security;
alter table public.study_rooms enable row level security;
alter table public.study_sessions enable row level security;
alter table public.room_participants enable row level security;
alter table public.reservations enable row level security;
alter table public.recurring_reservations enable row level security;
alter table public.achievements enable row level security;
alter table public.user_achievements enable row level security;
alter table public.supporters enable row level security;
alter table public.supporter_notifications enable row level security;
alter table public.subscriptions enable row level security;
alter table public.reports enable row level security;
alter table public.blocked_users enable row level security;
alter table public.announcements enable row level security;
alter table public.notification_settings enable row level security;
alter table public.admin_audit_logs enable row level security;
alter table public.contact_messages enable row level security;

-- ---------- profiles ----------
create policy "profiles: self select" on public.profiles
  for select to authenticated using (id = auth.uid() or public.is_admin());
create policy "profiles: self update" on public.profiles
  for update to authenticated using (id = auth.uid() or public.is_admin())
  with check (id = auth.uid() or public.is_admin());
-- INSERTはauthトリガ(definer)のみ / DELETEはauth.users削除のCASCADEのみ

-- ---------- user_stats (書込はRPCのみ) ----------
create policy "user_stats: self select" on public.user_stats
  for select to authenticated using (user_id = auth.uid() or public.is_admin());

-- ---------- study_goals ----------
create policy "study_goals: self all" on public.study_goals
  for all to authenticated using (user_id = auth.uid())
  with check (user_id = auth.uid());
create policy "study_goals: admin select" on public.study_goals
  for select to authenticated using (public.is_admin());

-- ---------- study_rooms (参加した部屋のみ閲覧可。作成/更新はRPC) ----------
create policy "study_rooms: participant select" on public.study_rooms
  for select to authenticated using (
    public.is_admin() or exists (
      select 1 from public.room_participants rp
      where rp.room_id = study_rooms.id and rp.user_id = auth.uid()
    )
  );

-- ---------- study_sessions (書込はRPCのみ) ----------
create policy "study_sessions: self select" on public.study_sessions
  for select to authenticated using (user_id = auth.uid() or public.is_admin());

-- ---------- room_participants (同室の行は閲覧可。書込はRPCのみ) ----------
create policy "room_participants: room member select" on public.room_participants
  for select to authenticated using (
    public.is_admin()
    or user_id = auth.uid()
    or exists (
      select 1 from public.room_participants me
      where me.room_id = room_participants.room_id and me.user_id = auth.uid()
    )
  );

-- ---------- reservations ----------
create policy "reservations: self all" on public.reservations
  for all to authenticated using (user_id = auth.uid())
  with check (user_id = auth.uid());
create policy "reservations: admin select" on public.reservations
  for select to authenticated using (public.is_admin());

-- ---------- recurring_reservations ----------
create policy "recurring_reservations: self all" on public.recurring_reservations
  for all to authenticated using (user_id = auth.uid())
  with check (user_id = auth.uid());
create policy "recurring_reservations: admin select" on public.recurring_reservations
  for select to authenticated using (public.is_admin());

-- ---------- achievements (マスタ: 全員閲覧可) ----------
create policy "achievements: read all" on public.achievements
  for select to authenticated using (true);

-- ---------- user_achievements (付与はRPCのみ) ----------
create policy "user_achievements: self select" on public.user_achievements
  for select to authenticated using (user_id = auth.uid() or public.is_admin());

-- ---------- supporters ----------
create policy "supporters: self all" on public.supporters
  for all to authenticated using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ---------- supporter_notifications ----------
create policy "supporter_notifications: owner select" on public.supporter_notifications
  for select to authenticated using (
    public.is_admin() or exists (
      select 1 from public.supporters s
      where s.id = supporter_notifications.supporter_id and s.user_id = auth.uid()
    )
  );

-- ---------- subscriptions (変更はStripe Webhook = service role のみ) ----------
create policy "subscriptions: self select" on public.subscriptions
  for select to authenticated using (user_id = auth.uid() or public.is_admin());

-- ---------- reports (作成はRPC経由。自分の通報のみ閲覧可) ----------
create policy "reports: reporter select" on public.reports
  for select to authenticated using (reporter_id = auth.uid() or public.is_admin());
create policy "reports: admin update" on public.reports
  for update to authenticated using (public.is_admin()) with check (public.is_admin());

-- ---------- blocked_users ----------
create policy "blocked_users: self all" on public.blocked_users
  for all to authenticated using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ---------- announcements ----------
create policy "announcements: published read" on public.announcements
  for select to authenticated using (is_published = true or public.is_admin());
create policy "announcements: admin write" on public.announcements
  for insert to authenticated with check (public.is_admin());
create policy "announcements: admin update" on public.announcements
  for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "announcements: admin delete" on public.announcements
  for delete to authenticated using (public.is_admin());

-- ---------- notification_settings ----------
create policy "notification_settings: self all" on public.notification_settings
  for all to authenticated using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ---------- admin_audit_logs (閲覧は管理者のみ。書込はRPC) ----------
create policy "admin_audit_logs: admin select" on public.admin_audit_logs
  for select to authenticated using (public.is_admin());

-- ---------- contact_messages (誰でも投稿可、閲覧は管理者のみ) ----------
create policy "contact_messages: anyone insert" on public.contact_messages
  for insert to anon, authenticated with check (true);
create policy "contact_messages: admin select" on public.contact_messages
  for select to authenticated using (public.is_admin());
create policy "contact_messages: admin update" on public.contact_messages
  for update to authenticated using (public.is_admin()) with check (public.is_admin());

-- ============================================================
-- Supabase Realtime 認可 (privateチャネル)
-- topic 'room:<room_id>' は、そのルームの参加者のみ送受信できる
-- ============================================================
create policy "room members can receive broadcasts"
  on realtime.messages for select to authenticated
  using (
    exists (
      select 1 from public.room_participants rp
      where rp.user_id = auth.uid()
        and rp.left_at is null
        and realtime.topic() = 'room:' || rp.room_id::text
    )
  );

create policy "room members can send broadcasts"
  on realtime.messages for insert to authenticated
  with check (
    exists (
      select 1 from public.room_participants rp
      where rp.user_id = auth.uid()
        and rp.left_at is null
        and realtime.topic() = 'room:' || rp.room_id::text
    )
  );
