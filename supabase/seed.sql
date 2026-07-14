-- ============================================================
-- MokuTomo シードデータ (ローカル開発専用。本番では絶対に実行しないこと)
-- ログイン情報はREADMEの「開発環境」欄を参照。
-- ============================================================

-- ---------- テストユーザー (auth.users へ直接投入: ローカル専用の手法) ----------
-- パスワードは全員 'password123' (bcrypt)
do $$
declare
  u record;
begin
  for u in
    select * from (values
      ('11111111-1111-1111-1111-111111111111'::uuid, 'sakura@example.com',  'さくら'),
      ('22222222-2222-2222-2222-222222222222'::uuid, 'kaito@example.com',   'カイト'),
      ('33333333-3333-3333-3333-333333333333'::uuid, 'mei@example.com',     'めい'),
      ('99999999-9999-9999-9999-999999999999'::uuid, 'admin@example.com',   '運営チーム')
    ) as t(id, email, display_name)
  loop
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, recovery_token, email_change, email_change_token_new, email_change_token_current
    ) values (
      '00000000-0000-0000-0000-000000000000', u.id, 'authenticated', 'authenticated',
      u.email, crypt('password123', gen_salt('bf')), now(),
      '{"provider":"email","providers":["email"]}',
      jsonb_build_object('display_name', u.display_name, 'terms_accepted', 'true'),
      now() - interval '40 days', now(), '', '', '', '', ''
    ) on conflict (id) do nothing;

    insert into auth.identities (
      id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at
    ) values (
      gen_random_uuid(), u.id, u.id::text,
      jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
      'email', now(), now(), now()
    ) on conflict do nothing;
  end loop;
end $$;

-- プロフィール調整 (handle_new_user トリガで作成済みの行を更新)
update public.profiles set role = 'admin', study_purpose = 'work',
  onboarding_completed_at = now() - interval '39 days'
  where id = '99999999-9999-9999-9999-999999999999';
update public.profiles set study_purpose = 'exam',
  onboarding_completed_at = now() - interval '39 days'
  where id = '11111111-1111-1111-1111-111111111111';
update public.profiles set study_purpose = 'certification',
  onboarding_completed_at = now() - interval '30 days'
  where id = '22222222-2222-2222-2222-222222222222';
update public.profiles set study_purpose = 'school',
  onboarding_completed_at = now() - interval '20 days'
  where id = '33333333-3333-3333-3333-333333333333';

-- さくらはプレミアムプラン (繰り返し予約・応援者通知のテスト用)
update public.subscriptions set plan = 'premium', status = 'active',
  current_period_end = now() + interval '30 days'
  where user_id = '11111111-1111-1111-1111-111111111111';

-- ---------- 学習履歴 (約30件: 過去14日に分散) ----------
do $$
declare
  v_users uuid[] := array[
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222222',
    '33333333-3333-3333-3333-333333333333'
  ];
  v_topics text[] := array['数学の過去問','英単語','簿記2級','レポート作成','プログラミング','読書ノート'];
  v_uid uuid;
  v_room_id uuid;
  v_start timestamptz;
  v_minutes integer;
  v_status text;
  v_attended integer;
  i integer := 0;
begin
  while i < 30 loop
    v_uid := v_users[(i % 3) + 1];
    v_minutes := (array[25,25,25,50,15])[(i % 5) + 1];
    v_start := date_trunc('hour', now()) - make_interval(days => (i % 14), hours => (i % 4) + 8);
    v_status := case when i % 6 = 5 then 'left_early' else 'completed' end;
    v_attended := case when v_status = 'completed' then v_minutes * 60 else (v_minutes * 60) / 3 end;

    insert into public.study_rooms (status, duration_minutes, starts_at, ends_at)
    values ('finished', v_minutes, v_start, v_start + make_interval(mins => v_minutes))
    returning id into v_room_id;

    insert into public.study_sessions
      (user_id, room_id, topic, planned_minutes, started_at, ended_at, attended_seconds, status, rating, xp_awarded)
    values (
      v_uid, v_room_id, v_topics[(i % 6) + 1], v_minutes,
      v_start, v_start + make_interval(secs => v_attended), v_attended, v_status,
      case when v_status = 'completed' then (array['focused','normal','focused'])[(i % 3) + 1] else null end,
      case when v_status = 'completed' then (v_attended / 60) * 2 + 10 else 0 end
    );

    insert into public.room_participants (room_id, user_id, joined_at, left_at)
    values (v_room_id, v_uid, v_start, v_start + make_interval(secs => v_attended));

    i := i + 1;
  end loop;
