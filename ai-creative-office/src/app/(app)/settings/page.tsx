'use client';

// 会社設定 + デモモード + AI社員設定
import { Badge, Button, Card, CardHeader, PageHeader } from '@/components/ui';
import { APPROVAL_TYPE } from '@/lib/labels';
import { useOffice } from '@/lib/store';
import type { ApprovalType } from '@/lib/types';
import { useState } from 'react';

export default function SettingsPage() {
  const settings = useOffice((s) => s.settings);
  const agents = useOffice((s) => s.agents);
  const updateSettings = useOffice((s) => s.updateSettings);
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
          <CardHeader title="デモモード" sub="AI社員が自動的に働き、数値・進捗・ログが動きます" />
          <div className="flex items-center gap-3 p-4">
            <button
              onClick={() => updateSettings({ demoMode: !settings.demoMode })}
              className={`relative h-6 w-11 rounded-full transition ${settings.demoMode ? 'bg-emerald-500' : 'bg-slate-300'}`}
              aria-label="デモモード切り替え"
            >
              <span
                className={`absolute top-0.5 h-5 w-5 rounded-full bg-white shadow transition-all ${settings.demoMode ? 'left-[22px]' : 'left-0.5'}`}
              />
            </button>
            <p className="text-sm text-slate-700">{settings.demoMode ? '稼働中(2.5秒ごとに更新)' : '停止中'}</p>
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

function AgentSettingRow({ agentId }: { agentId: string }) {
  const agent = useOffice((s) => s.agents.find((a) => a.id === agentId))!;
  const [name, setName] = useState(agent.name);

  const rename = () => {
    useOffice.setState((s) => ({
      agents: s.agents.map((a) => (a.id === agentId ? { ...a, name: name || a.name } : a)),
    }));
  };
  const togglePause = () => {
    useOffice.setState((s) => ({
      agents: s.agents.map((a) =>
        a.id === agentId
          ? { ...a, status: a.status === 'paused' ? 'idle' : 'paused', statusNote: a.status === 'paused' ? '次のタスク待ち' : '停止中(社長指示)' }
          : a,
      ),
    }));
  };

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
