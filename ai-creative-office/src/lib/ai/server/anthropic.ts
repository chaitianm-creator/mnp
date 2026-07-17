// Anthropic Claude プロバイダー(サーバー専用・fetchベースでSDK依存なし)
import 'server-only';
import { BaseProvider, type GenerateOptions, type GenerateResult } from './provider';

const API_URL = 'https://api.anthropic.com/v1/messages';
const DEFAULT_MODEL = 'claude-sonnet-5';
const TIMEOUT_MS = 60_000;

export class AnthropicAIProvider extends BaseProvider {
  readonly name = 'anthropic';
  readonly isMock = false;
  readonly model: string;
  private readonly apiKey: string;

  constructor(apiKey: string, model?: string) {
    super();
    this.apiKey = apiKey;
    this.model = model || DEFAULT_MODEL;
  }

  listAvailableModels(): string[] {
    return ['claude-fable-5', 'claude-sonnet-5', 'claude-haiku-4-5'];
  }

  async validateConnection(): Promise<boolean> {
    try {
      const r = await this.generateText({ system: 'You are a health check.', prompt: 'ping', maxTokens: 8 });
      return r.text.length > 0;
    } catch {
      return false;
    }
  }

  async generateText(options: GenerateOptions): Promise<GenerateResult> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
    try {
      const res = await fetch(API_URL, {
        method: 'POST',
        signal: controller.signal,
        headers: {
          'content-type': 'application/json',
          'x-api-key': this.apiKey, // ログには一切出さない
          'anthropic-version': '2023-06-01',
        },
        body: JSON.stringify({
          model: this.model,
          max_tokens: options.maxTokens ?? 4000,
          system: options.system,
          messages: [{ role: 'user', content: options.prompt }],
        }),
      });
      if (!res.ok) {
        // エラーメッセージにAPIキーが含まれないよう、ステータスと種別のみ伝える
        if (res.status === 429) throw new Error('レート制限に達しました。しばらく待って再実行してください');
        if (res.status === 401) throw new Error('APIキーが無効です。設定を確認してください');
        throw new Error(`AI API接続に失敗しました(HTTP ${res.status})`);
      }
      const json = (await res.json()) as {
        content: { type: string; text?: string }[];
        usage?: { input_tokens: number; output_tokens: number };
      };
      const text = json.content
        .filter((c) => c.type === 'text')
        .map((c) => c.text ?? '')
        .join('');
      // Anthropic APIは実利用量を返すため、実値を記録する
      return {
        text,
        inputTokens: json.usage?.input_tokens ?? Math.ceil((options.system.length + options.prompt.length) / 4),
        outputTokens: json.usage?.output_tokens ?? Math.ceil(text.length / 4),
        estimated: !json.usage,
      };
    } catch (e) {
      if (e instanceof Error && e.name === 'AbortError') {
        throw new Error('AI API呼び出しがタイムアウトしました(60秒)');
      }
      throw e;
    } finally {
      clearTimeout(timer);
    }
  }
}
