// プロバイダーの選択(サーバー専用)
// AI_PROVIDER=anthropic かつ ANTHROPIC_API_KEY がある場合のみ実AIを使用。
// それ以外は常にMockへフォールバックし、アプリはエラーにならない。
import 'server-only';
import { AnthropicAIProvider } from './anthropic';
import { MockAIProvider } from './mock';
import type { AIProvider } from './provider';

let cached: AIProvider | null = null;

export function getProvider(): AIProvider {
  if (cached) return cached;
  const requested = (process.env.AI_PROVIDER ?? 'mock').toLowerCase();
  const anthropicKey = process.env.ANTHROPIC_API_KEY;

  if (requested === 'anthropic' && anthropicKey) {
    cached = new AnthropicAIProvider(anthropicKey, process.env.ANTHROPIC_MODEL);
    return cached;
  }
  // openai / gemini は将来対応(未実装のためMockへフォールバック)
  cached = new MockAIProvider();
  return cached;
}

export function providerStatus() {
  const p = getProvider();
  return { provider: p.name, model: p.model, isMock: p.isMock };
}