end $$;

-- 統計をセッション実績から再計算
update public.user_stats us set
  xp = agg.xp,
  level = public.level_for_xp(agg.xp),
  total_focus_minutes = agg.minutes,
  total_completed_sessions = agg.completed,
  current_streak = 3,
  longest_streak = 6,
  last_study_date = (now() at time zone 'Asia/Tokyo')::date
from (
  select user_id,
    coalesce(sum(xp_awarded),0)::integer as xp,
    coalesce(sum(attended_seconds),0)::integer / 60 as minutes,
    count(*) filter (where status = 'completed')::integer as completed
  from public.study_sessions group by user_id
) agg
where us.user_id = agg.user_id;

-- ---------- 実績付与 ----------
select public.award_achievements(u) from unnest(array[
  '11111111-1111-1111-1111-111111111111'::uuid,
  '22222222-2222-2222-2222-222222222222'::uuid,
  '33333333-3333-3333-3333-333333333333'::uuid
]) as u;

-- ---------- 予約 ----------
insert into public.reservations (user_id, starts_at, duration_minutes, topic) values
  ('11111111-1111-1111-1111-111111111111', date_trunc('hour', now()) + interval '26 hours', 25, '数学の過去問'),
  ('22222222-2222-2222-2222-222222222222', date_trunc('hour', now()) + interval '20 hours', 50, '簿記2級'),
  ('33333333-3333-3333-3333-333333333333', date_trunc('hour', now()) + interval '44 hours', 25, 'レポート作成');

-- 繰り返し予約 (プレミアムのさくらのみ)
insert into public.recurring_reservations (user_id, weekday, start_time, duration_minutes, topic) values
  ('11111111-1111-1111-1111-111111111111', 1, '07:00', 25, '朝の英単語'),
  ('11111111-1111-1111-1111-111111111111', 4, '21:00', 50, '数学の過去問');

-- 欠席テストデータ
insert into public.reservations (user_id, starts_at, duration_minutes, topic, status) values
  ('22222222-2222-2222-2222-222222222222', now() - interval '2 days', 25, '英単語', 'missed');

-- ---------- 応援者 ----------
insert into public.supporters (user_id, supporter_email, supporter_name, status, consented_at) values
  ('11111111-1111-1111-1111-111111111111', 'parent@example.com', 'お母さん', 'accepted', now() - interval '10 days'),
  ('11111111-1111-1111-1111-111111111111', 'friend@example.com', 'ゆき', 'pending', null);

-- ---------- お知らせ ----------
insert into public.announcements (title, body, is_published, published_at, created_by) values
  ('MokuTomoへようこそ', 'オンライン自習室MokuTomoのベータ版を公開しました。「今すぐ入室」からすぐに自習を始められます。', true, now() - interval '7 days', '99999999-9999-9999-9999-999999999999'),
  ('メンテナンスのお知らせ', '今週土曜日の深夜2:00〜4:00にメンテナンスを行います。この間は自習室に入室できません。', true, now() - interval '1 day', '99999999-9999-9999-9999-999999999999'),
  ('(下書き)新機能の予告', '近日中に週間レポート機能を追加予定です。', false, null, '99999999-9999-9999-9999-999999999999');

-- ---------- 通報テストデータ ----------
insert into public.reports (reporter_id, reported_user_id, category, description, status) values
  ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222',
   'camera_misuse', 'カメラに勉強と関係のないものを映し続けていました。', 'open'),
  ('33333333-3333-3333-3333-333333333333', '22222222-2222-2222-2222-222222222222',
   'other', 'テスト用の通報データです。', 'resolved');
update public.reports set resolved_by = '99999999-9999-9999-9999-999999999999',
  resolution_note = '確認しました。問題ありませんでした。'
  where status = 'resolved';

-- ---------- ブロックテストデータ ----------
insert into public.blocked_users (user_id, blocked_user_id) values
  ('33333333-3333-3333-3333-333333333333', '22222222-2222-2222-2222-222222222222');
