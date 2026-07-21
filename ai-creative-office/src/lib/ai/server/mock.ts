// MockAIProvider: APIキーなしでも成果物生成フローを体験できるデモ用プロバイダー
// 単なる待機ではなく、依頼文を織り込んだ現実的なサンプル成果物を生成する。
// 生成物には isMock=true が付与され、画面上で「デモ生成」と表示される。
import 'server-only';
import { CASE_DEFS, classifyRequest, type CaseDef } from '../../case-types';
import { BaseProvider, type GenerateOptions, type GenerateResult } from './provider';

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

/** プロンプトから案件種別を復元(【案件種別】ラベル優先、なければ依頼文から判定) */
function caseOf(prompt: string): CaseDef {
  const m = prompt.match(/【案件種別】(.+)/);
  if (m) {
    const label = m[1].trim();
    const hit = Object.values(CASE_DEFS).find((d) => d.label === label);
    if (hit) return hit;
  }
  const req = prompt.match(/【社長の依頼】\n([\s\S]+?)(\n\n|$)/)?.[1] ?? prompt;
  return CASE_DEFS[classifyRequest(req)];
}

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

// ============================================================
// 案件ルームの会話型AI(デモ用の意図理解エンジン)
// ユーザーの入力を依頼として解釈し、ChatGPTのように直接回答する
// ============================================================

interface TaskWorkPayload {
  reply: string;
  suggestions: { approaches: string[]; checkpoints: string[]; nextActions: string[]; missingInfo: string[] } | null;
  artifact: { title: string; kind: string; content: string } | null;
}

/** 指示行(「〜返信文を考えて」等)かどうか。相手メッセージ本文と区別するための判定 */
function isInstructionLine(line: string): boolean {
  const l = line.trim();
  if (/^(上記|以下|これ|この内容|先方から|相手から)/.test(l)) return true;
  return (
    /(返信|返事|メール|文面|文章|下書き|リライト|要約|議事録|別案|提案|整理)/.test(l) &&
    /(考えて|作って|作成して|書いて|直して|まとめて|出して|して)(ください|ほしい|欲しい|もらえますか|もらえる)?[。..!]?$/.test(l)
  );
}

/** 入力から「ユーザーの指示」と「貼り付けられた相手メッセージ本文」を分離する */
function splitRequest(req: string): { instr: string; body: string; explicit: boolean } {
  const lines = req.split('\n').map((l) => l.trim()).filter(Boolean);
  const instrLines = lines.filter((l) => l.length <= 80 && isInstructionLine(l));
  const bodyLines = lines.filter((l) => !instrLines.includes(l) && !/^[【・\-*]/.test(l));
  const body = bodyLines.join('\n').trim();
  return { instr: instrLines.join(' ') || req, body: body.length >= 20 ? body : '', explicit: instrLines.length > 0 };
}

/** 会話履歴から相手メッセージらしき貼り付け(長文の社長発言)を探す */
function bodyFromConversation(conv: string): string {
  const segs = conv.split(/\n(?=(?:社長|AI): )/).filter((s) => s.startsWith('社長: '));
  for (let i = segs.length - 1; i >= 0; i--) {
    const { body } = splitRequest(segs[i].replace(/^社長: /, ''));
    if (body.length >= 30) return body;
  }
  return '';
}

