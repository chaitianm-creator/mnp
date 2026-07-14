-- ============================================================
-- MokuTomo RPC関数
-- 記録・XP・部屋割当はすべてサーバー側(SECURITY DEFINER)で行い、
-- クライアントから数値を直接書き込ませない。
-- ============================================================

-- ---------- 管理者判定 ----------
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin' and status = 'active'
  );
$$;

-- ---------- サーバー時刻 (タイマー同期の基準) ----------
create or replace function public.get_server_time()
returns timestamptz language sql stable as $$
  select now();
$$;

-- ---------- 現在自習中の人数 ----------
create or replace function public.current_studying_count()
returns integer language sql stable security definer set search_path = public as $$
  select count(distinct rp.user_id)::integer
  from public.room_participants rp
  join public.study_rooms r on r.id = rp.room_id
  where rp.left_at is null
    and r.status in ('waiting','active')
    and r.ends_at > now();
$$;

-- ---------- XP→レベル計算 ----------
create or replace function public.level_for_xp(p_xp integer)
returns integer language sql immutable as $$
  select floor(sqrt(greatest(p_xp, 0) / 50.0))::integer + 1;
$$;

-- ---------- 期限切れルームのクローズ ----------
create or replace function public.close_expired_rooms()
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.study_rooms
  set status = 'finished'
  where status in ('waiting','active') and ends_at < now();

  update public.study_rooms
  set status = 'active'
  where status = 'waiting' and starts_at <= now() and ends_at >= now();

  -- 終了したルームに残っているactiveセッションを打ち切る(リロードせず閉じた等)
  update public.study_sessions s
  set status = 'abandoned',
      ended_at = r.ends_at,
      attended_seconds = greatest(0, extract(epoch from (r.ends_at - greatest(s.started_at, r.starts_at)))::integer)
  from public.study_rooms r
  where s.room_id = r.id
    and s.status = 'active'
    and r.ends_at < now() - interval '10 minutes';

  update public.room_participants rp
  set left_at = r.ends_at
  from public.study_rooms r
  where rp.room_id = r.id and rp.left_at is null and r.ends_at < now() - interval '10 minutes';
end;
$$;

