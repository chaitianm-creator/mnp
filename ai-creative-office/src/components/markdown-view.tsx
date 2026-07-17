'use client';

// 安全なMarkdown表示(XSS対策: 先に全HTMLをエスケープしてから装飾タグを付与)
// 外部ライブラリに依存しない軽量実装。見出し/太字/引用/リストのみ対応
import { useMemo } from 'react';

function escapeHtml(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

function render(md: string): string {
  const lines = escapeHtml(md).split('\n');
  const out: string[] = [];
  let inList = false;
  const closeList = () => {
    if (inList) {
      out.push('</ul>');
      inList = false;
    }
  };
  for (const raw of lines) {
    const line = raw.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
    if (/^### /.test(line)) { closeList(); out.push(`<h4>${line.slice(4)}</h4>`); continue; }
    if (/^## /.test(line)) { closeList(); out.push(`<h3>${line.slice(3)}</h3>`); continue; }
    if (/^# /.test(line)) { closeList(); out.push(`<h2>${line.slice(2)}</h2>`); continue; }
    if (/^&gt; /.test(line)) { closeList(); out.push(`<blockquote>${line.slice(5)}</blockquote>`); continue; }
    if (/^[-・] /.test(line) || /^\d+\. /.test(line)) {
      if (!inList) { out.push('<ul>'); inList = true; }
      out.push(`<li>${line.replace(/^[-・] /, '').replace(/^\d+\. /, '')}</li>`);
      continue;
    }
    if (line.trim() === '') { closeList(); out.push('<div class="md-space"></div>'); continue; }
    closeList();
    out.push(`<p>${line}</p>`);
  }
  closeList();
  return out.join('');
}

export function MarkdownView({ markdown, className }: { markdown: string; className?: string }) {
  const html = useMemo(() => render(markdown), [markdown]);
  return (
    <div
      className={`md-view text-[13px] leading-relaxed text-slate-700 ${className ?? ''}`}
      // escapeHtml済みのテキストにのみタグを付与しているためXSS安全
      dangerouslySetInnerHTML={{ __html: html }}
    />
  );
}
