-- ============================================================
-- AI CREATIVE OFFICE データベース設計(Phase 1時点の設計ドラフト)
-- Phase 1ではアプリはlocalStorageで動作し、このスキーマは未接続。
-- Phase 4-5でSupabase接続時にこのマイグレーションを適用する。
--
-- RLS方針:
--   すべてのテーブルは organization_id を持ち、
--   「自分が所属する organization の行のみ読み書き可能」を基本とする。
--   users.organization_id と auth.uid() の対応は memberships で解決。
-- ============================================================

create extension if not exists "uuid-ossp";

-- ---------- 組織・ユーザー ----------
create table organizations (
  id uuid primary key default uuid_generate_v4(),
  name text not null default 'AI CREATIVE OFFICE',
  sub_copy text not null default '',
  created_at timestamptz not null default now()
);

create table organization_settings (
  organization_id uuid primary key references organizations(id) on delete cascade,
  ceo_name text not null default '',
  business text not null default '',
  services jsonb not null default '[]',
  target_customer text not null default '',
  sales_regions jsonb not null default '[]',
  sales_industries jsonb not null default '[]',
  prohibited_targets text not null default '',
  tone text not null default '',
  brand_color text not null default '#6366f1',
  monthly_ai_budget_jpy integer not null default 100000,
  approval_required jsonb not null default '[]',
  timezone text not null default 'Asia/Tokyo',
  currency text not null default 'JPY',
  usd_jpy_rate numeric(8,2) not null default 155,
  demo_mode boolean not null default true,
  updated_at timestamptz not null default now()
);

create table users (
  id uuid primary key references auth.users(id) on delete cascade,
  organization_id uuid not null references organizations(id) on delete cascade,
  display_name text not null default '',
  role text not null default 'owner', -- owner / member
  created_at timestamptz not null default now()
);
create index idx_users_org on users(organization_id);

-- ---------- 部署・AI社員 ----------
create table departments (
  id text primary key, -- executive / secretary / sales / marketing / production / admin
  organization_id uuid not null references organizations(id) on delete cascade,
  name text not null,
  color text not null default '#6366f1',
  sort_order integer not null default 0
);
create index idx_departments_org on departments(organization_id);

create table agents (
  id uuid primary key default uuid_generate_v4(),
  organization_id uuid not null references organizations(id) on delete cascade,
  department_id text references departments(id),
  code text not null, -- ceo / list / form_sales ...
  name text not null,
  role text not null,
  description text not null default '',
  responsibilities jsonb not null default '[]',
  avatar text not null default '🤖',
  color text not null default '#6366f1',
  model text not null default 'claude-sonnet-5',
  provider text not null default 'anthropic',
  system_prompt text not null default '',
  capabilities jsonb not null default '[]',
  available_tools jsonb not null default '[]',
  input_schema jsonb,
  output_schema jsonb,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  unique (organization_id, code)
);
create index idx_agents_org on agents(organization_id);

create table agent_settings (
  agent_id uuid primary key references agents(id) on delete cascade,
  max_parallel_tasks integer not null default 1,
  daily_budget_jpy integer,
  approval_types jsonb not null default '[]',
  custom_prompt text
);

create table agent_status_logs (
  id uuid primary key default uuid_generate_v4(),
  organization_id uuid not null references organizations(id) on delete cascade,
  agent_id uuid not null references agents(id) on delete cascade,
  status text not null, -- idle/checking/working/delegating/waiting_approval/error/done/paused/meeting
  status_note text not null default '',
  progress integer not null default 0,
  current_task_id uuid,
  created_at timestamptz not null default now()
);
create index idx_agent_status_logs_agent on agent_status_logs(agent_id, created_at desc);

create table agent_messages ( -- AI社員同士の会話
  id uuid primary key default uuid_generate_v4(),
  organization_id uuid not null references organizations(id) on delete cascade,
  from_agent_id uuid references agents(id),
  to_agent_id uuid references agents(id),
  content text not null,
  task_id uuid,
  created_at timestamptz not null default now()
);
create index idx_agent_messages_org on agent_messages(organization_id, created_at desc);

-- ---------- 顧客・営業 ----------
create table customers (
  id uuid primary key default uuid_generate_v4(),
  organization_id uuid not null references organizations(id) on delete cascade,
  name text not null,
  industry text,
  region text,
  url text,
  memo text default '',
  created_at timestamptz not null default now()
);
create index idx_customers_org on customers(organization_id);

