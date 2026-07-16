'use client';

// 外部サービス連携
import { Badge, Button, Card, PageHeader } from '@/components/ui';
import { useOffice } from '@/lib/store';

export default function IntegrationsPage() {
  const integrations = useOffice((s) => s.integrations);
  const toggleIntegration = useOffice((s) => s.toggleIntegration);

  const categories = Array.from(new Set(integrations.map((i) => i.category)));

  return (
    <div>
      <PageHeader
        title="外部サービス連携"
        sub="Phase 5で本番接続します。現在はすべてモック動作で、接続構造(環境変数・有効/無効切り替え)のみ用意されています"
      />
      <div className="space-y-6">
        {categories.map((cat) => (
          <section key={cat}>
            <h2 className="mb-2 text-sm font-bold text-slate-700">{cat}</h2>
            <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
              {integrations
                .filter((i) => i.category === cat)
                .map((integration) => (
                  <Card key={integration.id} className="p-4">
                    <div className="flex items-center gap-2">
                      <p className="flex-1 text-sm font-bold text-slate-900">{integration.name}</p>
                      <Badge
                        className={
                          integration.status === 'connected'
                            ? 'bg-emerald-50 text-emerald-700'
                            : integration.status === 'disabled'
                              ? 'bg-slate-100 text-slate-400'
                              : 'bg-amber-50 text-amber-700'
                        }
                      >
                        {integration.status === 'connected' ? '接続済み' : integration.status === 'disabled' ? '無効' : '未接続'}
                      </Badge>
                    </div>
                    <p className="mt-1 text-xs text-slate-500">{integration.description}</p>
                    <div className="mt-2">
                      <p className="text-[10px] font-semibold text-slate-400">必要な環境変数</p>
                      <div className="mt-1 flex flex-wrap gap-1">
                        {integration.requiredEnv.map((env) => (
                          <code key={env} className="rounded bg-slate-100 px-1.5 py-0.5 text-[10px] text-slate-600">{env}</code>
                        ))}
                      </div>
                    </div>
                    <div className="mt-3 border-t border-slate-100 pt-2">
                      <Button variant="secondary" onClick={() => toggleIntegration(integration.id)}>
                        {integration.status === 'disabled' ? '有効化する' : '無効化する'}
                      </Button>
                    </div>
                  </Card>
                ))}
            </div>
          </section>
        ))}
      </div>
    </div>
  );
}
