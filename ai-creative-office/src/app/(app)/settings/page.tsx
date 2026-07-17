'use client';

// 会社設定 + デモモード + AI社員設定
import { Badge, Button, Card, CardHeader, PageHeader } from '@/components/ui';
import { APPROVAL_TYPE } from '@/lib/labels';
import { DEFAULT_SIMULATION } from '@/lib/simulation';
import { useOffice } from '@/lib/store';
import type { ApprovalType } from '@/lib/types';
import { useState } from 'react';

export default function SettingsPage() {
  const settings = useOffice((s) => s.settings);
  const agents = useOffice((s) => s.agents);
  const updateSettings = useOffice((s) => s.updateSettings);
  const setDemoMode = useOffice((s) => s.setDemoMode);
  const resetAll = useOffice((s) => s.resetAll);
  const [saved, setSaved] = useState(false);
  const [form, setForm] = useState({
    companyName: settings.companyName,
    subCopy: settings.subCopy,
    ceoName: settings.ceoName,
    business: settings.business,
    tone: settings.tone,
    brandColor: settings.brandColor,
    timezone: settings.timezone,
  });

  const save = () => {
    updateSettings(form);
    setSaved(true);
    setTimeout(() => setSaved(false), 2000);
  };

  const toggleApproval = (type: ApprovalType) => {
    const cur = settings.approvalRequired;
    updateSettings({
      approvalRequired: cur.includes(type) ? cur.filter((t) => t !== type) : [...cur, type],
    });
  };

  return (
    <div>
      <PageHeader title="設定" sub="会社情報・デモモード・承認ルール・AI社員" />

      <div className="grid gap-3 lg:grid-cols-2">
        <Card>
          <CardHeader title="Demo Mode" sub="デモ用ダミーデータの表示と自動デモ演出を切り替えます" />
          <div className="p-4">
            <div className="flex items-center gap-3">
              <button
                onClick={() => setDemoMode(!settings.demoMode)}
                className={`relative h-6 w-11 rounded-full transition ${settings.demoMode ? 'bg-emerald-500' : 'bg-slate-300'}`}
                aria-label="Demo Mode切り替え"
                aria-pressed={settings.demoMode}
              >
                <span
                  className={`absolute top-0.5 h-5 w-5 rounded-full bg-white shadow transition-all ${settings.demoMode ? 'left-[22px]' : 'left-0.5'}`}
                />
              </button>
              <p className="text-sm text-slate-700">
                {settings.demoMode ? 'ON: ダミーデータを表示中(AI社員が自動で働く様子を確認できます)' : 'OFF: 通常モード(実データのみ・初期値0)'}
              </p>
            </div>
            <p className="mt-2 text-[11px] leading-relaxed text-slate-400">
              切り替えてもあなたが作成した成果物・AI実行履歴・会社設定は保持されます。ダミーの実績・ログ・案件はDemo Mode ONのときだけ表示されます。
            </p>
          </div>
          <div className="flex items-center gap-3 border-t border-slate-100 p-4">
            <button
              onClick={() => updateSettings({ timeEffects: !(settings.timeEffects ?? true) })}
              className={`relative h-6 w-11 rounded-full transition ${(settings.timeEffects ?? true) ? 'bg-emerald-500' : 'bg-slate-300'}`}
              aria-label="時間帯演出の切り替え"
            >
              <span
                className={`absolute top-0.5 h-5 w-5 rounded-full bg-white shadow transition-all ${(settings.timeEffects ?? true) ? 'left-[22px]' : 'left-0.5'}`}
              />
            </button>
            <p className="text-sm text-slate-700">
              時間帯演出(朝・日中・夕方・夜でオフィスの雰囲気が変化){(settings.timeEffects ?? true) ? ': ON' : ': OFF'}
            </p>
          </div>
          <div className="space-y-3 border-t border-slate-100 p-4">
            <div className="flex flex-wrap items-center gap-3">
              <label className="text-xs font-medium text-slate-600">時間帯の基準</label>
              <select
                value={settings.clockMode ?? 'real'}
                onChange={(e) => updateSettings({ clockMode: e.target.value as 'real' | 'demo' })}
                className="rounded-lg border border-slate-200 px-2 py-1.5 text-xs outline-none"
              >
                <option value="real">実時刻連動</option>
                <option value="demo">デモ時間を進める(約2分で1日)</option>
              </select>
            </div>
            <div className="flex flex-wrap items-center gap-2">
              <span className="text-xs font-medium text-slate-600">会社イベントの再生:</span>
              <Button variant="secondary" onClick={() => useOffice.getState().playAssembly('morning')}>
                🌅 朝会を再生
              </Button>
              <Button variant="secondary" onClick={() => useOffice.getState().playAssembly('evening')}>
                🌇 夕会を再生
              </Button>
              <span className="text-[11px] text-slate-400">再生するとオフィスの社内会話・アナウンスに反映されます</span>
            </div>
          </div>
        </Card>

        <Card>
          <CardHeader title="データ管理" sub="モックデータはブラウザ(localStorage)に永続化されています" />
          <div className="p-4">
            <Button
              variant="danger"
              onClick={() => {
                if (confirm('すべてのデータを初期状態に戻します。よろしいですか?')) resetAll();
              }}
            >
              モックデータを初期化する
            </Button>
          </div>
        </Card>

        <Card>
          <CardHeader title="会社情報" />
          <div className="space-y-3 p-4">
            <Field label="会社名(プロダクト名)">
              <input className={inputCls} value={form.companyName} onChange={(e) => setForm({ ...form, companyName: e.target.value })} />
            </Field>
            <Field label="サブコピー">
              <input className={inputCls} value={form.subCopy} onChange={(e) => setForm({ ...form, subCopy: e.target.value })} />
            </Field>
            <div className="grid grid-cols-2 gap-3">
              <Field label="代表者名">
                <input className={inputCls} value={form.ceoName} onChange={(e) => setForm({ ...form, ceoName: e.target.value })} />
              </Field>
              <Field label="タイムゾーン">
                <input className={inputCls} value={form.timezone} onChange={(e) => setForm({ ...form, timezone: e.target.value })} />
              </Field>
            </div>
            <Field label="事業内容">
              <input className={inputCls} value={form.business} onChange={(e) => setForm({ ...form, business: e.target.value })} />
            </Field>
            <div className="grid grid-cols-2 gap-3">
              <Field label="会社のトーン">
                <input className={inputCls} value={form.tone} onChange={(e) => setForm({ ...form, tone: e.target.value })} />
              </Field>
              <Field label="ブランドカラー">
                <input type="color" className="h-9 w-full cursor-pointer rounded-lg border border-slate-200" value={form.brandColor} onChange={(e) => setForm({ ...form, brandColor: e.target.value })} />
              </Field>
            </div>
            <div className="flex items-center gap-3">
              <Button onClick={save}>保存</Button>
              {saved && <span className="text-xs text-emerald-600">保存しました</span>}
            </div>
          </div>
        </Card>

        <AiRunSettingsCard />

        <SimulationSettingsCard />

        <Card>
          <CardHeader title="承認が必要な処理" sub="チェックされた処理は実行前に承認センターでの承認が必須になります" />
          <div className="grid grid-cols-1 gap-2 p-4 sm:grid-cols-2">
            {(Object.keys(APPROVAL_TYPE) as ApprovalType[]).map((type) => (
              <label key={type} className="flex cursor-pointer items-center gap-2 rounded-lg border border-slate-100 px-3 py-2 text-sm hover:bg-slate-50">
                <input
                  type="checkbox"
                  checked={settings.approvalRequired.includes(type)}
                  onChange={() => toggleApproval(type)}
                  className="h-4 w-4 accent-brand-600"
                />
                {APPROVAL_TYPE[type]}
              </label>
            ))}
          </div>
        </Card>

        <Card className="lg:col-span-2">
          <CardHeader title="AI社員設定" sub="表示名の変更と稼働の停止/再開(名称は一覧・オフィスに即反映)" />
          <div className="grid gap-2 p-4 sm:grid-cols-2 xl:grid-cols-3">
            {agents.map((agent) => (
              <AgentSettingRow key={agent.id} agentId={agent.id} />
            ))}
          </div>
        </Card>
      </div>
    </div>
  );
}

