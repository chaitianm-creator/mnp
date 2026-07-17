// MockAIProvider: APIキーなしでも成果物生成フローを体験できるデモ用プロバイダー
// 単なる待機ではなく、依頼文を織り込んだ現実的なサンプル成果物を生成する。
// 生成物には isMock=true が付与され、画面上で「デモ生成」と表示される。
import 'server-only';
import { BaseProvider, type GenerateOptions, type GenerateResult } from './provider';

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

/** 依頼文から題材キーワードを推定(モック成果物の現実感用) */
function themeOf(request: string): { theme: string; audience: string; siteType: string } {
  const theme = request.includes('採用')
    ? '採用'
    : request.includes('LP')
      ? 'LP'
      : request.includes('サービス')
        ? 'サービス紹介'
        : request.includes('SEO') || request.includes('記事')
          ? 'SEO記事'
          : 'コーポレート';
  const audience = request.includes('中小企業') ? '中小企業' : request.includes('求職') ? '求職者' : '見込み顧客';
  const siteType = theme === '採用' ? '採用サイト' : theme === 'LP' ? 'ランディングページ' : `${theme}サイト`;
  return { theme, audience, siteType };
}

export class MockAIProvider extends BaseProvider {
  readonly name = 'mock';
  readonly isMock = true;
  readonly model = 'mock-agent-v1';

  listAvailableModels(): string[] {
    return ['mock-agent-v1'];
  }

  async validateConnection(): Promise<boolean> {
    return true;
  }

  estimateCost(): number {
    return 0; // モックは料金¥0(画面には推定表示なしの¥0として記録)
  }

