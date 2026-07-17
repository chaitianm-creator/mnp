// 構造化出力 → Markdown 変換(クライアント・サーバー共用)
import type {
  ContentDraftOutput,
  CreativeBriefOutput,
  DirectorDocOutput,
  DistributionPlanOutput,
  ExecutionPlanOutput,
  ReviewResultOutput,
  VisualDesignOutput,
  WriterCopyOutput,
} from './schemas';

const list = (items: string[], prefix = '- ') => items.map((i) => `${prefix}${i}`).join('\n');

export function planToMarkdown(p: ExecutionPlanOutput): string {
  return [
    `# 実行計画: ${p.summary}`,
    `\n## 最終目的\n${p.goal}`,
    `\n## 想定成果物\n${list(p.deliverables)}`,
    p.assumptions.length ? `\n## 前提条件(仮定)\n${list(p.assumptions)}` : '',
    p.missingInformation.length ? `\n## 不足情報(提供いただくと品質が向上)\n${list(p.missingInformation)}` : '',
    `\n## 作業タスク`,
    ...p.tasks.map(
      (t, i) =>
        `\n### ${i + 1}. ${t.title}(担当: ${t.assignedAgentRole})\n${t.description}\n- 依存: ${t.dependsOn.length ? t.dependsOn.map((d) => `タスク${d + 1}`).join(', ') : 'なし'} / 並列可: ${t.canRunInParallel ? 'はい' : 'いいえ'} / 想定トークン: ${t.estimatedTokens.toLocaleString()}`,
    ),
    p.risks.length ? `\n## リスク\n${list(p.risks)}` : '',
    `\n## 完了条件\n${list(p.completionCriteria)}`,
  ]
    .filter(Boolean)
    .join('\n');
}

export function directorToMarkdown(d: DirectorDocOutput): string {
  return [
    `# 要件整理書`,
    `\n## 案件概要\n${d.overview}`,
    `\n## 顧客課題\n${list(d.customerIssues)}`,
    `\n## サイトの目的\n${d.purpose}`,
    `\n## ビジネス目標\n${list(d.businessGoals)}`,
    `\n## ターゲット\n${d.target}`,
    `\n## ペルソナ\n${d.persona}`,
    `\n## ユーザーの悩み\n${list(d.userPains)}`,
    `\n## 提供価値\n${list(d.valueProposition)}`,
    `\n## 競合との差別化\n${list(d.differentiation)}`,
    `\n## コンバージョン\n${d.conversion}`,
    `\n## KPI\n${list(d.kpis)}`,
    `\n## サイトマップ\n${list(d.sitemap)}`,
    `\n## ページ一覧\n${list(d.pages)}`,
    `\n## トップページ構成\n${d.topPageSections.map((s, i) => `${i + 1}. **${s.name}** — ${s.purpose}`).join('\n')}`,
    `\n## 必要素材\n${list(d.requiredAssets)}`,
    `\n## 制作スケジュール\n${list(d.schedule)}`,
    d.openQuestions.length ? `\n## 未確定事項\n${list(d.openQuestions)}` : '',
    d.clientConfirmations.length ? `\n## 顧客確認事項\n${list(d.clientConfirmations)}` : '',
  ]
    .filter(Boolean)
    .join('\n');
}

export function writerToMarkdown(w: WriterCopyOutput): string {
  return [
    `# Web原稿`,
    `\n## メインキャッチコピー\n> ${w.mainCatch}`,
    `\n## サブコピー\n${w.subCopy}`,
    `\n## CTA\n${w.cta}`,
    ...w.sections.map((s) => `\n## ${s.heading}(${s.role})\n${s.body}`),
    `\n## よくある質問\n${w.faq.map((f) => `**Q. ${f.q}**\nA. ${f.a}`).join('\n\n')}`,
    `\n## 会社紹介\n${w.companyIntro}`,
    w.recruitMessage ? `\n## 採用向けメッセージ\n${w.recruitMessage}` : '',
    `\n## SEO\n- タイトル: ${w.seoTitle}\n- メタディスクリプション: ${w.metaDescription}`,
  ]
    .filter(Boolean)
    .join('\n');
}