// AI実働(実行基盤)の設定
function AiRunSettingsCard() {
  const settings = useOffice((s) => s.settings);
  const updateSettings = useOffice((s) => s.updateSettings);
  const [status, setStatus] = useState<{ provider: string; model: string; isMock: boolean } | null>(null);

  useState(() => {
    fetch('/api/agent/status')
      .then((r) => r.json())
      .then(setStatus)
      .catch(() => setStatus(null));
    return undefined;
  });

  return (
    <Card>
      <CardHeader
        title="AI実働の設定"
        sub="社長指示チャットの「AI実働モード」で使用するプロバイダーとコスト上限です。APIキーはサーバー側の環境変数で管理され、ブラウザへは渡されません"
      />
      <div className="space-y-3 p-4">
        <div className="flex flex-wrap items-center gap-2 text-sm">
          <span className="text-xs font-medium text-slate-600">現在のプロバイダー:</span>
          {status ? (
            <>
              <Badge className={status.isMock ? 'bg-slate-100 text-slate-600' : 'bg-emerald-50 text-emerald-700'}>
                {status.isMock ? 'モック(デモ生成)' : `実AI: ${status.provider}`}
              </Badge>
              <span className="text-xs text-slate-400">モデル: {status.model}</span>
            </>
          ) : (
            <span className="text-xs text-slate-400">確認中…</span>
          )}
        </div>
        <p className="text-[11px] text-slate-400">
          実AIへ切り替えるには、デプロイ環境の環境変数に <code className="rounded bg-slate-100 px-1">AI_PROVIDER=anthropic</code> と{' '}
          <code className="rounded bg-slate-100 px-1">ANTHROPIC_API_KEY</code> を設定してください(.env.example参照)。未設定でもモックで安全に動作します。
        </p>
        <div>
          <label className="mb-1 block text-xs font-medium text-slate-600">1回の実行あたりのAI利用料上限(円)— 超過時は停止して承認を求めます</label>
          <input
            type="number"
            min={0}
            aria-label="AI実行コスト上限"
            value={settings.aiRunCostCapJpy ?? 500}
            onChange={(e) => updateSettings({ aiRunCostCapJpy: Number(e.target.value) || 0 })}
            className={inputCls + ' max-w-[160px]'}
          />
        </div>
      </div>
    </Card>
  );
}

