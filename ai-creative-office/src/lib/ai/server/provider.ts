// ============================================================
// AIプロバイダー抽象化(サーバー専用 — APIキーはクライアントへ渡さない)
// MockAIProvider / AnthropicAIProvider を同一インターフェースで提供し、
// 将来 OpenAI / Gemini を追加できるようにする。
// ============================================================
import 'server-only';
import type { ZodSchema } from 'zod';

export interface GenerateOptions {
  system: string;
  prompt: string;
  maxTokens?: number;
}

export interface GenerateResult {
  text: string;
  inputTokens: number;
  outputTokens: number;
  estimated: boolean; // トークン数が推定値か
}

export interface AIProvider {
  readonly name: string;
  readonly model: string;
  readonly isMock: boolean;
  generateText(options: GenerateOptions): Promise<GenerateResult>;
  /** JSONを生成しZodで検証する。失敗時はmaxRetriesまで再試行 */
  generateStructuredOutput<T>(options: GenerateOptions & { schema: ZodSchema<T>; maxRetries?: number }): Promise<GenerateResult & { data: T }>;
  estimateCost(inputTokens: number, outputTokens: number): number; // USD
  validateConnection(): Promise<boolean>;
  listAvailableModels(): string[];
  // streamText(): 将来対応(構造化出力を壊さないため初期版では未実装)
}

/** $/1Mトークンの単価表(設定画面のレート変更はJPY換算側で反映) */
const PRICING: Record<string, { input: number; output: number }> = {
  'claude-sonnet-5': { input: 3, output: 15 },
  'claude-haiku-4-5': { input: 1, output: 5 },
  'claude-fable-5': { input: 5, output: 25 },
  default: { input: 3, output: 15 },
};

export function pricingFor(model: string) {
  return PRICING[model] ?? PRICING.default;
}

function extractJson(text: string): string {
  // コードフェンスや前置きが混ざっても最初のJSONオブジェクトを取り出す
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  const candidate = fenced ? fenced[1] : text;
  const start = candidate.indexOf('{');
  const end = candidate.lastIndexOf('}');
  if (start === -1 || end === -1 || end <= start) throw new Error('JSONが見つかりません');
  return candidate.slice(start, end + 1);
}

export abstract class BaseProvider implements AIProvider {
  abstract readonly name: string;
  abstract readonly model: string;
  abstract readonly isMock: boolean;
  abstract generateText(options: GenerateOptions): Promise<GenerateResult>;
  abstract validateConnection(): Promise<boolean>;
  abstract listAvailableModels(): string[];

  estimateCost(inputTokens: number, outputTokens: number): number {
    const p = pricingFor(this.model);
    return (inputTokens / 1e6) * p.input + (outputTokens / 1e6) * p.output;
  }

  async generateStructuredOutput<T>(
    options: GenerateOptions & { schema: ZodSchema<T>; maxRetries?: number },
  ): Promise<GenerateResult & { data: T }> {
    const maxRetries = options.maxRetries ?? 2;
    let lastError = '';
    let totalIn = 0;
    let totalOut = 0;
    let estimated = false;
    for (let attempt = 0; attempt <= maxRetries; attempt++) {
      const retryHint =
        attempt === 0
          ? ''
          : `\n\n前回の出力はスキーマ検証に失敗しました(${lastError.slice(0, 200)})。必ず指定スキーマに一致するJSONオブジェクトのみを出力してください。`;
      const result = await this.generateText({
        system: options.system,
        prompt: options.prompt + retryHint,
        maxTokens: options.maxTokens,
      });
      totalIn += result.inputTokens;
      totalOut += result.outputTokens;
      estimated = estimated || result.estimated;
      try {
        const parsed = options.schema.parse(JSON.parse(extractJson(result.text)));
        return { ...result, inputTokens: totalIn, outputTokens: totalOut, estimated, data: parsed };
      } catch (e) {
        lastError = e instanceof Error ? e.message : String(e);
      }
    }
    throw new Error(`構造化出力に${maxRetries + 1}回失敗しました: ${lastError.slice(0, 300)}`);
  }
}