create table customer_contacts (
  id uuid primary key default uuid_generate_v4(),
  customer_id uuid not null references customers(id) on delete cascade,
  name text not null,
  email text,
  phone text,
  role text,
  created_at timestamptz not null default now()
);

create table leads (
  id uuid primary key default uuid_generate_v4(),
  organization_id uuid not null references organizations(id) on delete cascade,
  campaign_id uuid,
  company_name text not null,
  industry text,
  region text,
  employee_size text,
  url text,
  contact_form_url text,
  email text,
  phone text,
  contact_person text,
  reason text default '',
  hypothesis text default '',
  proposal text,
  status text not null default 'new',
  last_contact_at timestamptz,
  next_action_at timestamptz,
  opted_out boolean not null default false,     -- 配信停止(再送信禁止)
  do_not_contact boolean not null default false, -- 連絡禁止
  memo text default '',
  created_at timestamptz not null default now()
);
create index idx_leads_org_status on leads(organization_id, status);
-- 重複送信防止: 同一組織内で同一URL/メールの企業を一意に
create unique index uq_leads_org_url on leads(organization_id, url) where url is not null;

create table outreach_campaigns (
  id uuid primary key default uuid_generate_v4(),
  organization_id uuid not null references organizations(id) on delete cascade,
  name text not null,
  channel text not null, -- email / form / tel
  target_condition text default '',
  status text not null default 'draft',
  created_at timestamptz not null default now()
);

create table outreach_messages (
  id uuid primary key default uuid_generate_v4(),
  organization_id uuid not null references organizations(id) on delete cascade,
  campaign_id uuid references outreach_campaigns(id) on delete set null,
  lead_id uuid not null references leads(id) on delete cascade,
  channel text not null,
  subject text,
  body text not null,
  -- 外部送信の安全設計: 下書き→承認待ち→承認済み→実行中→完了/失敗/停止
  status text not null default 'draft'
    check (status in ('draft','waiting_approval','approved','executing','done','failed','stopped')),
  approval_id uuid,
  sent_at timestamptz,
  result text,
  created_at timestamptz not null default now()
);
create index idx_outreach_messages_lead on outreach_messages(lead_id);
create index idx_outreach_messages_status on outreach_messages(organization_id, status);

create table inquiries (
  id uuid primary key default uuid_generate_v4(),
  organization_id uuid not null references organizations(id) on delete cascade,
  from_company text,
  from_name text,
  email text,
  subject text not null,
  body text not null,
  service text,
  urgency text not null default 'medium',
  status text not null default 'new',
  draft_reply text,
  assignee_agent_id uuid references agents(id),
  received_at timestamptz not null default now(),
  first_response_minutes integer
);
create index idx_inquiries_org on inquiries(organization_id, status);

create table meetings (
  id uuid primary key default uuid_generate_v4(),
  organization_id uuid not null references organizations(id) on delete cascade,
  deal_id uuid,
  title text not null,
  candidate_slots jsonb not null default '[]',
  confirmed_at timestamptz,
  location text,
  minutes text, -- 議事録
  status text not null default 'scheduling',
  created_at timestamptz not null default now()
);

create table deals (
  id uuid primary key default uuid_generate_v4(),
  organization_id uuid not null references organizations(id) on delete cascade,
  lead_id uuid references leads(id) on delete set null,
  customer_id uuid references customers(id) on delete set null,
  title text not null,
  amount_jpy integer not null default 0,
  status text not null default 'new',
  summary text default '',
  next_action text default '',
  next_action_at timestamptz,
  lost_reason text,
  probability integer not null default 0,
  created_at timestamptz not null default now()
);
create index idx_deals_org_status on deals(organization_id, status);

-- ---------- 制作 ----------
create table projects (
  id uuid primary key default uuid_generate_v4(),
  organization_id uuid not null references organizations(id) on delete cascade,
  customer_id uuid references customers(id) on delete set null,
  deal_id uuid references deals(id) on delete set null,
  name text not null,
  service_type text,
  order_amount_jpy integer not null default 0,
  production_cost_jpy integer not null default 0,
  outsourcing_cost_jpy integer not null default 0,
  director_agent_id uuid references agents(id),
  start_date date,
  deadline date,
  status text not null default 'active',
  phase text not null default '問い合わせ',
  progress integer not null default 0,
  requirements text default '',
  purpose text default '',
  target text default '',
  persona text default '',
  sitemap jsonb not null default '[]',
  assets jsonb not null default '[]',
  published_url text,
  created_at timestamptz not null default now()
);
create index idx_projects_org on projects(organization_id, status);

