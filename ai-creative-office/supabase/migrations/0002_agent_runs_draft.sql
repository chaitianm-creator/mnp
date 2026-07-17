-- ============================================================
-- 【設計ドラフト・未適用】AI実働基盤のテーブル設計
-- 現在はZustand persist(localStorage)で動作しており、
-- このSQLは将来のSupabase移行用の設計資料です。本番へ適用しないこと。
-- ============================================================

-- AI実行ラン(社長の依頼1件 = 1ラン)
create table agent_runs (
  id uuid primary key default uuid_generate_v4(),
  organization_id uuid not null references organizations(id) on delete cascade,
  request text not null,                -- 社長の依頼文
  plan_markdown text not null default '',
  plan_json jsonb,
  status text not null default 'awaiting_approval'
    check (status in ('awaiting_approval','running','revising','awaiting_cost_approval','done','failed','cancelled')),
  total_input_tokens bigint not null default 0,
  total_output_tokens bigint not null default 0,
  total_cost_jpy numeric(12,2) not null default 0,
  is_mock boolean not null default true,
  revision_count integer not null default 0,
  max_revisions integer not null default 1,
  error text,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);
create index idx_agent_runs_org on agent_runs(organization_id, created_at desc);

-- ラン内の個別タスク実行
create table task_runs (
  id uuid primary key default uuid_generate_v4(),
  run_id uuid not null references agent_runs(id) on delete cascade,
  agent_code text not null,             -- director / writer / reviewer
  title text not null,
  status text not null default 'pending'
    check (status in ('pending','running','done','failed','cancelled')),
  depends_on uuid[],
  retry_count integer not null default 0,
  max_retries integer not null default 2,
  input_tokens bigint not null default 0,
  output_tokens bigint not null default 0,
  cost_jpy numeric(12,2) not null default 0,
  model text,
  provider text,
  error text,
  review_status text not null default 'none',
  started_at timestamptz,
  completed_at timestamptz
);
create index idx_task_runs_run on task_runs(run_id);

-- 成果物(現行バージョン)
create table deliverables (
  id uuid primary key default uuid_generate_v4(),
  organization_id uuid not null references organizations(id) on delete cascade,
  run_id uuid references agent_runs(id) on delete set null,
  task_run_id uuid references task_runs(id) on delete set null,
  title text not null,
  type text not null check (type in ('plan','requirements','copy','review')),
  agent_code text not null,
  status text not null default 'draft'
    check (status in ('draft','needs_fix','reviewed','approved','final','rejected')),
  current_version integer not null default 1,
  markdown text not null default '',
  json jsonb,
  source_request text not null default '',
  model text,
  provider text,
  is_mock boolean not null default true,
  input_tokens bigint not null default 0,
  output_tokens bigint not null default 0,
  cost_jpy numeric(12,2) not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index idx_deliverables_org on deliverables(organization_id, created_at desc);

-- 成果物のバージョン履歴(AIによる自動上書きをせず、人間編集も別バージョン)
create table deliverable_versions (
  id uuid primary key default uuid_generate_v4(),
  deliverable_id uuid not null references deliverables(id) on delete cascade,
  version integer not null,
  markdown text not null,
  edited_by text not null check (edited_by in ('ai','human')),
  note text not null default '',
  created_at timestamptz not null default now(),
  unique (deliverable_id, version)
);

-- 実行計画(履歴として独立保存する場合)
create table execution_plans (
  id uuid primary key default uuid_generate_v4(),
  run_id uuid not null references agent_runs(id) on delete cascade,
  plan jsonb not null,
  created_at timestamptz not null default now()
);

-- 実行エラー
create table execution_errors (
  id uuid primary key default uuid_generate_v4(),
  run_id uuid references agent_runs(id) on delete cascade,
  task_run_id uuid references task_runs(id) on delete cascade,
  message text not null,                -- APIキー等の機密は含めない
  retry_count integer not null default 0,
  input_summary text,                   -- 入力の要約(全文は保存しない)
  created_at timestamptz not null default now()
);

-- 備考: ai_messages / ai_usage は既存の agent_messages / ai_usage テーブルを流用する。
-- RLSは他テーブル同様 organization_id = current_org_id() を基本とする。