// 投資家モードのシミュレーション算出条件
function SimulationSettingsCard() {
  const simulation = useOffice((s) => s.settings.simulation) ?? DEFAULT_SIMULATION;
  const updateSettings = useOffice((s) => s.updateSettings);
  const [saved, setSaved] = useState(false);
  const [form, setForm] = useState(simulation);

  return (
    <Card>
      <CardHeader
        title="投資家モード シミュレーション条件"
        sub="年間利益・AI削減人件費・ROIなどの算出条件です。表示値はデモデータを用いたシミュレーションであり、実際の成果を保証するものではありません"
      />
      <div className="space-y-3 p-4">
        <div className="grid gap-3 sm:grid-cols-3">
          <Field label="1人あたりの想定人件費(月・円)">
            <input
              type="number"
              min={0}
              className={inputCls}
              value={form.salaryPerHeadJpy}
              onChange={(e) => setForm({ ...form, salaryPerHeadJpy: Number(e.target.value) || 0 })}
            />
          </Field>
          <Field label="タスク1件の人間換算作業時間(分)">
            <input
              type="number"
              min={1}
              className={inputCls}
              value={form.minutesPerTask}
              onChange={(e) => setForm({ ...form, minutesPerTask: Number(e.target.value) || 1 })}
            />
          </Field>
          <Field label="月間想定労働時間(時間)">
            <input
              type="number"
              min={1}
              className={inputCls}
              value={form.workHoursPerMonth}
              onChange={(e) => setForm({ ...form, workHoursPerMonth: Number(e.target.value) || 1 })}
            />
          </Field>
        </div>
        <div className="flex items-center gap-3">
          <Button
            onClick={() => {
              updateSettings({ simulation: form });
              setSaved(true);
              setTimeout(() => setSaved(false), 2000);
            }}
          >
            算出条件を保存
          </Button>
          {saved && <span className="text-xs text-emerald-600">保存しました。投資家モードへ即時反映されます</span>}
        </div>
      </div>
    </Card>
  );
}

function AgentSettingRow({ agentId }: { agentId: string }) {
  const agent = useOffice((s) => s.agents.find((a) => a.id === agentId))!;
  const renameAgent = useOffice((s) => s.renameAgent);
  const pauseAgent = useOffice((s) => s.pauseAgent);
  const resumeAgent = useOffice((s) => s.resumeAgent);
  const [name, setName] = useState(agent.name);

  const rename = () => renameAgent(agentId, name);
  const togglePause = () => (agent.status === 'paused' ? resumeAgent(agentId) : pauseAgent(agentId));

  return (
    <div className="flex items-center gap-2 rounded-lg border border-slate-100 px-3 py-2">
      <span className="text-lg">{agent.avatar}</span>
      <input
        value={name}
        onChange={(e) => setName(e.target.value)}
        onBlur={rename}
        className="min-w-0 flex-1 rounded border border-transparent px-1 py-0.5 text-sm outline-none hover:border-slate-200 focus:border-brand-400"
      />
      {agent.status === 'paused' && <Badge className="bg-slate-100 text-slate-500">停止中</Badge>}
      <Button variant="ghost" onClick={togglePause} className="shrink-0 px-2 py-1 text-xs">
        {agent.status === 'paused' ? '再開' : '停止'}
      </Button>
    </div>
  );
}

const inputCls = 'w-full rounded-lg border border-slate-200 px-3 py-2 text-sm outline-none focus:border-brand-400';

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <label className="mb-1 block text-xs font-medium text-slate-600">{label}</label>
      {children}
    </div>
  );
}