-- ---------- 入室 (部屋の自動割当) ----------
create or replace function public.join_room(
  p_topic text default '',
  p_duration integer default 25,
  p_is_trial boolean default false
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_profile public.profiles%rowtype;
  v_plan text;
  v_today_count integer;
  v_room public.study_rooms%rowtype;
  v_session public.study_sessions%rowtype;
  v_active public.study_sessions%rowtype;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  select * into v_profile from public.profiles where id = v_uid;
  if v_profile.status <> 'active' then
    raise exception 'account_suspended';
  end if;
  if p_duration not in (5,15,25,50) then
    raise exception 'invalid_duration';
  end if;

  perform public.close_expired_rooms();

  -- 既にactiveなセッションがあれば同じ部屋へ再入室(リロード/再接続対応)
  select s.* into v_active
  from public.study_sessions s
  join public.study_rooms r on r.id = s.room_id
  where s.user_id = v_uid and s.status = 'active' and r.ends_at > now()
  limit 1;
  if found then
    update public.room_participants
      set left_at = null
      where room_id = v_active.room_id and user_id = v_uid;
    select * into v_room from public.study_rooms where id = v_active.room_id;
    return jsonb_build_object(
      'room_id', v_room.id, 'session_id', v_active.id,
      'starts_at', v_room.starts_at, 'ends_at', v_room.ends_at,
      'duration_minutes', v_room.duration_minutes, 'rejoined', true
    );
  end if;

  -- 終わった部屋に紐づくactiveセッションが残っていれば打ち切る
  update public.study_sessions set status = 'abandoned', ended_at = now()
  where user_id = v_uid and status = 'active';

  -- 無料プランは1日2コマ(入室回数)まで。体験セッションは対象外
  if not p_is_trial then
    select plan into v_plan from public.subscriptions where user_id = v_uid;
    if coalesce(v_plan, 'free') = 'free' then
      select count(*) into v_today_count
      from public.study_sessions
      where user_id = v_uid
        and is_trial = false
        and (started_at at time zone v_profile.timezone)::date
            = (now() at time zone v_profile.timezone)::date;
      if v_today_count >= 2 then
        raise exception 'free_plan_daily_limit';
      end if;
    end if;
  end if;

  -- 空き部屋を探す(開始5分以内・ブロック関係のユーザーがいない部屋)
  select r.* into v_room
  from public.study_rooms r
  where r.status in ('waiting','active')
    and r.is_trial = p_is_trial
    and r.duration_minutes = p_duration
    and r.ends_at > now() + interval '2 minutes'
    and r.starts_at > now() - interval '5 minutes'
    and (
      select count(*) from public.room_participants rp
      where rp.room_id = r.id and rp.left_at is null
    ) < r.max_participants
    and not exists (
      select 1
      from public.room_participants rp
      join public.blocked_users b
        on (b.user_id = v_uid and b.blocked_user_id = rp.user_id)
        or (b.blocked_user_id = v_uid and b.user_id = rp.user_id)
      where rp.room_id = r.id and rp.left_at is null
    )
  order by r.starts_at asc
  limit 1
  for update of r skip locked;

  if not found then
    insert into public.study_rooms (status, duration_minutes, starts_at, ends_at, max_participants, is_trial)
    values (
      'waiting', p_duration,
      now() + interval '30 seconds',
      now() + interval '30 seconds' + make_interval(mins => p_duration),
      6, p_is_trial
    )
    returning * into v_room;
  end if;

  insert into public.study_sessions (user_id, room_id, topic, planned_minutes, started_at, is_trial)
  values (v_uid, v_room.id, coalesce(p_topic,''), p_duration, now(), p_is_trial)
  returning * into v_session;

  insert into public.room_participants (room_id, user_id, session_id, joined_at, left_at)
  values (v_room.id, v_uid, v_session.id, now(), null)
  on conflict (room_id, user_id)
  do update set left_at = null, session_id = excluded.session_id, joined_at = now();

  return jsonb_build_object(
    'room_id', v_room.id, 'session_id', v_session.id,
    'starts_at', v_room.starts_at, 'ends_at', v_room.ends_at,
    'duration_minutes', v_room.duration_minutes, 'rejoined', false
  );
end;
$$;

-- ---------- 同室メンバー取得 (表示名・学習内容のみを公開) ----------
create or replace function public.get_room_members(p_room_id uuid)
returns table (
  user_id uuid,
  display_name text,
  topic text,
  camera_on boolean,
  joined_at timestamptz,
  left_at timestamptz
) language plpgsql stable security definer set search_path = public as $$
begin
  if not exists (
    select 1 from public.room_participants
    where room_id = p_room_id and room_participants.user_id = auth.uid()
  ) and not public.is_admin() then
    raise exception 'not_a_room_member';
  end if;

  return query
  select rp.user_id, p.display_name, coalesce(s.topic, ''), rp.camera_on, rp.joined_at, rp.left_at
  from public.room_participants rp
  join public.profiles p on p.id = rp.user_id
  left join public.study_sessions s on s.id = rp.session_id
  where rp.room_id = p_room_id;
end;
$$;

-- ---------- カメラON/OFF状態の更新 ----------
create or replace function public.set_camera_state(p_room_id uuid, p_camera_on boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.room_participants
  set camera_on = p_camera_on
  where room_id = p_room_id and user_id = auth.uid();
end;
$$;

-- ---------- 途中退出 ----------
create or replace function public.leave_session(p_session_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_session public.study_sessions%rowtype;
  v_room public.study_rooms%rowtype;
  v_attended integer;
begin
  select * into v_session from public.study_sessions
  where id = p_session_id and user_id = v_uid and status = 'active'
  for update;
  if not found then
    raise exception 'session_not_found';
  end if;

  select * into v_room from public.study_rooms where id = v_session.room_id;
  v_attended := greatest(0, extract(epoch from (
    least(now(), v_room.ends_at) - greatest(v_session.started_at, v_room.starts_at)
  ))::integer);

  update public.study_sessions
  set status = 'left_early', ended_at = now(), attended_seconds = v_attended
  where id = p_session_id;

  update public.room_participants
  set left_at = now()
  where room_id = v_session.room_id and user_id = v_uid;

  return jsonb_build_object('attended_seconds', v_attended);
end;
$$;

-- ---------- 実績付与(内部用) ----------
create or replace function public.award_achievements(p_user_id uuid)
returns setof text language plpgsql security definer set search_path = public as $$
declare
  v_stats public.user_stats%rowtype;
  v_a record;
begin
  select * into v_stats from public.user_stats where user_id = p_user_id;
  for v_a in select * from public.achievements loop
    if (v_a.condition_type = 'first_session' and v_stats.total_completed_sessions >= 1)
      or (v_a.condition_type = 'completed_sessions' and v_stats.total_completed_sessions >= v_a.condition_value)
      or (v_a.condition_type = 'streak_days' and v_stats.current_streak >= v_a.condition_value)
    then
      begin
        insert into public.user_achievements (user_id, achievement_id)
        values (p_user_id, v_a.id);
        return next v_a.id;
      exception when unique_violation then
        -- 既に獲得済み
        null;
      end;
    end if;
  end loop;
  return;
end;
$$;

-- ---------- セッション完了 ----------
create or replace function public.finish_session(
  p_session_id uuid,
  p_rating text default null,
  p_memo text default null
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_session public.study_sessions%rowtype;
  v_room public.study_rooms%rowtype;
  v_attended integer;
  v_xp integer := 0;
  v_minutes integer;
  v_today_local date;
  v_new_achievements text[];
  v_stats public.user_stats%rowtype;
  v_tz text;
begin
  select * into v_session from public.study_sessions
  where id = p_session_id and user_id = v_uid
  for update;
  if not found then
    raise exception 'session_not_found';
  end if;
  if v_session.status <> 'active' then
    raise exception 'session_already_finished';
  end if;

  select * into v_room from public.study_rooms where id = v_session.room_id;

  -- サーバー時刻で完了を検証(30秒の猶予)。早すぎる完了要求は拒否
  if now() < v_room.ends_at - interval '30 seconds' then
    raise exception 'session_not_finished_yet';
  end if;

  v_attended := greatest(0, extract(epoch from (
    v_room.ends_at - greatest(v_session.started_at, v_room.starts_at)
  ))::integer);
  v_minutes := floor(v_attended / 60.0)::integer;

  if not v_session.is_trial then
    v_xp := v_minutes * 2 + 10;
  end if;

  update public.study_sessions
  set status = 'completed',
      ended_at = v_room.ends_at,
      attended_seconds = v_attended,
      rating = p_rating,
      memo = left(coalesce(p_memo,''), 500),
      xp_awarded = v_xp
  where id = p_session_id;

  update public.room_participants
  set left_at = v_room.ends_at
  where room_id = v_session.room_id and user_id = v_uid;

  -- 統計・連続日数の更新(体験セッションは対象外)
  if not v_session.is_trial then
    select timezone into v_tz from public.profiles where id = v_uid;
    v_today_local := (now() at time zone coalesce(v_tz, 'Asia/Tokyo'))::date;

    update public.user_stats
    set xp = xp + v_xp,
        level = public.level_for_xp(xp + v_xp),
        total_focus_minutes = total_focus_minutes + v_minutes,
        total_completed_sessions = total_completed_sessions + 1,
        current_streak = case
          when last_study_date = v_today_local then current_streak
          when last_study_date = v_today_local - 1 then current_streak + 1
          else 1
        end,
        longest_streak = greatest(longest_streak, case
          when last_study_date = v_today_local then current_streak
          when last_study_date = v_today_local - 1 then current_streak + 1
          else 1
        end),
        last_study_date = v_today_local
    where user_id = v_uid;

    -- 予約からの入室なら予約を完了扱いに
    update public.reservations
    set status = 'completed', session_id = p_session_id
    where user_id = v_uid and status = 'scheduled'
      and starts_at between v_room.starts_at - interval '30 minutes' and v_room.ends_at;

    select array_agg(a) into v_new_achievements from public.award_achievements(v_uid) a;

    -- 応援者通知をキューに追加(送信はサーバーのAPIルートが行う)
    insert into public.supporter_notifications (supporter_id, type, payload)
    select sp.id, 'session_complete',
           jsonb_build_object('minutes', v_minutes, 'topic', v_session.topic)
    from public.supporters sp
    join public.subscriptions sub on sub.user_id = sp.user_id
    where sp.user_id = v_uid and sp.status = 'accepted'
      and sp.notify_on_complete and sub.plan = 'premium';
  end if;

  select * into v_stats from public.user_stats where user_id = v_uid;

  return jsonb_build_object(
    'attended_seconds', v_attended,
    'xp_awarded', v_xp,
    'level', coalesce(v_stats.level, 1),
    'xp', coalesce(v_stats.xp, 0),
    'current_streak', coalesce(v_stats.current_streak, 0),
    'new_achievements', coalesce(to_jsonb(v_new_achievements), '[]'::jsonb)
  );
end;
$$;

-- ---------- 完了後の自己評価・メモの追記 ----------
create or replace function public.rate_session(
  p_session_id uuid,
  p_rating text,
  p_memo text default ''
)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_rating is not null and p_rating not in ('focused','normal','distracted') then
    raise exception 'invalid_rating';
  end if;
  update public.study_sessions
  set rating = p_rating, memo = left(coalesce(p_memo,''), 500)
  where id = p_session_id and user_id = auth.uid()
    and status in ('completed','left_early');
  if not found then
    raise exception 'session_not_found';
  end if;
end;
$$;

-- ---------- 学習開始の応援者通知キュー ----------
create or replace function public.queue_start_notifications(p_session_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_session public.study_sessions%rowtype;
begin
  select * into v_session from public.study_sessions
  where id = p_session_id and user_id = auth.uid();
  if not found or v_session.is_trial then return; end if;

  insert into public.supporter_notifications (supporter_id, type, payload)
  select sp.id, 'session_start',
         jsonb_build_object('minutes', v_session.planned_minutes, 'topic', v_session.topic)
  from public.supporters sp
  join public.subscriptions sub on sub.user_id = sp.user_id
  where sp.user_id = auth.uid() and sp.status = 'accepted'
    and sp.notify_on_start and sub.plan = 'premium';
end;
$$;

-- ---------- 通報 (レート制限付き) ----------
create or replace function public.create_report(
  p_reported_user_id uuid,
  p_room_id uuid,
  p_category text,
  p_description text default ''
)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_count integer;
  v_id uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_reported_user_id = v_uid then raise exception 'cannot_report_self'; end if;

  select count(*) into v_count from public.reports
  where reporter_id = v_uid and created_at > now() - interval '24 hours';
  if v_count >= 10 then raise exception 'report_rate_limited'; end if;

  insert into public.reports (reporter_id, reported_user_id, room_id, category, description)
  values (v_uid, p_reported_user_id, p_room_id, p_category, left(coalesce(p_description,''), 1000))
  returning id into v_id;
  return v_id;
end;
$$;

-- ---------- 応援者招待 (レート制限付き) ----------
create or replace function public.invite_supporter(p_email text, p_name text default '')
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_count integer;
  v_row public.supporters%rowtype;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'invalid_email'; end if;

  select count(*) into v_count from public.supporters
  where user_id = v_uid and created_at > now() - interval '24 hours';
  if v_count >= 5 then raise exception 'invite_rate_limited'; end if;

  insert into public.supporters (user_id, supporter_email, supporter_name)
  values (v_uid, lower(p_email), coalesce(p_name,''))
  on conflict (user_id, supporter_email)
  do update set status = 'pending', invite_token = gen_random_uuid(), updated_at = now()
  returning * into v_row;

  return jsonb_build_object('id', v_row.id, 'invite_token', v_row.invite_token);
end;
$$;

-- ---------- 応援者の同意 (招待メールのリンクから、未ログインで呼ばれる) ----------
create or replace function public.accept_supporter_invite(p_token uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_row public.supporters%rowtype;
  v_name text;
begin
  update public.supporters
  set status = 'accepted', consented_at = now()
  where invite_token = p_token and status = 'pending'
  returning * into v_row;
  if not found then
    raise exception 'invalid_or_used_token';
  end if;
  select display_name into v_name from public.profiles where id = v_row.user_id;
  return jsonb_build_object('user_display_name', v_name);
end;
$$;

-- ---------- 予約: 無料プラン件数制限 ----------
create or replace function public.enforce_reservation_limit()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_plan text;
  v_count integer;
begin
  select plan into v_plan from public.subscriptions where user_id = new.user_id;
  if coalesce(v_plan, 'free') = 'free' then
    select count(*) into v_count from public.reservations
    where user_id = new.user_id and status = 'scheduled';
    if v_count >= 3 then
      raise exception 'free_plan_reservation_limit';
    end if;
  end if;
  return new;
end;
$$;
create trigger reservations_limit before insert on public.reservations
  for each row execute function public.enforce_reservation_limit();

-- ---------- 繰り返し予約はプレミアムのみ ----------
create or replace function public.enforce_recurring_premium()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_plan text;
begin
  select plan into v_plan from public.subscriptions where user_id = new.user_id;
  if coalesce(v_plan, 'free') <> 'premium' then
    raise exception 'premium_required';
  end if;
  return new;
end;
$$;
create trigger recurring_reservations_premium before insert on public.recurring_reservations
  for each row execute function public.enforce_recurring_premium();

-- ---------- 欠席記録 + 繰り返し予約の実体化 ----------
create or replace function public.sync_reservations()
returns void language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_rule public.recurring_reservations%rowtype;
  v_day date;
  v_starts timestamptz;
begin
  if v_uid is null then return; end if;

  -- 開始から10分過ぎても入室していない予約を欠席に
  update public.reservations
  set status = 'missed'
  where user_id = v_uid and status = 'scheduled'
    and starts_at < now() - interval '10 minutes'
    and session_id is null;

  -- アクティブな繰り返しルールから今後14日分の予約を生成(重複はスキップ)
  for v_rule in
    select * from public.recurring_reservations where user_id = v_uid and active
  loop
    for i in 0..13 loop
      v_day := (now() at time zone v_rule.timezone)::date + i;
      if extract(dow from v_day)::integer = v_rule.weekday then
        v_starts := (v_day::text || ' ' || v_rule.start_time::text)::timestamp
                    at time zone v_rule.timezone;
        if v_starts > now()
          and not exists (
            select 1 from public.reservations
            where recurring_reservation_id = v_rule.id and starts_at = v_starts
          )
        then
          begin
            insert into public.reservations
              (user_id, starts_at, duration_minutes, topic, recurring_reservation_id)
            values
              (v_uid, v_starts, v_rule.duration_minutes, v_rule.topic, v_rule.id);
          exception when others then
            null; -- 件数制限などはスキップ(繰り返しはプレミアムのため通常発生しない)
          end;
        end if;
      end if;
    end loop;
  end loop;
end;
$$;

-- ---------- 管理者: ユーザー利用停止/解除 ----------
create or replace function public.admin_set_user_status(
  p_user_id uuid,
  p_status text,
  p_note text default ''
)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'admin_only'; end if;
  if p_status not in ('active','suspended') then raise exception 'invalid_status'; end if;

  update public.profiles set status = p_status where id = p_user_id;

  -- 停止時は進行中セッションを打ち切る
  if p_status = 'suspended' then
    update public.study_sessions set status = 'abandoned', ended_at = now()
    where user_id = p_user_id and status = 'active';
    update public.room_participants set left_at = now()
    where user_id = p_user_id and left_at is null;
  end if;

  insert into public.admin_audit_logs (admin_id, action, target_type, target_id, detail)
  values (auth.uid(), 'set_user_status', 'user', p_user_id::text,
          jsonb_build_object('status', p_status, 'note', p_note));
end;
$$;

-- ---------- 管理者: 強制退室 ----------
create or replace function public.admin_force_leave(p_room_id uuid, p_user_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'admin_only'; end if;

  update public.study_sessions set status = 'abandoned', ended_at = now()
  where user_id = p_user_id and room_id = p_room_id and status = 'active';
  update public.room_participants set left_at = now()
  where user_id = p_user_id and room_id = p_room_id and left_at is null;

  insert into public.admin_audit_logs (admin_id, action, target_type, target_id, detail)
  values (auth.uid(), 'force_leave', 'room', p_room_id::text,
          jsonb_build_object('user_id', p_user_id));
end;
$$;

-- ---------- 管理者: 通報対応 ----------
create or replace function public.admin_update_report(
  p_report_id uuid,
  p_status text,
  p_note text default ''
)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'admin_only'; end if;
  if p_status not in ('open','reviewing','resolved','dismissed') then
    raise exception 'invalid_status';
  end if;

  update public.reports
  set status = p_status, resolved_by = auth.uid(), resolution_note = left(coalesce(p_note,''),1000)
  where id = p_report_id;

  insert into public.admin_audit_logs (admin_id, action, target_type, target_id, detail)
  values (auth.uid(), 'update_report', 'report', p_report_id::text,
          jsonb_build_object('status', p_status));
end;
$$;

-- ---------- 管理者: 利用状況集計 ----------
create or replace function public.admin_stats()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v jsonb;
begin
  if not public.is_admin() then raise exception 'admin_only'; end if;

  select jsonb_build_object(
    'total_users', (select count(*) from public.profiles where status <> 'deleted'),
    'dau_today', (select count(distinct user_id) from public.study_sessions
                  where started_at > date_trunc('day', now())),
    'mau', (select count(distinct user_id) from public.study_sessions
            where started_at > now() - interval '30 days'),
    'total_focus_minutes', (select coalesce(sum(attended_seconds),0)/60 from public.study_sessions
                            where status in ('completed','left_early')),
    'completed_sessions', (select count(*) from public.study_sessions where status = 'completed'),
    'studying_now', public.current_studying_count(),
    'open_reports', (select count(*) from public.reports where status = 'open'),
    'active_rooms', (select count(*) from public.study_rooms
                     where status in ('waiting','active') and ends_at > now()),
    'daily_users_14d', (
      select coalesce(jsonb_agg(t order by t->>'day'), '[]'::jsonb) from (
        select jsonb_build_object('day', d.day::date, 'users', count(distinct s.user_id)) as t
        from generate_series(date_trunc('day', now()) - interval '13 days',
                             date_trunc('day', now()), interval '1 day') d(day)
        left join public.study_sessions s
          on date_trunc('day', s.started_at) = d.day
        group by d.day
      ) sub
    )
  ) into v;
  return v;
end;
$$;

-- ---------- 実績マスタ ----------
insert into public.achievements (id, name, description, condition_type, condition_value, icon, sort_order) values
  ('first_session',  'はじめの一歩',   '初めてのコマを完了した',           'first_session',      1,   'sparkles', 1),
  ('sessions_10',    '10コマの積み重ね','完了コマが10コマに到達した',       'completed_sessions', 10,  'layers',   2),
  ('sessions_100',   '100コマの道',    '完了コマが100コマに到達した',      'completed_sessions', 100, 'mountain', 3),
  ('streak_7',       '7日のともしび',  '7日連続で自習室を利用した',        'streak_days',        7,   'flame',    4),
  ('streak_30',      '30日のともしび', '30日連続で自習室を利用した',       'streak_days',        30,  'trophy',   5)
on conflict (id) do nothing;