create table project_pages (
  id uuid primary key default uuid_generate_v4(),
  project_id uuid not null references projects(id) on delete cascade,
  name text not null,
  status text not null default 'planned',
  sort_order integer not null default 0
);

create table project_members (
  project_id uuid not null references projects(id) on delete cascade,
  agent_id uuid not null references agents(id) on delete cascade,
  primary key (project_id, agent_id)
);

-- ---------- タスク ----------
create table tasks (
  id uuid primary key default uuid_generate_v4(),
  organization_id uuid not null references organizations(id) on delete cascade,
  title text not null,
  description text default '',
  assignee_agent_id uuid references agents(id),
  requester_agent_id uuid references agents(id),
  project_id uuid references projects(id) on delete set null,
  customer_id uuid references customers(id) on delete set null,
  priority text not null default 'medium',
  status text not null default 'backlog'
    check (status in ('backlog','preparing','queued','running','waiting_approval','revising','done','failed','stopped','cancelled')),
  progress integer not null default 0,
  planned_start date,
  deadline date,
  started_at timestamptz,
  completed_at timestamptz,
  needs_approval boolean not null default false,
  approver text,
  input jsonb,
  output jsonb,
  model text,
  input_tokens bigint not null default 0,
  output_tokens bigint not null default 0,
  cost_usd numeric(12,6) not null default 0,
  error_message text,
  created_at timestamptz not null default now()
);
create index idx_tasks_org_status on tasks(organization_id, status);
create index idx_tasks_assignee on tasks(assignee_agent_id, status);
create index idx_tasks_project on tasks(project_id);

create table task_dependencies (
  task_id uuid not null references tasks(id) on delete cascade,
  depends_on_task_id uuid not null references tasks(id) on delete cascade,
  primary key (task_id, depends_on_task_id)
);

create table task_logs (
  id uuid primary key default uuid_generate_v4(),
  task_id uuid not null references tasks(id) on delete cascade,
  agent_id uuid references agents(id),
  message text not null,
  level text not null default 'info',
  created_at timestamptz not null default now()
);
create index idx_task_logs_task on task_logs(task_id, created_at desc);

-- ---------- 承認 ----------
create table approvals (
  id uuid primary key default uuid_generate_v4(),
  organization_id uuid not null references organizations(id) on delete cascade,
  type text not null, -- email_send / form_send / sns_post / customer_reply / quote_send / publish / domain_change / bulk_task / high_cost / pii
  title text not null,
  requester_agent_id uuid references agents(id),
  target text default '',
  body text default '',
  count integer not null default 1,
  estimated_cost_jpy integer not null default 0,
  risks jsonb not null default '[]',
  has_duplicates boolean not null default false,
  has_opted_out_targets boolean not null default false,
  status text not null default 'pending'
    check (status in ('pending','approved','revision_requested','rejected')),
  task_id uuid references tasks(id) on delete set null,
  decided_by uuid references users(id),
  decided_at timestamptz,
  created_at timestamptz not null default now()
);
create index idx_approvals_org_status on approvals(organization_id, status);

-- ---------- コスト・売上 ----------
create table ai_usage (
  id uuid primary key default uuid_generate_v4(),
  organization_id uuid not null references organizations(id) on delete cascade,
  provider text not null,
  model text not null,
  input_tokens bigint not null default 0,
  output_tokens bigint not null default 0,
  cached_tokens bigint not null default 0,
  usd_rate_input numeric(10,4) not null default 0,  -- $/1Mトークン
  usd_rate_output numeric(10,4) not null default 0,
  cost_usd numeric(12,6) not null default 0,
  usd_jpy_rate numeric(8,2) not null default 155,
  cost_jpy numeric(12,2) not null default 0,
  agent_id uuid references agents(id),
  task_id uuid references tasks(id) on delete set null,
  project_id uuid references projects(id) on delete set null,
  executed_at timestamptz not null default now()
);
create index idx_ai_usage_org_date on ai_usage(organization_id, executed_at desc);
create index idx_ai_usage_agent on ai_usage(agent_id);
create index idx_ai_usage_project on ai_usage(project_id);

