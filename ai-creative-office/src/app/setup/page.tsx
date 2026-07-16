'use client';

// 初期設定ウィザード
import { Button, Card } from '@/components/ui';
import { useOffice } from '@/lib/store';
import { useRouter } from 'next/navigation';
import { useState } from 'react';

export default function SetupPage() {
  const router = useRouter();
  const settings = useOffice((s) => s.settings);
  const updateSettings = useOffice((s) => s.updateSettings);
  const [form, setForm] = useState({
    companyName: settings.companyName,
    ceoName: settings.ceoName === '社長' ? '' : settings.ceoName,
    business: settings.business,
    targetCustomer: settings.targetCustomer,
    salesRegions: settings.salesRegions.join('、'),
    salesIndustries: settings.salesIndustries.join('、'),
    prohibitedTargets: settings.prohibitedTargets,
    tone: settings.tone,
    brandColor: settings.brandColor,
    monthlyAiBudgetJpy: settings.monthlyAiBudgetJpy,
    timezone: settings.timezone,
  });

  const set = (k: string, v: string | number) => setForm((f) => ({ ...f, [k]: v }));

  return (
    <div className="min-h-screen bg-gradient-to-br from-brand-50 via-white to-accent-400/10 px-4 py-10">
      <div className="mx-auto max-w-2xl">
        <p className="bg-gradient-to-r from-brand-600 to-accent-600 bg-clip-text text-center text-2xl font-extrabold text-transparent">
          はじめまして、社長。
        </p>
        <p className="mt-2 text-center text-sm text-slate-500">
          AI社員たちが働く会社の基本情報を設定してください。あとから会社設定でいつでも変更できます。
        </p>
        <Card className="mt-6 space-y-4 p-6">
          <Field label="会社名">
            <input className={inputCls} value={form.companyName} onChange={(e) => set('companyName', e.target.value)} />
          </Field>
          <Field label="代表者名">
            <input className={inputCls} placeholder="例: 山田 太郎" value={form.ceoName} onChange={(e) => set('ceoName', e.target.value)} />
          </Field>
          <Field label="事業内容">
            <input className={inputCls} value={form.business} onChange={(e) => set('business', e.target.value)} />
          </Field>
          <Field label="ターゲット顧客">
            <input className={inputCls} value={form.targetCustomer} onChange={(e) => set('targetCustomer', e.target.value)} />
          </Field>
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="営業対象地域(読点区切り)">
              <input className={inputCls} value={form.salesRegions} onChange={(e) => set('salesRegions', e.target.value)} />
            </Field>
            <Field label="営業対象業種(読点区切り)">
              <input className={inputCls} value={form.salesIndustries} onChange={(e) => set('salesIndustries', e.target.value)} />
            </Field>
          </div>
          <Field label="営業禁止条件">
            <textarea className={inputCls} rows={2} value={form.prohibitedTargets} onChange={(e) => set('prohibitedTargets', e.target.value)} />
          </Field>
          <div className="grid gap-4 sm:grid-cols-3">
            <Field label="会社のトーン">
              <input className={inputCls} value={form.tone} onChange={(e) => set('tone', e.target.value)} />
            </Field>
            <Field label="ブランドカラー">
              <input type="color" className="h-9 w-full cursor-pointer rounded-lg border border-slate-200" value={form.brandColor} onChange={(e) => set('brandColor', e.target.value)} />
            </Field>
            <Field label="月間AI利用予算(円)">
              <input type="number" className={inputCls} value={form.monthlyAiBudgetJpy} onChange={(e) => set('monthlyAiBudgetJpy', Number(e.target.value))} />
            </Field>
          </div>
          <Button
            className="w-full py-2.5"
            onClick={() => {
              updateSettings({
                companyName: form.companyName || 'AI CREATIVE OFFICE',
                ceoName: form.ceoName || '社長',
                business: form.business,
                targetCustomer: form.targetCustomer,
                salesRegions: form.salesRegions.split(/[、,]/).map((s) => s.trim()).filter(Boolean),
                salesIndustries: form.salesIndustries.split(/[、,]/).map((s) => s.trim()).filter(Boolean),
                prohibitedTargets: form.prohibitedTargets,
                tone: form.tone,
                brandColor: form.brandColor,
                monthlyAiBudgetJpy: form.monthlyAiBudgetJpy,
                setupCompleted: true,
              });
              router.push('/office');
            }}
          >
            設定を保存して出社する
          </Button>
        </Card>
      </div>
    </div>
  );
}

const inputCls =
  'w-full rounded-lg border border-slate-200 px-3 py-2 text-sm outline-none focus:border-brand-400';

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <label className="mb-1 block text-xs font-medium text-slate-600">{label}</label>
      {children}
    </div>
  );
}