function taskAssistantPayload(prompt: string): TaskWorkPayload {
  // 最新のユーザー依頼(【社長の依頼】ブロック)と案件コンテキストを取り出す
  const req = (prompt.match(/【社長の依頼】\n([\s\S]+?)(\n\n【|$)/)?.[1] ?? prompt).trim();
  const source = prompt.match(/【元の指示・依頼内容(全文)】\n([\s\S]+?)(?=\n\n【|$)/)?.[1]?.trim() ?? '';
  const conv = prompt.match(/【この案件のこれまでの会話】\n([\s\S]+?)(?=\n\n【|$)/)?.[1] ?? '';
  const latestM = prompt.match(/【現在の最新版成果物(?:\(([^)]+)\))?: ?([^】]+)】\n([\s\S]+?)(?=\n\n【|$)/);
  const latestKind = latestM?.[1]?.trim() || '返信文案';
  const latestTitle = latestM?.[2]?.trim() ?? '';
  const latestContent = latestM?.[3]?.trim() ?? '';
  const taskTitle = prompt.match(/タスク名: ([^/\n]+)/)?.[1]?.trim() ?? '';
  const deadline = prompt.match(/期限: ([^/\n]+)/)?.[1]?.trim();
  const subject = taskTitle || source.split('\n')[0]?.slice(0, 24) || 'ご依頼の件';
  const firstLine = (t: string) => t.split('\n').find((l) => l.trim()) ?? '';
  const sentences = (t: string) => t.replace(/\n+/g, ' ').split(/(?<=[。!?!?])/).map((x) => x.trim()).filter(Boolean);

  // 入力を「指示」と「相手メッセージ本文」に分離し、本文は 今回の入力 > 元依頼 > 会話履歴 の順で解決
  const { instr, body: reqBody, explicit } = splitRequest(req);
  const body = reqBody || splitRequest(source).body || bodyFromConversation(conv);

  const draftReply = (content: string, kind: string) =>
    `ご依頼の${kind}を作成しました。\n\n────────\n${content}\n────────\n\n[ ]の箇所をご確認ください。成果物エリアにも保存済みです(送信はしていません)。「もっと丁寧に」「短くして」「別案を3つ」など、続けてご指示いただけます。`;

  // 立場の指定(了承する/断る)。「行けると返信して」「断る文面に」などを検知
  const wantsAccept = /行ける|行けます|参加でき|対応でき|出席する|受けられ|OKと|大丈夫と|了承|承諾|引き受け|お受けす/.test(instr);
  const wantsDecline = /行けない|行けません|参加できない|対応できない|都合がつかない|難しいと|断る|断り|お断り|辞退|見送り|見送る|不参加|欠席/.test(instr);
  const replyIntent = /返信して|返事して|(返信|返事|メール|文面|文章)(の文|文)?(の案|案)?を?(考|作|書)|返信文|下書き|ドラフト/.test(instr);

  // ---- 相手メッセージの内容を理解して返信文を組み立てる(テンプレ差し込みではない) ----
  // assumed=true は「指示なしでメッセージだけ貼られた」場合(前向きに了解する前提の提案)
  const composeReply = (b: string, stance: 'accept' | 'decline' | 'none', assumed = false): TaskWorkPayload => {
    // 文脈判定: ビジネスメールか、LINE・チャットのような軽い文面か
    const isBiz = !b || /お世話にな|株式会社|御社|貴社|いたします|申し上げ|ございます|拝/.test(b) || b.length > 140;
    const norm = (t: string) => t.replace(/時半/g, '時30分');
    // 相手メッセージから日時・話題・質問・場所/準備の言及を読み取る
    const range = b.match(/\d{1,2}時(?:半|\d{1,2}分)?\s*(?:[〜~\-−ー]|から)\s*\d{1,2}時(?:半|\d{1,2}分)?/)?.[0];
    const dateStr = b.match(/\d{1,2}月\d{1,2}日(?:\s*[((][月火水木金土日][))])?|\d{1,2}\/\d{1,2}(?:[((][月火水木金土日][))])?/)?.[0];
    const topic =
      b.match(/「([^「」]{2,20})」/)?.[1] ??
      b.match(/([^\s、。]{2,14}?)(?:のお願い|の件で|の件に|のご依頼|の依頼で|のご相談|の募集)/)?.[1] ??
      (taskTitle || null);
    const asks = sentences(b).filter((x) => /でしょうか|ですか|ますか|いただけ|お願いでき/.test(x));
    const hasVenue = /会場|現地|会議室|店舗|お店/.test(b);
    const hasPrep = /準備|設営|接続|セッティング|機材/.test(b);
    const single = b.match(/\d{1,2}時(?:半|\d{1,2}分)?(?:から|開始)/)?.[0];
    const when = range ? `${dateStr ? `${dateStr}の` : ''}${norm(range)}` : single ? norm(single) : dateStr ?? '';

    if (!b) {
      // 相手メッセージが無い場合: 汎用ドラフト+本文の貼り付けを案内
      const content = `[宛名をご記入ください] 様\n\nお世話になっております。[会社名/氏名をご記入ください]です。\n\nこの度はご連絡いただきありがとうございます。「${subject}」の件、承知いたしました。\n\n内容を確認のうえ、${deadline && deadline !== '未設定' ? deadline : '[回答期日をご記入ください]'}までに改めてご連絡いたします。ご不明な点がございましたら、お気軽にお知らせください。\n\n今後ともよろしくお願いいたします。\n\n[署名をご記入ください]`;
      return {
        reply: `ご依頼の返信文を作成しました。\n\n────────\n${content}\n────────\n\n相手からのメッセージ本文をこのチャットに貼り付けて「行けると返信して」のようにご指示いただければ、内容に沿った具体的な返信文に作り直します。`,
        suggestions: null,
        artifact: { title: `${subject} への返信文案`, kind: '返信文案', content },
      };
    }

    const head = topic ? `「${topic}」` : 'ご連絡いただいた';
    let lines: (string | null)[];
    if (stance === 'accept') {
      lines = isBiz
        ? [
            'お世話になっております。',
            'ご連絡ありがとうございます。',
            '',
            `${head}の件、承知いたしました。`,
            when ? `${/^\d/.test(when) ? `当日は${when}` : when}で対応させていただきます。` : asks[0] ? `お尋ねの「${norm(asks[0]).replace(/[。??]+$/, '').slice(0, 30)}」につきましては、問題なく対応できます。` : '内容につきまして、問題ございません。',
            hasVenue || hasPrep ? `開始前に${hasVenue ? '会場' : '現地'}へ伺い、${hasPrep ? '準備や接続確認も含めて' : '準備も含めて'}対応いたします。` : null,
            '',
            ...(when || hasVenue || hasPrep
              ? ['微力ではございますが、お力になれれば幸いです。', '当日はどうぞよろしくお願いいたします。']
              : ['ご不明な点やご要望がございましたら、お気軽にお知らせください。', '今後ともどうぞよろしくお願いいたします。']),
          ]
        : [
            'ご連絡ありがとうございます!',
            `${head}の件、大丈夫です。${when ? `${when.endsWith('から')||when.endsWith('開始') ? when : `${when}で`}伺います。` : ''}`,
            hasPrep ? '少し早めに着いて準備も手伝いますね。' : null,
            '当日よろしくお願いします!',
          ];
    } else if (stance === 'decline') {
      lines = isBiz
        ? [
            'お世話になっております。',
            'ご連絡ありがとうございます。',
            '',
            `${head}の件、ぜひお力になりたかったのですが、あいにく${when ? `${when}は` : 'ご希望の日程は'}都合がつかず、今回は見送らせていただきたく存じます。`,
            'お役に立てず申し訳ございません。またの機会がございましたら、ぜひお声がけください。',
            '',
            '引き続きよろしくお願いいたします。',
          ]
        : [
            'ご連絡ありがとうございます!',
            `せっかくお声がけいただいたのですが、${when ? `${when}は` : 'その日は'}都合がつかず、今回は難しそうです。すみません…!`,
            'また次の機会にぜひお願いします!',
          ];
    } else {
      lines = [
        isBiz ? 'お世話になっております。\nご連絡ありがとうございます。' : 'ご連絡ありがとうございます!',
        '',
        `${head}の件、確認いたしました。`,
        asks[0] ? `${norm(asks[0]).replace(/[。??]+$/, '')} → [対応可否をご記入ください]` : '[回答内容をご記入ください]',
        '',
        'よろしくお願いいたします。',
      ];
    }
    const content = lines.filter((l): l is string => l !== null).join('\n');
    const note = assumed
      ? '了解・承諾する前提の返信案です。「断る文面にして」「もっと丁寧に」「短く」など、続けてご指示いただければ調整します。'
      : stance === 'none'
        ? '「行けると返信して」「断る返信にして」のように可否を教えていただければ、その前提で完成させます。'
        : '送信はしていません。「もっと丁寧に」「短く」「断る文面に変えて」など、続けてご指示いただけます。';
    return {
      reply: `${assumed ? '先方からのメッセージと受け取り、内容に対する返信文をご提案します' : '相手のメッセージ内容を踏まえて返信文を作成しました'}。\n\n────────\n${content}\n────────\n\n${note}`,
      suggestions: null,
      artifact: {
        title: `${topic ?? subject} への返信文案${stance === 'decline' ? '(お断り)' : stance === 'accept' ? '(承諾)' : ''}`,
        kind: '返信文案',
        content,
      },
    };
  };

  // ---- 追加指示(トーン調整): 直前の成果物を前提に調整する ----
  if (latestContent && !reqBody && !wantsAccept && !wantsDecline && /丁寧|フォーマル|かしこまっ/.test(instr)) {
    const politer = latestContent
      .replace(/お世話になっております/g, 'いつも大変お世話になっております')
      .replace(/ありがとうございます/g, '誠にありがとうございます')
      .replace(/よろしくお願いいたします/g, '何卒よろしくお願い申し上げます')
      .replace(/ご連絡差し上げます/g, 'ご連絡を差し上げたく存じます')
      .replace(/承知いたしました/g, '謹んで承知いたしました');
    return {
      reply: `かしこまりました。「${latestTitle}」をより丁寧な表現に調整しました。\n\n────────\n${politer}\n────────\n\nさらに格式を上げる・柔らかくするなどの調整も可能です。`,
      suggestions: null,
      artifact: { title: `${subject}(丁寧版)`, kind: latestKind, content: politer },
    };
  }
  if (latestContent && !reqBody && !wantsAccept && !wantsDecline && /短く|簡潔|コンパクト|要点だけ/.test(instr)) {
    const ss = sentences(latestContent).filter((x) => !/^\[/.test(x));
    const shorter = [ss[0], ss.find((x) => /件|確認|承知|対応/.test(x)) ?? ss[1], '引き続きよろしくお願いいたします。']
      .filter(Boolean)
      .filter((v, i, a) => a.indexOf(v) === i)
      .join('\n');
    return {
      reply: `承知しました。要点を残して短くしました。\n\n────────\n${shorter}\n────────\n\nさらに削ることも、丁寧さを足すこともできます。`,
      suggestions: null,
      artifact: { title: `${subject}(短縮版)`, kind: latestKind, content: shorter },
    };
  }
  if (latestContent && !reqBody && !wantsAccept && !wantsDecline && /カジュアル|砕け|フランク|やわらか|柔らか/.test(instr)) {
    const casual = latestContent
      .replace(/いつも大変お世話になっております/g, 'お世話になっています')
      .replace(/何卒よろしくお願い申し上げます/g, 'よろしくお願いします')
      .replace(/申し上げます/g, 'します')
      .replace(/でございます/g, 'です')
      .replace(/いたします/g, 'します');
    return {
      reply: `トーンをやわらかくしました。\n\n────────\n${casual}\n────────\n\n社内向け・親しい相手向けにはこのくらいが読みやすいと思います。`,
      suggestions: null,
      artifact: { title: `${subject}(カジュアル版)`, kind: latestKind, content: casual },
    };
  }

  // ---- 指示なしで相手からのメッセージだけが打ち込まれた場合: 返信文の提案を既定動作にする ----
  // (案件専用チャットは「先方のメッセージを打ち込む→返信文を提案してもらう」場所)
  if (!explicit && reqBody) {
    return composeReply(reqBody, 'accept', true);
  }

  // ---- 返信・メール作成 / 立場の指定(了承・断り)は内容理解エンジンへ ----
  if (replyIntent || ((wantsAccept || wantsDecline) && (body || latestContent))) {
    // リライト等の明示指示があればそちらを優先
    if (!/リライト|要約|議事録|別案/.test(instr)) {
      return composeReply(body, wantsDecline ? 'decline' : wantsAccept ? 'accept' : 'none');
    }
  }

  // ---- 別案・バリエーション ----
  if (/別案|他の案|パターン|バリエーション|案を(\d|[一二三四五])/.test(instr) || /(\d|[一二三四五])\s*(つ|案|パターン)/.test(instr)) {
    const nRaw = instr.match(/(\d+|[一二三四五])\s*(つ|案|パターン)/)?.[1] ?? '3';
    const n = Math.min(5, Math.max(2, ({ 一: 1, 二: 2, 三: 3, 四: 4, 五: 5 } as Record<string, number>)[nRaw] ?? (parseInt(nRaw, 10) || 3)));
    const tones = [
      ['A案(標準・丁寧)', `お世話になっております。「${subject}」の件、承知いたしました。内容を確認のうえ、[期日をご記入ください]までにご連絡いたします。よろしくお願いいたします。`],
      ['B案(簡潔)', `「${subject}」の件、承知しました。確認して[期日をご記入ください]までにご連絡します。`],
      ['C案(親しみやすい)', `ご連絡ありがとうございます!「${subject}」の件、確認しますね。[期日をご記入ください]までにはお返事しますので、少しお待ちください。`],
      ['D案(お詫び+前向き)', `ご連絡が遅くなり申し訳ありません。「${subject}」の件、優先して確認いたします。[期日をご記入ください]までに必ずご連絡いたします。`],
      ['E案(確認質問つき)', `「${subject}」の件、承知しました。1点だけ確認させてください。[確認したい点をご記入ください]。ご回答いただき次第、すぐに対応します。`],
    ].slice(0, n);
    const content = tones.map(([name, body]) => `■ ${name}\n${body}`).join('\n\n');
    return {
      reply: `${n}案ご用意しました。\n\n────────\n${content}\n────────\n\n気に入った案があれば「B案をもっと丁寧に」のように調整もできます。`,
      suggestions: null,
      artifact: { title: `${subject} 文面 ${n}案`, kind: '別案セット', content },
    };
  }

  // ---- 議事録 ----
  if (/議事録/.test(instr)) {
    const minutesBase = body || latestContent || source || req;
    const topic = minutesBase === req ? subject : firstLine(minutesBase).slice(0, 40);
    const content = `【議事録】${subject}\n\n日時: [日時をご記入ください]\n出席者: [出席者をご記入ください]\n\n■ 議題\n・${topic || '[議題をご記入ください]'}\n\n■ 議論の要点\n・${sentences(minutesBase).slice(0, 2).join('\n・') || '[要点をご記入ください]'}\n\n■ 決定事項\n・[決定事項をご記入ください]\n\n■ TODO(担当・期限)\n・${subject}の対応 — 担当: [担当者] / 期限: ${deadline && deadline !== '未設定' ? deadline : '[期限をご記入ください]'}\n\n■ 次回\n・[次回日程をご記入ください]`;
    return { reply: draftReply(content, '議事録'), suggestions: null, artifact: { title: `${subject} 議事録`, kind: '議事録', content } };
  }

  // ---- 要約 ----
  if (/要約|まとめて|サマリ/.test(instr)) {
    const target = body || latestContent || source || req.replace(/を?要約して.*$/, '');
    const ss = sentences(target);
    return {
      reply: `要約しました。\n\n【要約】\n・主旨: ${ss[0] ?? subject}\n・ポイント: ${ss.slice(1, 3).join(' / ') || '詳細は元の文面を参照'}\n・期限/条件: ${deadline && deadline !== '未設定' ? deadline : '明記なし(要確認)'}\n・次のアクション: 内容確認のうえ対応方針を決める\n\nこの要約をもとに「返信文を考えて」などの依頼もできます。`,
      suggestions: null,
      artifact: null,
    };
  }

  // ---- リライト ----
  if (/リライト|書き直|直して|推敲|改善して/.test(instr)) {
    const ss = sentences(body || latestContent || source || req);
    const content = `${subject}について\n\n■ 結論\n${ss[0] ?? '[結論をご記入ください]'}\n\n■ 詳細\n${ss.slice(1, 4).join('\n') || '[詳細をご記入ください]'}\n\n■ お願い\nご確認のうえ、ご不明点があればお知らせください。`;
    return {
      reply: `リライトしました。結論を先頭に出し、段落を整理しています。\n\n────────\n${content}\n────────\n\n「もっと短く」「箇条書きに」などの追加調整もどうぞ。`,
      suggestions: null,
      artifact: { title: `${subject}(リライト版)`, kind: 'リライト版', content },
    };
  }

  // ---- タスク整理・進め方の相談(このときだけAI提案エリアも更新) ----
  if (/整理して|進め方|どう進め|優先順位|段取り|対応方針/.test(instr)) {
    return {
      reply: `「${subject}」の進め方を整理しました。\n\n1. まず相手・目的を1行で固定する(手戻り防止)\n2. 今日できる最小の一歩: 返信の要点を3行で書き出す\n3. ${deadline && deadline !== '未設定' ? `期限(${deadline})から逆算して、` : ''}確認が必要な点を先に相手へ聞く\n\n右のAI提案エリアにも対応方針・確認事項・次のアクションを保存しました。「返信文を考えて」と言っていただければ、このままドラフトも作ります。`,
      suggestions: {
        approaches: ['相手・目的を1行で固定してから着手する', 'タスクを「今日やる最小の一歩」と「後で決めること」に分ける'],
        checkpoints: ['宛先(相手の名前・会社名)は正しいか', `期日・優先度はこのままでよいか${deadline && deadline !== '未設定' ? `(現在: ${deadline})` : ''}`],
        nextActions: ['対応方針を1つ選ぶ', '必要なら「返信文を考えて」でドラフト作成', '完了したらステータスを「完了」へ変更する'],
        missingInfo: ['相手からの元のメッセージ全文', '希望する納期・トーン(丁寧/カジュアル)'],
      },
      artifact: null,
    };
  }

  // ---- 提案・アイデア ----
  if (/提案|アイデア|どう思|意見/.test(instr)) {
    return {
      reply: `「${subject}」について、私の提案は3つです。\n\n① すぐ返す: まず受領+御礼だけ先に返信し、詳細回答は期日を切って分ける(印象と余裕の両立)\n② テンプレ化: 今回の文面を雛形として保存し、同種の連絡を数分で返せるようにする\n③ 先回り: 相手が次に聞きそうな点([よくある質問をご記入ください])を先に書き添えて往復を減らす\n\nどれか進めたいものがあれば、「①で返信文を作って」のようにご指示ください。`,
      suggestions: null,
      artifact: null,
    };
  }

  // ---- 上記以外: 会話として直接応答 ----
  return {
    reply: `「${req.slice(0, 60)}${req.length > 60 ? '…' : ''}」の件ですね。\n\n${source ? `この案件の元の依頼は「${firstLine(source).slice(0, 50)}」と把握しています。` : ''}私はこのルーム専属のアシスタントとして、その場で本文まで作成できます。たとえば:\n・「返信文を考えて」「メールを書いて」\n・「要約して」「リライトして」「議事録を作って」\n・「別案を3つ」「もっと丁寧に」「短くして」\n\n判断に迷う点があれば、状況を書いていただければ一緒に考えます。`,
    suggestions: null,
    artifact: null,
  };
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

    if (options.system.includes('[ROLE:TASK_ASSISTANT]')) {
      // 案件ルームの会話型AI: 入力を「依頼」として解釈し、チャットへ直接回答する
      // (返信文・リライト・要約・議事録・メール・別案・トーン調整・タスク整理・雑談に対応)
      payload = taskAssistantPayload(request);
    } else if (options.system.includes('[ROLE:CEO_ADVISOR]')) {
      // 経営相談モード: ①需要②勝てる理由③最悪のケース④最初の一歩 + レビュー会議 + ユーザー分析
      const req = request.match(/【社長の依頼】\n([\s\S]+?)(\n\n|$)/)?.[1] ?? request;
      const topic = req.replace(/について.*|を?相談.*|どう思う.*|すべきか.*/g, '').slice(0, 30) || '今回のテーマ';
      payload = {
        demand: [
          `困っているのは「${audience}」— 時間も専門知識も足りず、後回しにしている層です`,
          '必要になる場面は、売上や採用など「痛みが数字で見え始めた」とき',
          'お金を払うのは現場担当ではなく、成果に責任を持つ経営者・決裁者です',
        ],
        winningReason: [
          '社長自身が顧客と同じ立場を経験しており、課題の解像度が高いこと',
          '小回りが利く体制のため、大手が拾えない個別事情に対応できること',
          '実績が積み上がる前でも「過程の発信」自体が参入障壁になります',
        ],
        worstCase: [
          '外した場合に失うのは主に時間(3〜6ヶ月)と機会費用。金銭的損失は小さく設計可能',
          '最大のリスクは「反応がないまま続けて疲弊する」こと',
          '撤退ライン例: 3ヶ月で問い合わせ・反応ゼロなら内容を根本から見直す',
        ],
        firstStep: {
          action: `今日30分: 「${topic}」の想定顧客を1人だけ具体的に書き出す(名前・年齢・悩み・昨日困った場面)`,
          breakdown: ['10分: 顧客像を1人分だけ書く', '10分: その人が昨日検索したであろう言葉を5個書く', '10分: その言葉に対して自分が言えることを1行ずつ書く'],
        },
        reviewPanel: {
          investor: { good: '小さく検証して撤退ラインを決める姿勢は投資判断として健全です', harsh: '「誰が払うのか」の検証がまだ仮説です。実際に1人に聞くまで数字は信用しません' },
          lazyReader: { good: '30分の最初の一歩まで分解されているので、今日動けます', harsh: '正直、説明が1行でも長いと読み飛ばします。顧客に見せる文章はもっと短く' },
          futureSelf: { good: '記録を残しながら進めれば、1年後に「やってよかった」と言える積み上げになります', harsh: '1年後の自分より: 完璧を待って始めなかった月のことを一番後悔しています' },
        },
        userInsights: {
          criteria: ['始める前にリスクと撤退ラインを確認したい'],
          values: ['時間を無駄にしないこと'],
          phrases: [],
          patterns: ['大きな決断の前に相談して整理するタイプ'],
          strengths: ['行動前に構造化して考えられる'],
          weaknesses: [],
        },
      };
    } else if (options.system.includes('[ROLE:CEO_RESEARCH]')) {
      // ディープリサーチモード: 判断材料の整理(結論は出さない)
      const theme = request.match(/テーマ[::]\s*(.+)/)?.[1]?.split('\n')[0]?.slice(0, 40) ?? 'ご指定のテーマ';
      payload = {
        facts: [
          `「${theme}」の市場は中小企業のデジタル化需要と連動して拡大傾向(具体的な市場規模は一次資料での確認が必要です)`,
          '中小企業の約7割がデジタル活用に課題を感じているとする調査が複数存在します(出典要確認)',
          '競合は大手コンサル系・ツールベンダー系・個人支援系の3層に分かれ、価格帯が大きく異なります',
          'デモ環境のため、以下は「調べるべき観点と情報源」の整理です。数値は必ず一次資料でご確認ください',
        ],
        pros: [
          { point: '需要の裾野が広く、小さく始めても顧客が見つかりやすい', basis: '中小企業数は日本の企業の99%超(中小企業庁の基本データ)' },
          { point: '専門家不足により、伴走型支援への支払い意欲が高い', basis: '各種のDX実態調査で「人材不足」が最上位課題に挙がる傾向' },
        ],
        cons: [
          { point: '価格競争が激しく、単発案件では利益が薄い', basis: '低価格ツールや無料相談窓口(公的支援)と比較されやすい' },
          { point: '成果が出るまでの期間が長く、解約リスクがある', basis: '支援系サービスの一般的な継続率の課題(業界レポートで要確認)' },
        ],
        sources: [
          { title: '中小企業庁「中小企業白書」', type: '政府資料', url: 'https://www.chusho.meti.go.jp/' },
          { title: '総務省「情報通信白書」', type: '政府資料', url: 'https://www.soumu.go.jp/' },
          { title: 'IPA「DX動向調査」', type: '公的機関資料', url: 'https://www.ipa.go.jp/' },
          { title: '上場している同業企業のIR資料(決算説明資料)', type: '企業IR', url: 'https://www.jpx.co.jp/' },
        ],
        cautions: [
          'デモ生成のため、具体的な数値・統計は記載していません。上記の公式サイト内で最新の資料を検索してご確認ください',
          '賛成・反対の根拠は一般的な傾向です。ご自身の商圏・顧客層での一次確認(5社ヒアリング等)を推奨します',
        ],
        reviewPanel: {
          investor: { good: '一次情報の出典を確認しにいく設計は良い', harsh: '市場が大きい=あなたが勝てる、ではありません。獲得コストの試算がまだです' },
          lazyReader: { good: '賛成・反対が分かれていて判断しやすい', harsh: '資料を全部読む気はないので、次は「結局どの数字を見ればいいか」を1つに絞ってほしい' },
          futureSelf: { good: '始める前に反対意見を見ておいたのは正解でした', harsh: '調査だけで2週間使ったことは後悔しています。調べながら動けばよかった' },
        },
      };
    } else if (options.system.includes('[ROLE:CEO_CONSULT]')) {
      // CEOの相談(経営者・クリエイティブディレクターとしての一次回答)
      const def = caseOf(request);
      const req = request.match(/【社長の依頼】\n([\s\S]+?)(\n\n|$)/)?.[1] ?? request;
      // 曖昧さの判定: ターゲットと目的が読み取れない短い依頼は確認質問をする
      const hasTarget = /向け|ターゲット|経営者|求職者|顧客|(\d0代)|既存客|新規/.test(req);
      const hasPurpose = /目的|ため|増や|獲得|認知|集客|採用|問い合わせ|売上|紹介|告知|豆知識|改善|リニューアル/.test(req);
      const questions: { question: string; why: string; options: string[] }[] = [];
      if (!hasTarget) {
        questions.push({
          question: `この${def.label}は、どなたに届けたいですか?`,
          why: 'ターゲットが変わると、言葉選び・デザイン・構成のすべてが変わります。ここが成果物の質を最も左右します',
          options: ['中小企業の経営者', '一般消費者', '求職者(採用目的)', '既存のお客様'],
        });
      }
      if (!hasPurpose) {
        questions.push({
          question: 'いちばん優先したい成果はどれですか?',
          why: 'ゴールによって「何を強調し、何を削るか」の判断基準が変わるためです',
          options: ['問い合わせ・相談を増やす', '認知を広げる(まず知ってもらう)', '信頼感を高める(ブランディング)', '採用応募を増やす'],
        });
      }
      const directorName = def.directorLabel.replace(/^[^ ]+ /, '');
      const focusPoint =
        def.pipeline === 'sns'
          ? '伸びるかどうかは最初の1秒のフックで決まるので、そこから逆算して設計します'
          : def.pipeline === 'design'
            ? '一目で伝わるかどうかは情報の優先順位で決まるので、要素の絞り込みから始めます'
            : def.pipeline === 'docs'
              ? '読み手が迷わない論理の流れが命なので、章立ての設計から丁寧に作ります'
              : '成果はデザインより情報設計で決まるので、ターゲットの動線から組み立てます';
      payload = {
        shortReply: `${def.label}のご依頼ですね、承知しました。経営視点では、単発で終わらせず「反応を測って次につなげる」形にすることが投資効果を高めます。制作判断は専門の${directorName}へ引き継ぎます。`,
        directorComment: `${directorName}です、引き継ぎました。${def.label}はお任せください。${focusPoint}。${
          questions.length > 0 ? `制作に入る前に、${questions.length}点だけ確認させてください。` : 'この内容ならすぐ企画に入れます。実行計画をお出ししますね。'
        }`,
        understanding: `ご依頼は「${req.slice(0, 60)}」、種別としては${def.label}案件と受け取りました。単発の制作物ではなく、会社の${def.pipeline === 'sns' ? '認知獲得と見込み顧客との接点づくり' : def.pipeline === 'docs' ? '意思決定を前に進めるコミュニケーション' : '信頼獲得と問い合わせ導線'}の一手として捉えています。`,
        objective: `本当のゴールは「${def.label}を作ること」ではなく、それを通じて${def.pipeline === 'sns' ? 'ターゲットの手を止め、保存・プロフィール訪問という次の行動につなげること' : def.pipeline === 'docs' ? '読み手が迷わず「次に進む」と判断できる材料を渡すこと' : 'ターゲットに「ここなら任せられる」と感じてもらい、行動につなげること'}だと整理しました。制作前にこのゴールを固定することで、途中の判断がぶれなくなります。`,
        proposal: `成果を出すために、(1)ターゲットを1人まで絞り込み、その人の悩みから逆算して構成する、(2)伝えたいことを詰め込まず「1${def.pipeline === 'sns' ? '投稿' : '成果物'}=1メッセージ」に絞る、(3)完成後に反応を測る指標(${def.pipeline === 'sns' ? '保存率・プロフィール遷移' : '問い合わせ数・読了率'})を先に決めておく、の3点を提案します。特に(1)が品質の8割を決めます。`,
        reasoning: `${def.label}で成果が出ないケースの多くは、内容の質ではなく「誰に何を伝えるか」の設計不足が原因です。逆にここが固まっていれば、後工程のライティングもデザインも判断が速く、修正も減ります。費用対効果の面でも、上流の整理に時間を使うのが最も効率的です。`,
        productionApproach: `${def.departmentLabel}の${def.pipeline === 'sns' ? 'SNSディレクター→ライター→デザイナー→マーケティング→レビュアーの5工程' : def.pipeline === 'web' ? 'ディレクター→ライター→レビュアーの3工程' : def.pipeline === 'design' ? 'ディレクター→(ライター)→デザイナー→レビュアーの工程' : '構成→本文→レビューの3工程'}で制作します。各工程の成果物はすべて確認可能で、レビューで品質を担保してからお届けします。`,
        questions,
        readyToProceed: questions.length === 0,
      };
    } else if (options.system.includes('[ROLE:CEO]')) {
      // 案件種別に応じた実行計画(担当部署への振り分けを反映)
      const def = caseOf(request);
      const roleOf: Record<string, string> = { sns: 'sns', writer: 'writer', designer: 'designer', seo: 'seo', director: 'director' };
      const stepTasks = def.steps.map((st, i) => ({
        title: st.title,
        description: st.description,
        assignedAgentRole: roleOf[st.agentId] ?? 'director',
        dependsOn: i === 0 ? [] : [i - 1],
        canRunInParallel: false,
        requiresApproval: false,
        estimatedTokens: 2400 + i * 400,
        estimatedCostJPY: 0,
      }));
      payload = {
        summary: `${def.label}の制作(${audience}向け)— 担当: ${def.departmentLabel}`,
        goal: `${audience}に届く${def.label}の成果物一式を作成し、社長が確認できる状態にする`,
        assumptions: ['ブランドトーンは既存の会社設定(誠実・提案型)を踏襲します', '公開・投稿・共有は行わず、社内確認用の成果物とします'],
        missingInformation: ['具体的な顧客社名・実績数値(あれば品質が向上します)'],
        deliverables: [...def.steps.map((st) => `${st.deliverableTitle}(担当: ${st.agentId})`), 'レビュー報告書(レビュアーAI)'],
        tasks: [
          ...stepTasks,
          { title: '品質レビュー', description: '整合性・誇大表現・誤字・要確認事項をチェック', assignedAgentRole: 'reviewer', dependsOn: [stepTasks.length - 1], canRunInParallel: false, requiresApproval: false, estimatedTokens: 1800, estimatedCostJPY: 0 },
        ],
        risks: ['実績・数値は仮置きのため、公開前に実データへの差し替えが必要です'],
        completionCriteria: ['レビュー承認済みの成果物一式が保存されている'],
      };
    } else if (options.system.includes('[ROLE:PLANNER]')) {
      // 企画・構成案(SNSディレクター/ディレクター/SEOディレクター)
      const def = caseOf(request);
      const isCarousel = def.type === 'instagram_carousel';
      const isReel = def.type === 'instagram_reel';
      const structure = isCarousel
        ? [
            { name: '1枚目: 表紙', purpose: `「${theme}」の悩みに刺さるフックで手を止めさせる` },
            { name: '2枚目: 共感', purpose: 'ターゲットの悩みを言語化して自分ごと化する' },
            { name: '3〜5枚目: 本編', purpose: '解決策を1枚1メッセージで解説する' },
            { name: '6枚目: まとめ', purpose: '要点を1枚に整理し保存を促す' },
            { name: '7枚目: CTA', purpose: 'プロフィール遷移・保存・フォローを促す' },
          ]
        : isReel
          ? [
              { name: '0-2秒: フック', purpose: '最初の2秒で離脱を防ぐ(テキストオーバーレイ必須)' },
              { name: '2-15秒: 本編', purpose: 'テンポよく3つのポイントを見せる' },
              { name: '15-25秒: 実例', purpose: 'ビフォーアフターで納得感を作る' },
              { name: 'ラスト: CTA', purpose: 'フォローと保存を促す' },
            ]
          : def.pipeline === 'docs'
            ? [
                { name: '導入', purpose: '読み手の課題を提示し、読む理由を作る' },
                { name: '現状分析', purpose: '課題の構造を整理する' },
                { name: '提案内容', purpose: '解決策と実行プランを示す' },
                { name: '期待効果', purpose: '成果イメージと根拠を示す' },
                { name: '次のステップ', purpose: '意思決定に必要な行動を明確にする' },
              ]
            : [
                { name: 'メインビジュアル', purpose: `${def.label}の第一印象で目を引く` },
                { name: 'キーメッセージ', purpose: '伝えたい価値を一言で伝える' },
                { name: 'CTA', purpose: '次の行動へ迷いなく誘導する' },
              ];
      payload = {
        overview: `${def.label}の企画・構成案。依頼内容:「${request.match(/【社長の依頼】\n(.+)/)?.[1]?.slice(0, 60) ?? request.slice(0, 60)}」`,
        objective: `${audience}との接点を増やし、保存・問い合わせなどの反応につなげる`,
        target: `${audience}(スマホ閲覧が中心)`,
        keyMessage: `${theme}の悩みは、正しい手順で解決できる`,
        toneOfVoice: '誠実で親しみやすく、専門用語を避けたやさしい言葉',
        structure,
        constraints: def.pipeline === 'design' ? ['媒体・サイズは要確認(constraints)', 'ブランドカラーを踏襲する'] : ['プラットフォームの推奨仕様に準拠する', '誇大表現・断定表現を使わない'],
        referenceIdeas: ['同業他社の高保存率投稿の構成', '自社の過去反応が良かったトーン'],
        openQuestions: ['実績数値・事例の使用可否', 'ブランドカラー・ロゴデータの有無'],
      };
    } else if (options.system.includes('[ROLE:CONTENT]')) {
      // 本文・キャプション(ライター)
      const def = caseOf(request);
      const revised = request.includes('[修正指示]') || request.includes('【修正指示】');
      const isX = def.type === 'x_post';
      payload = {
        title: revised ? `【保存版】${theme}で失敗しないための3つのポイント` : `${theme}、なんとなくで進めていませんか?`,
        mainText: isX
          ? `${theme}で成果が出ない会社の共通点は「順番」でした。\n\n1. 目的を決める\n2. 相手を決める\n3. 伝え方を決める\n\nこの順番を守るだけで反応は変わります。詳しくはプロフィールへ。`
          : `「${theme}、やったほうがいいのは分かってるけど、何から始めれば…」\n\nそんな声をよくいただきます。実は、成果が出ない一番の原因はセンスではなく「順番」です。\n\n✅ ポイント1: 目的をひとつに絞る\n✅ ポイント2: 相手の悩みから逆算する\n✅ ポイント3: 次の行動を明確にする\n\nこの3つを押さえるだけで、反応は大きく変わります。\n\n詳しい手順は保存して見返してください👇`,
        variations: [revised ? `${theme}の正解、実は3つだけ` : `もう迷わない、${theme}の始め方`, `${audience}のための${theme}入門`],
        hashtags: def.pipeline === 'sns' ? [`#${theme}`, '#中小企業', '#経営者', '#マーケティング', '#仕事術', '#ビジネスハック', '#起業家', '#個人事業主', '#集客', '#社長'] : [],
        cta: def.pipeline === 'sns' ? '役に立ったら保存🔖 プロフィールから無料相談も受付中' : '無料相談で課題を整理する',
        notes: ['実績・数値は仮置きです([実績情報をご提供ください])', isX ? '本文は140字以内に収めています' : 'キャプションは冒頭2行で興味を引く構成です'],
      };
    } else if (options.system.includes('[ROLE:VISUAL]')) {
      // ビジュアル・デザイン案(デザイナー)
      const def = caseOf(request);
      const revised = request.includes('[修正指示]') || request.includes('【修正指示】');
      payload = {
        concept: revised
          ? `${def.label}の修正版: 視認性を最優先に、余白を広げて1メッセージ1画面へ整理`
          : `「やさしく、信頼できる」を軸に、${audience}が3秒で内容を理解できるデザイン`,
        layoutIdeas: [
          { name: 'A案: 大胆タイポ', description: 'キーメッセージを画面の60%で見せる。情報量を絞り、瞬間的な理解を狙う' },
          { name: 'B案: 図解型', description: '3ステップを図解で見せる。保存されやすく、じっくり読まれる投稿向き' },
          def.pipeline === 'design'
            ? { name: 'C案: 写真主体', description: '人物写真で信頼感を演出し、コピーを添える構成' }
            : { name: 'C案: ビフォーアフター', description: '左右比較で変化を直感的に伝える' },
        ],
        colorPalette: ['#4F46E5(メイン: 信頼のブルー系)', '#F5D76E(アクセント: 注目の黄色)', '#FDFAF3(背景: やわらかい生成り)', '#1F2937(テキスト: 読みやすい濃灰)'],
        typography: '見出し: 太めのゴシック(Noto Sans JP Bold)/ 本文: Noto Sans JP Regular。スマホの小画面でも読める級数を確保',
        imageDirections: def.type === 'instagram_carousel'
          ? ['1枚目: キーメッセージ+人物または象徴的なアイコン', '2枚目以降: 1枚1メッセージの図解', '最終枚: CTAボタン風の要素で行動を明示']
          : ['メインビジュアルはターゲットが「自分ごと」と感じる場面写真またはイラスト', 'テキストオーバーレイはコントラスト比4.5:1以上を確保'],
        sizeVariations: def.type === 'banner' ? ['300×250(レクタングル)', '728×90(リーダーボード)', '1080×1080(SNS用)'] : def.pipeline === 'sns' ? ['1080×1350(フィード推奨)', '1080×1920(ストーリーズ転用)'] : ['A4(チラシ標準)'],
        notes: ['ロゴデータ・ブランドガイドラインの提供をお願いします', '写真素材は権利クリアなものを使用します'],
      };
    } else if (options.system.includes('[ROLE:MARKETER]')) {
      // 配信戦略・KPI(マーケティングAI)
      const def = caseOf(request);
      payload = {
        bestTiming: `${audience}の閲覧が多い平日7:30前後(通勤時間)と21:00前後(就寝前)。まずは火・木の21:00投稿を推奨`,
        frequency: def.type === 'instagram_reel' ? '週2本(品質優先)。フィード投稿と交互に運用' : '週3回(月・水・金)を基本に、反応を見て調整',
        kpis: ['保存率 3%以上(目安)', 'プロフィール遷移率 1.5%以上(目安)', 'フォロワー純増 週+50(目安)', 'リーチに対するエンゲージメント率 5%(目安)'],
        hashtagStrategy: '大(10万件超)3個・中(1〜10万件)5個・小(1万件未満)5個の構成で、検索流入と関連表示の両方を狙う',
        abTestIdeas: ['1枚目のフック文言を2案でテスト', '投稿時間 7:30 vs 21:00 の反応比較', 'CTA「保存」vs「プロフィールへ」の遷移率比較'],
        crossChannelIdeas: ['反応の良い投稿をThreadsへ転用', 'カルーセルをブログ記事化してSEO流入も獲得'],
        expectedEffect: '4週間の継続運用で、保存数とプロフィール遷移の増加を想定(数値はデモの目安であり、成果を保証するものではありません)',
        notes: ['投稿の実行(外部送信)は行いません。社長の承認後、手動での投稿をお願いします'],
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