create table expenses (
  id uuid primary key default uuid_generate_v4(),
  organization_id uuid not null references organizations(id) on delete cascade,
  project_id uuid references projects(id) on delete set null,
  category text not null, -- production / outsourcing / tool / other
  amount_jpy integer not null,
  memo text default '',
  incurred_on date not null default current_date,
  created_at timestamptz not null default now()
);

create table revenues (
  id uuid primary key default uuid_generate_v4(),
  organization_id uuid not null references organizations(id) on delete cascade,
  project_id uuid references projects(id) on delete set null,
  deal_id uuid references deals(id) on delete set null,
  amount_jpy integer not null,
  status text not null default 'unbilled', -- unbilled / billed / paid
  billed_on date,
  paid_on date,
  created_at timestamptz not null default now()
);

-- ---------- レポート・ログ ----------
create table reports (
  id uuid primary key default uuid_generate_v4(),
  organization_id uuid not null references organizations(id) on delete cascade,
  type text not null, -- daily / weekly / monthly
  period_label text not null,
  body text not null,
  created_at timestamptz not null default now()
);

create table integrations (
  id uuid primary key default uuid_generate_v4(),
  organization_id uuid not null references organizations(id) on delete cascade,
  code text not null, -- gmail / gcal / sns / vercel ...
  name text not null,
  category text not null,
  status text not null default 'not_connected', -- not_connected / connected / disabled
  config jsonb not null default '{}', -- APIキー本体はVault/環境変数に置きここには保存しない
  created_at timestamptz not null default now(),
  unique (organization_id, code)
);

create table error_logs (
  id uuid primary key default uuid_generate_v4(),
  organization_id uuid not null references organizations(id) on delete cascade,
  agent_id uuid references agents(id),
  task_id uuid references tasks(id) on delete set null,
  message text not null,
  detail text default '',
  resolved boolean not null default false,
  created_at timestamptz not null default now()
);

create table audit_logs (
  id uuid primary key default uuid_generate_v4(),
  organization_id uuid not null references organizations(id) on delete cascade,
  actor_user_id uuid references users(id),
  actor_agent_id uuid references agents(id),
  action text not null,
  target_table text,
  target_id uuid,
  detail jsonb not null default '{}',
  created_at timestamptz not null default now()
);
create index idx_audit_logs_org on audit_logs(organization_id, created_at desc);

create table notifications (
  id uuid primary key default uuid_generate_v4(),
  organization_id uuid not null references organizations(id) on delete cascade,
  user_id uuid references users(id) on delete cascade,
  title text not null,
  body text default '',
  link text,
  read boolean not null default false,
  created_at timestamptz not null default now()
);
create index idx_notifications_user on notifications(user_id, read);

-- ---------- 後付け外部キー(テーブル作成順の都合で最後に付与) ----------
alter table leads
  add constraint fk_leads_campaign foreign key (campaign_id)
  references outreach_campaigns(id) on delete set null;
alter table meetings
  add constraint fk_meetings_deal foreign key (deal_id)
  references deals(id) on delete set null;
alter table agent_status_logs
  add constraint fk_agent_status_logs_task foreign key (current_task_id)
  references tasks(id) on delete set null;
alter table agent_messages
  add constraint fk_agent_messages_task foreign key (task_id)
  references tasks(id) on delete set null;
alter table outreach_messages
  add constraint fk_outreach_messages_approval foreign key (approval_id)
  references approvals(id) on delete set null;

-- ---------- RLS ----------
-- 全テーブルでRLSを有効化し、所属組織の行のみ許可する。
-- (代表例。実適用時は全テーブルに同型のポリシーを展開する)
alter table organizations enable row level security;
alter table leads enable row level security;
alter table tasks enable row level security;
alter table approvals enable row level security;
alter table ai_usage enable row level security;

create or replace function current_org_id() returns uuid
language sql stable as $$
  select organization_id from users where id = auth.uid()
$$;

create policy org_select on organizations for select using (id = current_org_id());
create policy leads_all on leads for all using (organization_id = current_org_id());
create policy tasks_all on tasks for all using (organization_id = current_org_id());
create policy approvals_all on approvals for all using (organization_id = current_org_id());
create policy ai_usage_all on ai_usage for all using (organization_id = current_org_id());
