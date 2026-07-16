// 現在のAIプロバイダー状態(APIキーは返さない)
import { providerStatus } from '@/lib/ai/server';
import { NextResponse } from 'next/server';

export const runtime = 'nodejs';

export async function GET() {
  return NextResponse.json(providerStatus());
}
