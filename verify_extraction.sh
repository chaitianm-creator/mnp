#!/usr/bin/env bash
# 展開物の自己診断: ビルド前に必ず実行してください。
# 旧バージョンのファイル混在・不正フォルダを検出します。
echo "== デザイン王国 展開物チェック =="
if [ ! -f VERSION.txt ]; then
  echo "❌ VERSION.txt がありません → これは旧版(rc1〜rc3)の展開物です。"
  echo "   このフォルダを削除し、rc4 の zip を新しい空フォルダに展開してください。"
  exit 1
fi
cat VERSION.txt
BRACE=$(find . -name "*{*" 2>/dev/null | wc -l | tr -d ' ')
REL=$(grep -rn "import '\.\./\|import '\./" app/lib 2>/dev/null | wc -l | tr -d ' ')
OLD=$(grep -rln "quest/quest/domain\|'\.\./quest/domain" app/lib 2>/dev/null | wc -l | tr -d ' ')
echo "ブレース名フォルダ : ${BRACE} 件 (0 が正)"
echo "相対import        : ${REL} 件 (0 が正 — rc4 は全て package: 形式)"
echo "旧import残存      : ${OLD} 件 (0 が正)"
if [ "$BRACE" = "0" ] && [ "$REL" = "0" ] && [ "$OLD" = "0" ]; then
  echo "✅ OK: rc4 のクリーンな展開物です。 cd app && flutter pub get && flutter build web"
else
  echo "❌ NG: 旧ファイルが混在しています。フォルダごと削除して再展開してください。"
  exit 1
fi
