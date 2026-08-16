import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:design_kingdom/features/onboarding/presentation/story_scenes.dart';

/// 主人公の歩行スプライトシート(前・左・右・後ろ×3コマ)をPNGに描き出す
/// 確認用ツール。`flutter test test/tools/render_walk_sheet_test.dart`
void main() {
  testWidgets('walk sprite sheet preview', (tester) async {
    await tester.runAsync(() async {
      const cellW = 96.0;
      const cellH = 124.0;
      const pad = 12.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const width = cellW * 3 + pad * 4;
      const height = cellH * 4 + pad * 5;
      canvas.drawRect(const Rect.fromLTWH(0, 0, width, height),
          Paint()..color = const Color(0xFFF7F5EF));
      for (var dir = 0; dir < 4; dir++) {
        for (var frame = 0; frame < 3; frame++) {
          final rows = heroineWalkRows(dir, frame);
          final unit = (cellW - 16) / rows[0].length;
          drawPixelSprite(
              canvas,
              rows,
              heroinePalette,
              pad + frame * (cellW + pad) + 8,
              pad + dir * (cellH + pad) + (cellH - unit * rows.length) / 2,
              unit);
        }
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(width.toInt(), height.toInt());
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File(
          '/tmp/claude-0/-home-user-mnp/eecf3780-dee3-538d-9368-d2f5a1e855cf/scratchpad/walk_sheet_preview.png');
      out.writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