  async generateText(options: GenerateOptions): Promise<GenerateResult> {
    await sleep(500 + Math.random() * 500); // 現実的な生成時間の演出
    const request = options.prompt;
    const { theme, audience, siteType } = themeOf(request);
    let payload: unknown;

    if (options.system.includes('[ROLE:CEO]')) {
      payload = {
        summary: `${siteType}の企画案作成(${audience}向け)`,
        goal: `${audience}の課題に応える${siteType}の企画・構成・原稿を作成し、社長が確認できる状態にする`,
        assumptions: ['ブランドトーンは既存の会社設定(誠実・提案型)を踏襲します', '公開・共有は行わず、社内確認用の成果物とします'],
        missingInformation: ['具体的な顧客社名・実績数値(あれば品質が向上します)'],
        deliverables: ['要件整理書(ディレクターAI)', 'キャッチコピー・Web原稿(ライターAI)', 'レビュー報告書(レビュアーAI)'],
        tasks: [
          { title: '要件整理とサイト構成の作成', description: 'ターゲット・ペルソナ・サイトマップ・トップページ構成を整理', assignedAgentRole: 'director', dependsOn: [], canRunInParallel: false, requiresApproval: false, estimatedTokens: 2600, estimatedCostJPY: 0 },
          { title: 'キャッチコピー・原稿の作成', description: '構成に沿ってコピーと本文を執筆', assignedAgentRole: 'writer', dependsOn: [0], canRunInParallel: false, requiresApproval: false, estimatedTokens: 3200, estimatedCostJPY: 0 },
          { title: '品質レビュー', description: '整合性・誇大表現・誤字・SEO・要確認事項をチェック', assignedAgentRole: 'reviewer', dependsOn: [1], canRunInParallel: false, requiresApproval: false, estimatedTokens: 1800, estimatedCostJPY: 0 },
        ],
        risks: ['実績・数値は仮置きのため、公開前に実データへの差し替えが必要です'],
        completionCriteria: ['レビュー承認済みの構成資料と原稿が成果物として保存されている'],
      };
    } else if (options.system.includes('[ROLE:DIRECTOR]')) {
      payload = {
        overview: `${audience}向け${siteType}の制作案件。依頼内容:「${request.slice(0, 80)}」`,
        customerIssues: ['応募・問い合わせの数が不足している', '自社の魅力を言語化できていない', '既存サイトが情報の羅列になっている'],
        purpose: `${siteType}を通じて、${audience}からの反応(応募・問い合わせ)を増やす`,
        businessGoals: ['月間の応募/問い合わせ数を現状の2倍にする', '面談・商談へ進む率を高める'],
        target: theme === '採用' ? '20〜30代の転職検討層(業界経験1年以上)' : `${audience}の意思決定者・担当者`,
        persona: theme === '採用' ? '28歳・現職に将来性の不安。働く環境と成長機会を重視し、応募前に必ず社員の声を確認する。' : '42歳・部門責任者。費用対効果と実績を重視し、比較検討に時間をかける。',
        userPains: ['情報が多すぎて判断できない', '実際の雰囲気・実態が見えない', '問い合わせのハードルが高い'],
        valueProposition: ['判断に必要な情報を1ページで完結', '実例・声による信頼の担保', '次の行動(CTA)が常に明確'],
        differentiation: ['ターゲットの意思決定プロセスに沿った情報設計', '誇大表現を避けた誠実なトーン'],
        conversion: theme === '採用' ? '応募フォーム送信(副CV: カジュアル面談申込)' : '問い合わせフォーム送信(副CV: 資料請求)',
        kpis: ['CV数/月', 'CV率', '直帰率', '主要ページの読了率'],
        sitemap: ['トップ', theme === '採用' ? '仕事内容' : 'サービス', theme === '採用' ? '社員インタビュー' : '実績', theme === '採用' ? '働く環境・待遇' : '料金', 'よくある質問', theme === '採用' ? '応募フォーム' : 'お問い合わせ'],
        pages: ['トップページ(本件の成果物対象)', '下層ページ(第2期で制作)'],
        topPageSections: [
          { name: 'ファーストビュー', purpose: '3秒で「自分向けのサイト」と認識させ、CTAを提示する' },
          { name: '課題への共感', purpose: `${audience}の悩みを言語化し、読み進める理由を作る` },
          { name: '提供価値', purpose: '課題がどう解決されるかを具体的に示す' },
          { name: '選ばれる理由', purpose: '差別化ポイントを3点に絞って伝える' },
          { name: '実例・声', purpose: '第三者の声で信頼を担保する(実データ要確認)' },
          { name: '利用の流れ', purpose: '行動後の見通しを示し、不安を減らす' },
          { name: 'よくある質問', purpose: '最後の疑問を解消する' },
          { name: 'CTA', purpose: '迷いなく行動できる締めの一押し' },
        ],
        requiredAssets: ['ロゴデータ', '写真素材(職場・人物)', '実績・数値データ(要提供)'],
        schedule: ['要件確定: 承認後すぐ', '原稿: 同日', 'レビュー・修正: 同日', 'デザイン着手: 別途'],
        openQuestions: ['メインカラーの指定はあるか', '既存サイトからの流用素材はあるか'],
        clientConfirmations: ['実績数値・お客様の声の提供可否', 'CV導線(フォーム項目)の確認'],
      };
    } else if (options.system.includes('[ROLE:WRITER]')) {
      const revised = request.includes('[修正指示]');
      const mainCatch = theme === '採用'
        ? revised ? '「ここでなら、成長できる」を実感できる会社' : '次のキャリアは、顔の見える会社で'
        : revised ? '成果につながるWebサイトを、最短距離で' : 'その課題、私たちが一緒に解決します';
      payload = {
        mainCatch,
        subCopy: theme === '採用' ? '仕事内容も、働く人も、待遇も。応募前に知りたいことを、ぜんぶ載せました。' : '目的から逆算した情報設計で、見た目だけで終わらないサイトを作ります。',
        cta: theme === '採用' ? 'まずはカジュアル面談で話を聞いてみる' : '無料相談で課題を整理する',
        sections: [
          { heading: 'こんなお悩みはありませんか', body: `・${audience}に情報が届いていない\n・魅力をうまく言葉にできない\n・行動(応募・問い合わせ)につながらない\n\nそのお悩み、情報の「順番」を変えるだけで大きく改善できます。`, role: '課題への共感' },
          { heading: '私たちが提供できること', body: '判断に必要な情報を、読み手の意思決定プロセスに沿って再設計します。読みやすさではなく「行動しやすさ」を基準に、各セクションの役割を明確にします。', role: '提供価値' },
          { heading: '選ばれる3つの理由', body: '1. ターゲット起点の情報設計\n2. 誇大表現を使わない誠実なコピー\n3. 公開後の改善まで見据えた構成', role: '選ばれる理由' },
          { heading: '導入実績', body: '導入実績: [実績情報をご提供ください]\nお客様の声: [掲載許諾済みの声をご提供ください]', role: '実績(要確認)' },
          { heading: 'ご利用の流れ', body: '1. 無料相談(30分)\n2. 要件整理・構成案のご提示\n3. 原稿・デザインの制作\n4. 確認・修正\n5. 納品', role: '利用の流れ' },
        ],
        faq: [
          { q: '相談だけでも可能ですか?', a: 'はい。現状の課題整理だけでもお気軽にご相談ください。' },
          { q: '費用はどのくらいかかりますか?', a: '[料金体系をご提供ください — 確定後に記載します]' },
          { q: '制作期間はどのくらいですか?', a: '規模により異なりますが、標準的なサイトで6〜8週間が目安です。' },
        ],
        companyIntro: '私たちは、AI社員と人間が協working体制で運営する少数精鋭のWeb制作チームです。目的から逆算した設計と、誠実なコピーライティングを大切にしています。',
        recruitMessage: theme === '採用' ? '肩書きより、あなたが「何をしたいか」を聞かせてください。私たちは挑戦する人の背中を押す会社です。' : '',
        seoTitle: theme === '採用' ? '採用情報 | 働く人と環境が見える採用サイト' : `${siteType}制作 | 成果につながる情報設計`,
        metaDescription: theme === '採用' ? '仕事内容・社員の声・待遇まで、応募前に知りたい情報をまとめた採用サイトです。カジュアル面談も受付中。' : '目的から逆算した情報設計で、行動につながるWebサイトを制作します。無料相談受付中。',
      };
    } else {
      // [ROLE:REVIEWER]
      const isRevision = request.includes('[修正版]');
      payload = isRevision
        ? {
            overall: '修正版を確認しました。重大な問題は解消されています。承認可能です。',
            goodPoints: ['CTAの文言が具体的になり、行動イメージが明確になりました', '実績はプレースホルダー化され、根拠のない数字がありません'],
            criticalIssues: [],
            minorIssues: ['FAQの料金回答は確定後の差し替えを忘れないでください'],
            suggestions: ['公開前にメタディスクリプションの文字数(120字前後)を最終確認してください'],
            clientConfirmations: ['実績数値・お客様の声の提供', '料金体系の確定'],
            approve: true,
          }
        : {
            overall: '全体の構成と整合性は良好ですが、修正が必要な重大な問題が1件あります。',
            goodPoints: ['ターゲットと構成の整合性が取れています', '誇大表現がなく、トーンが誠実です'],
            criticalIssues: ['メインキャッチがターゲットの一人称視点になっておらず、ファーストビューの役割(自分ごと化)を十分に果たせていません。より当事者視点の表現へ修正が必要です。'],
            minorIssues: ['「協working体制」に表記揺れがあります(「協働体制」へ統一)', 'CTAが2種類あり、優先順位の明示が望ましいです'],
            suggestions: ['ファーストビュー直下に信頼要素(実績プレースホルダー)を1行追加すると離脱を防げます'],
            clientConfirmations: ['実績数値・お客様の声の提供可否'],
            approve: false,
          };
    }

    const text = JSON.stringify(payload);
    return {
      text,
      inputTokens: Math.ceil((options.system.length + options.prompt.length) / 4),
      outputTokens: Math.ceil(text.length / 3),
      estimated: true,
    };
  }
}
