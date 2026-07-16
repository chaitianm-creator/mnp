// 構造化出力 → Markdown 変換(クライアント・サーバー共用)
import type { DirectorDocOutput, ExecutionPlanOutput, ReviewResultOutput, WriterCopyOutput } from './schemas';

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
