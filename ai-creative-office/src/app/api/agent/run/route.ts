// AI社員の実行エンドポイント(APIキーはここより先=サーバー内でのみ使用)
import { getProvider } from '@/lib/ai/server';
import { buildUserPrompt, SYSTEM_PROMPTS } from '@/lib/ai/server/prompts';
import { RunRequestSchema, SCHEMA_BY_KIND, type RunResponse } from '@/lib/ai/schemas';
import { NextResponse, type NextRequest } from 'next/server';
import type { ZodType } from 'zod';

export const runtime = 'nodejs';
export const maxDuration = 120;

// 簡易Rate Limit(インスタンス内): 1分あたり20リクエスト/IP
const hits = new Map<string, number[]>();
const RATE_LIMIT = 20;

function rateLimited(ip: string): boolean {
  const now = Date.now();
  const list = (hits.get(ip) ?? []).filter((t) => now - t < 60_000);
  list.push(now);
  hits.set(ip, list);
  if (hits.size > 1000) hits.clear(); // メモリ保護
  return list.length > RATE_LIMIT;
}

export async function POST(req: NextRequest): Promise<NextResponse<RunResponse>> {
  const ip = req.headers.get('x-forwarded-for')?.split(',')[0] ?? 'local';
  if (rateLimited(ip)) {
    return NextResponse.json({ ok: false, error: '実行回数の上限に達しました。1分ほど待って再実行してください' }, { status: 429 });
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ ok: false, error: 'リクエスト形式が不正です' }, { status: 400 });
  }
  const parsed = RunRequestSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ ok: false, error: '入力の検証に失敗しました(サイズ上限超過または必須項目不足)' }, { status: 400 });
  }
  const { kind, request, context, revisionNotes, caseLabel } = parsed.data;

  const provider = getProvider();
  const maxTokens = Math.min(Number(process.env.AI_MAX_TOKENS_PER_TASK ?? 4000) || 4000, 8000);
  const started = Date.now();
  try {
    const result = await provider.generateStructuredOutput({
      system: SYSTEM_PROMPTS[kind],
      prompt: buildUserPrompt(kind, request, context, revisionNotes, caseLabel),
      schema: SCHEMA_BY_KIND[kind] as ZodType<unknown>,
      maxTokens,
      maxRetries: 2,
    });
    return NextResponse.json({
      ok: true,
      data: result.data,
      usage: {
        provider: provider.name,
        model: provider.model,
        inputTokens: result.inputTokens,
        outputTokens: result.outputTokens,
        costUSD: provider.estimateCost(result.inputTokens, result.outputTokens),
        isMock: provider.isMock,
        estimated: result.estimated,
        durationMs: Date.now() - started,
      },
    });
  } catch (e) {
    // エラーメッセージにAPIキー等の機密が含まれないことはプロバイダー側で保証
    const message = e instanceof Error ? e.message : 'AI実行に失敗しました';
    return NextResponse.json({ ok: false, error: message }, { status: 502 });
  }
}