export function briefToMarkdown(b: CreativeBriefOutput, title = '企画・構成案'): string {
  return [
    `# ${title}`,
    `\n## 概要\n${b.overview}`,
    `\n## 目的\n${b.objective}`,
    `\n## ターゲット\n${b.target}`,
    `\n## キーメッセージ\n> ${b.keyMessage}`,
    `\n## トーン\n${b.toneOfVoice}`,
    `\n## 構成\n${b.structure.map((s, i) => `${i + 1}. **${s.name}** — ${s.purpose}`).join('\n')}`,
    b.constraints.length ? `\n## 制約・前提\n${list(b.constraints)}` : '',
    b.referenceIdeas.length ? `\n## 参考アイデア\n${list(b.referenceIdeas)}` : '',
    b.openQuestions.length ? `\n## 未確定事項\n${list(b.openQuestions)}` : '',
  ]
    .filter(Boolean)
    .join('\n');
}

export function contentToMarkdown(c: ContentDraftOutput, title = '本文・キャプション'): string {
  return [
    `# ${title}`,
    `\n## タイトル・フック\n> ${c.title}`,
    `\n## 本文\n${c.mainText}`,
    c.variations.length ? `\n## 別案\n${c.variations.map((v, i) => `**案${i + 2}:** ${v}`).join('\n\n')}` : '',
    c.hashtags.length ? `\n## ハッシュタグ\n${c.hashtags.map((h) => (h.startsWith('#') ? h : `#${h}`)).join(' ')}` : '',
    `\n## CTA\n${c.cta}`,
    c.notes.length ? `\n## 補足・注意事項\n${list(c.notes)}` : '',
  ]
    .filter(Boolean)
    .join('\n');
}

export function visualToMarkdown(v: VisualDesignOutput, title = 'ビジュアル案'): string {
  return [
    `# ${title}`,
    `\n## デザインコンセプト\n${v.concept}`,
    `\n## レイアウト案\n${v.layoutIdeas.map((l, i) => `${i + 1}. **${l.name}** — ${l.description}`).join('\n')}`,
    `\n## カラーパレット\n${list(v.colorPalette)}`,
    `\n## タイポグラフィ\n${v.typography}`,
    `\n## 画像ディレクション\n${list(v.imageDirections)}`,
    v.sizeVariations.length ? `\n## サイズ展開\n${list(v.sizeVariations)}` : '',
    v.notes.length ? `\n## 補足\n${list(v.notes)}` : '',
  ]
    .filter(Boolean)
    .join('\n');
}

export function distributionToMarkdown(d: DistributionPlanOutput, title = '配信戦略・KPI設計'): string {
  return [
    `# ${title}`,
    `\n## 最適な投稿タイミング\n${d.bestTiming}`,
    `\n## 投稿頻度\n${d.frequency}`,
    `\n## KPI\n${list(d.kpis)}`,
    `\n## ハッシュタグ戦略\n${d.hashtagStrategy}`,
    d.abTestIdeas.length ? `\n## A/Bテスト案\n${list(d.abTestIdeas)}` : '',
    d.crossChannelIdeas.length ? `\n## 他チャネル展開\n${list(d.crossChannelIdeas)}` : '',
    `\n## 想定効果\n${d.expectedEffect}`,
    d.notes.length ? `\n## 補足\n${list(d.notes)}` : '',
  ]
    .filter(Boolean)
    .join('\n');
}

export function reviewToMarkdown(r: ReviewResultOutput): string {
  return [
    `# レビュー報告書`,
    `\n## 総合評価\n${r.overall}\n\n**承認可否: ${r.approve ? '承認' : '要修正(差し戻し)'}**`,
    r.goodPoints.length ? `\n## 良い点\n${list(r.goodPoints)}` : '',
    r.criticalIssues.length ? `\n## 重大な問題\n${list(r.criticalIssues)}` : '\n## 重大な問題\nなし',
    r.minorIssues.length ? `\n## 軽微な問題\n${list(r.minorIssues)}` : '',
    r.suggestions.length ? `\n## 修正提案\n${list(r.suggestions)}` : '',
    r.clientConfirmations.length ? `\n## 顧客確認事項\n${list(r.clientConfirmations)}` : '',
  ]
    .filter(Boolean)
    .join('\n');
}
