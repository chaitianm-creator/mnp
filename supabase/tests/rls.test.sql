-- ============================================================
-- RLS検証テスト (ローカル環境でシード投入後に実行)
--   psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -v ON_ERROR_STOP=1 -f supabase/tests/rls.test.sql
-- すべてのアサーションが通れば "RLS TESTS PASSED" が表示される。
-- 失敗時は exception で停止する。
-- ============================================================

\set QUIET on

-- ---------- ヘルパー: さくら(一般ユーザー)として実行 ----------
begin;

select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
set local role authenticated;

do $$
declare
  n integer;
begin
  -- 1. 自分のセッションは読める
  select count(*) into n from public.study_sessions;
  if n = 0 then
    raise exception 'FAIL: さくらは自分のセッションを読めるはず';
  end if;

  -- 2. 他人のセッションは読めない (全行が自分のもの)
  select count(*) into n from public.study_sessions
  where user_id <> '11111111-1111-1111-1111-111111111111';
  if n <> 0 then
    raise exception 'FAIL: 他人のstudy_sessionsが % 行見えている', n;
  end if;

  -- 3. 他人のプロフィールは読めない
  select count(*) into n from public.profiles
  where id <> '11111111-1111-1111-1111-111111111111';
  if n <> 0 then
    raise exception 'FAIL: 他人のprofilesが % 行見えている', n;
  end if;

  -- 4. 他人の予約・目標・統計・応援者は読めない
  select count(*) into n from public.reservations
  where user_id <> '11111111-1111-1111-1111-111111111111';
  if n <> 0 then raise exception 'FAIL: 他人のreservationsが見えている'; end if;

  select count(*) into n from public.user_stats
  where user_id <> '11111111-1111-1111-1111-111111111111';
  if n <> 0 then raise exception 'FAIL: 他人のuser_statsが見えている'; end if;

  select count(*) into n from public.supporters
  where user_id <> '11111111-1111-1111-1111-111111111111';
  if n <> 0 then raise exception 'FAIL: 他人のsupportersが見えている'; end if;

  -- 5. user_stats への直接書込(XP改ざん)はできない
  begin
    update public.user_stats set xp = 999999
    where user_id = '11111111-1111-1111-1111-111111111111';
    if found then
      raise exception 'FAIL: user_statsを直接更新できてしまった';
    end if;
  exception when insufficient_privilege then
    null; -- 期待どおり
  end;

  -- 6. study_sessions への直接INSERT(記録偽造)はできない
  begin
    insert into public.study_sessions (user_id, planned_minutes, topic)
    values ('11111111-1111-1111-1111-111111111111', 25, '偽造');
    raise exception 'FAIL: study_sessionsへ直接INSERTできてしまった';
  exception when insufficient_privilege then
    null;
  end;

  -- 7. user_achievements への直接INSERT(バッジ偽造)はできない
  begin
    insert into public.user_achievements (user_id, achievement_id)
    values ('11111111-1111-1111-1111-111111111111', 'sessions_100');
    raise exception 'FAIL: user_achievementsへ直接INSERTできてしまった';
  exception when insufficient_privilege then
    null;
  end;

  -- 8. subscriptions の直接変更(プラン偽装)はできない
  begin
    update public.subscriptions set plan = 'premium'
    where user_id = '11111111-1111-1111-1111-111111111111';
    -- premiumのさくらはpremiumのままなのでfreeユーザーで検証すべきだが、
    -- update自体が拒否される(ポリシーなし)ことを確認する
    if found then
      raise exception 'FAIL: subscriptionsを直接更新できてしまった';
    end if;
  exception when insufficient_privilege then
    null;
  end;

  -- 9. 自分のrole昇格はできない (トリガで拒否)
  begin
    update public.profiles set role = 'admin'
    where id = '11111111-1111-1111-1111-111111111111';
    raise exception 'FAIL: 自分のroleをadminに変更できてしまった';
  exception when others then
    if sqlerrm like '%FAIL:%' then raise; end if;
    null; -- 期待どおり拒否
  end;

  -- 10. 管理者専用RPCは実行できない
  begin
    perform public.admin_stats();
    raise exception 'FAIL: 一般ユーザーがadmin_statsを実行できてしまった';
  exception when others then
    if sqlerrm like '%FAIL:%' then raise; end if;
    null;
  end;

  -- 11. admin_audit_logs は読めない
  select count(*) into n from public.admin_audit_logs;
  if n <> 0 then raise exception 'FAIL: admin_audit_logsが見えている'; end if;

  raise notice 'PASS: 一般ユーザー(さくら)の権限チェック OK';
end $$;

rollback;

-- ---------- 管理者として実行 ----------
begin;

select set_config('request.jwt.claims',
  '{"sub":"99999999-9999-9999-9999-999999999999","role":"authenticated"}', true);
set local role authenticated;

do $$
declare
  n integer;
  v jsonb;
begin
  -- 管理者は全ユーザーのプロフィールを読める
  select count(*) into n from public.profiles;
  if n < 4 then
    raise exception 'FAIL: 管理者が全profilesを読めない (%行)', n;
  end if;

  -- 管理者は通報を読める
  select count(*) into n from public.reports;
  if n = 0 then
    raise exception 'FAIL: 管理者がreportsを読めない';
  end if;

  -- admin_stats が実行できる
  v := public.admin_stats();
  if (v->>'total_users')::integer < 4 then
    raise exception 'FAIL: admin_statsの結果が不正';
  end if;

  raise notice 'PASS: 管理者の権限チェック OK';
end $$;

rollback;

-- ---------- 未認証(anon)として実行 ----------
begin;

select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;

do $$
declare
  n integer;
begin
  select count(*) into n from public.profiles;
  if n <> 0 then raise exception 'FAIL: anonがprofilesを読めている'; end if;
  select count(*) into n from public.study_sessions;
  if n <> 0 then raise exception 'FAIL: anonがstudy_sessionsを読めている'; end if;

  -- お問い合わせはanonでも投稿できる
  insert into public.contact_messages (email, message)
  values ('anon@example.com', 'RLSテストからの投稿');

  raise notice 'PASS: 未認証ユーザーの権限チェック OK';
end $$;

rollback;

select 'RLS TESTS PASSED' as result;
