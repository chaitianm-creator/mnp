import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:design_kingdom/features/onboarding/presentation/ac_avatar.dart';

void main() {
  testWidgets('render ac avatar png', (tester) async {
    await tester.runAsync(() async {
      const size = Size(360, 480);
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF7F5EF));
      const AcAvatarPainter().paint(canvas, size);
      final img = await rec.endRecording().toImage(360, 480);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('/tmp/claude-0/-home-user-mnp/eecf3780-dee3-538d-9368-d2f5a1e855cf/scratchpad/ac_avatar_preview.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
      // きせかえ色違い(さくら)
      final rec2 = ui.PictureRecorder();
      final canvas2 = Canvas(rec2);
      canvas2.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF7F5EF));
      const AcAvatarPainter(outfitTop: Color(0xFFF5A097)).paint(canvas2, size);
      final img2 = await rec2.endRecording().toImage(360, 480);
      final bytes2 = await img2.toByteData(format: ui.ImageByteFormat.png);
      File('/tmp/claude-0/-home-user-mnp/eecf3780-dee3-538d-9368-d2f5a1e855cf/scratchpad/ac_avatar_preview2.png')
          .writeAsBytesSync(bytes2!.buffer.asUint8List());
    });
  });
}
