import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:design_kingdom/core/state/outfit.dart';
import 'package:design_kingdom/core/state/user_progress.dart';
import 'package:design_kingdom/core/widgets/pn_shell.dart';
import 'package:design_kingdom/features/onboarding/presentation/story_scenes.dart';

/// 着せ替えクローゼット(どうぶつの森の衣装ショップ風)。
/// 中央にドットの主人公プレビュー、まわりにアイテムのグリッド。
/// トップスは既存のきせかえ(outfitProvider)に反映し、
/// ぼうし・メガネはプレビュー上の試着(DEMO)。
class ClosetPage extends ConsumerStatefulWidget {
  const ClosetPage({super.key});

  @override
  ConsumerState<ClosetPage> createState() => _ClosetPageState();
}

enum _Cat { tops, hat, glasses }

class _Item {
  const _Item(this.name, this.cat, this.idx, this.price, this.color);
  final String name;
  final _Cat cat;
  final int idx; // カテゴリ内のバリエーション番号
  final int price; // 0 = 持っている
  final Color color;
}

const _hatKinds = ['fedora', 'fedora', 'fedora', 'straw', 'knit', 'knit',
  'cap', 'beret'];

const _items = <_Item>[
  // トップス(kOutfits と同期)
  _Item('しろワンピ', _Cat.tops, 0, 0, Colors.white),
  _Item('さくらワンピ', _Cat.tops, 1, 490, Color(0xFFF5A097)),
  _Item('そらワンピ', _Cat.tops, 2, 490, Color(0xFF849BE4)),
  _Item('わかばワンピ', _Cat.tops, 3, 560, Color(0xFF5DAF8D)),
  _Item('ひまわりワンピ', _Cat.tops, 4, 560, Color(0xFFF9A31B)),
  // ぼうし
  _Item('なかおれハット', _Cat.hat, 0, 1100, Color(0xFFF2EEE4)),
  _Item('なかおれハット', _Cat.hat, 1, 1100, Color(0xFF9A948A)),
  _Item('なかおれハット', _Cat.hat, 2, 1100, Color(0xFF4A443A)),
  _Item('むぎわらハット', _Cat.hat, 3, 490, Color(0xFFE0B268)),
  _Item('ニットぼう', _Cat.hat, 4, 560, Color(0xFFD9534F)),
  _Item('ニットぼう', _Cat.hat, 5, 560, Color(0xFF5B8DBE)),
  _Item('キャップ', _Cat.hat, 6, 800, Color(0xFF4A90C4)),
  _Item('ベレーぼう', _Cat.hat, 7, 800, Color(0xFFE8A0B4)),
  // メガネ
  _Item('くろぶちメガネ', _Cat.glasses, 0, 560, Color(0xFF3A3532)),
  _Item('あかぶちメガネ', _Cat.glasses, 1, 560, Color(0xFFC0392B)),
  _Item('まるメガネ', _Cat.glasses, 2, 490, Color(0xFFB08D3E)),
  _Item('ひげメガネ', _Cat.glasses, 3, 1600, Color(0xFF6E4A22)),
];

class _ClosetPageState extends ConsumerState<ClosetPage> {
  int _hat = -1; // -1 = かぶらない
  int _glasses = -1;
  _Cat? _filter; // null = ぜんぶ

  int get _total {
    var t = 0;
    final outfit = ref.read(outfitProvider);
    for (final it in _items) {
      final selected = switch (it.cat) {
        _Cat.tops => it.idx == outfit,
        _Cat.hat => it.idx == _hat,
        _Cat.glasses => it.idx == _glasses,
      };
      if (selected) t += it.price;
    }
    return t;
  }

  void _tap(_Item it) {
    setState(() {
      switch (it.cat) {
        case _Cat.tops:
          ref.read(outfitProvider.notifier).select(it.idx);
        case _Cat.hat:
          _hat = _hat == it.idx ? -1 : it.idx;
        case _Cat.glasses:
          _glasses = _glasses == it.idx ? -1 : it.idx;
      }
    });
  }

  void _buy() {
    final t = _total;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(t == 0
          ? '今のコーデは持っているアイテムだけだよ！'
          : '合計 $t ポイントで こうにゅうしました！(DEMO)'),
      duration: const Duration(seconds: 2),
    ));
  }

  void _reset() {
    setState(() {
      _hat = -1;
      _glasses = -1;
      ref.read(outfitProvider.notifier).select(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(userProgressProvider);
    final outfit = ref.watch(outfitProvider);
    final visible = _filter == null
        ? _items
        : _items.where((e) => e.cat == _filter).toList();

    return PnShell(
      current: '着せ替えクローゼット',
      spTitle: '着せ替えクローゼット',
      showRail: false,
      mainBuilder: (context, wide) => [
        // ── 上部バー(タイトル + ポイント残高) ──
        Row(children: [
          const Text('着せ替えクローゼット',
              style: TextStyle(
                  color: pnInk, fontSize: 18, fontWeight: FontWeight.w900)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: pnYellow.withOpacity(0.7),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.stars_rounded, size: 15, color: pnInk),
              const SizedBox(width: 4),
              Text('${p.coins + 3000} ポイント',
                  style: const TextStyle(
                      color: pnInk,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        // ── カテゴリ ──
        Wrap(spacing: 6, children: [
          for (final (label, cat) in [
            ('ぜんぶ', null),
            ('トップス', _Cat.tops),
            ('ぼうし', _Cat.hat),
            ('メガネ', _Cat.glasses),
          ])
            ChoiceChip(
              label: Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _filter == cat ? pnInk : pnSub)),
              selected: _filter == cat,
              selectedColor: pnPink,
              backgroundColor: pnCard,
              side: const BorderSide(color: pnLine),
              showCheckmark: false,
              onSelected: (_) => setState(() => _filter = cat),
            ),
        ]),
        const SizedBox(height: 12),
        // ── 本体(PC: グリッド + 右に試着室 / SP: 試着室 → グリッド) ──
        if (wide)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _grid(visible, outfit, cols: 4)),
            const SizedBox(width: 14),
            SizedBox(width: 290, child: _fittingRoom(outfit)),
          ])
        else ...[
          _fittingRoom(outfit),
          const SizedBox(height: 12),
          _grid(visible, outfit, cols: 3),
        ],
      ],
    );
  }

  // ── 試着室(プレビュー + 合計 + ボタン) ──
  Widget _fittingRoom(int outfit) {
    return PnPanel(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        const Text('ためしぎちゅう',
            style: TextStyle(
                color: pnSub, fontSize: 11.5, fontWeight: FontWeight.w800)),
        const SizedBox(height: 30),
        SizedBox(
          width: 150,
          height: 214,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Center(
                child: PixelSprite(
                    rows: heroineFrontRows,
                    palette: heroinePaletteFor(outfit),
                    width: 150),
              ),
            ),
            if (_hat >= 0)
              Positioned(
                top: -26,
                left: 8,
                right: 8,
                child: CustomPaint(
                  size: const Size(134, 62),
                  painter: _HatPainter(
                      kind: _hatKinds[_hat],
                      color: _items
                          .firstWhere((e) =>
                              e.cat == _Cat.hat && e.idx == _hat)
                          .color),
                ),
              ),
            if (_glasses >= 0)
              Positioned(
                top: 66,
                left: 20,
                right: 20,
                child: CustomPaint(
                  size: const Size(110, 34),
                  painter: _GlassesPainter(
                      kind: _glasses,
                      color: _items
                          .firstWhere((e) =>
                              e.cat == _Cat.glasses && e.idx == _glasses)
                          .color),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: pnBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: pnLine),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('ごうけい',
                style: TextStyle(
                    color: pnSub, fontSize: 11, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Text('$_total ポイント',
                style: const TextStyle(
                    color: pnInk, fontSize: 15, fontWeight: FontWeight.w900)),
          ]),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          OutlinedButton(
            onPressed: _reset,
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: pnLine),
                foregroundColor: pnSub),
            child: const Text('やめる',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _buy,
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF2AFC1),
                foregroundColor: const Color(0xFF8E4A62)),
            icon: const Icon(Icons.shopping_bag_rounded, size: 16),
            label: const Text('購入する',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
          ),
        ]),
      ]),
    );
  }

  // ── アイテムグリッド ──
  Widget _grid(List<_Item> items, int outfit, {required int cols}) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.92,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final it = items[i];
        final selected = switch (it.cat) {
          _Cat.tops => it.idx == outfit,
          _Cat.hat => it.idx == _hat,
          _Cat.glasses => it.idx == _glasses,
        };
        return Material(
          color: pnCard,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _tap(it),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: selected ? const Color(0xFFE98FA9) : pnLine,
                    width: selected ? 2 : 1),
              ),
              padding: const EdgeInsets.all(8),
              child: Stack(children: [
                Column(children: [
                  Expanded(
                    child: Center(
                      child: CustomPaint(
                        size: const Size(64, 44),
                        painter: switch (it.cat) {
                          _Cat.hat => _HatPainter(
                              kind: _hatKinds[it.idx], color: it.color),
                          _Cat.glasses =>
                            _GlassesPainter(kind: it.idx, color: it.color),
                          _Cat.tops => _TopPainter(color: it.color),
                        },
                      ),
                    ),
                  ),
                  Text(it.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: pnInk,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(it.price == 0 ? 'もっている' : '⭐ ${it.price}',
                      style: TextStyle(
                          color: it.price == 0 ? pnGreenInk : pnSub,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800)),
                ]),
                if (selected)
                  const Positioned(
                    right: 0,
                    top: 0,
                    child: CircleAvatar(
                      radius: 9,
                      backgroundColor: Color(0xFF49B675),
                      child:
                          Icon(Icons.check, size: 12, color: Colors.white),
                    ),
                  ),
              ]),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// アイテムのイラスト(ぼうし/メガネ/トップス)
// ─────────────────────────────────────────────────────────────
class _HatPainter extends CustomPainter {
  const _HatPainter({required this.kind, required this.color});
  final String kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2;
    final fill = Paint()..color = color;
    final dark = Paint()
      ..color = Color.lerp(color, const Color(0xFF3A3026), 0.35)!;
    switch (kind) {
      case 'fedora':
        // つば
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(cx, h * 0.78), width: w * 0.95, height: h * 0.38),
            fill);
        // クラウン(山)
        final crown = Path()
          ..moveTo(cx - w * 0.3, h * 0.78)
          ..quadraticBezierTo(cx - w * 0.34, h * 0.16, cx - w * 0.1, h * 0.10)
          ..quadraticBezierTo(cx, h * 0.02, cx + w * 0.1, h * 0.10)
          ..quadraticBezierTo(cx + w * 0.34, h * 0.16, cx + w * 0.3, h * 0.78)
          ..close();
        canvas.drawPath(crown, fill);
        // バンド
        canvas.drawRect(
            Rect.fromLTWH(cx - w * 0.31, h * 0.56, w * 0.62, h * 0.14), dark);
      case 'straw':
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(cx, h * 0.78), width: w * 0.98, height: h * 0.4),
            fill);
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(cx, h * 0.72), width: w * 0.6, height: h * 1.2),
            3.1416, 3.1416, true, fill);
        canvas.drawRect(
            Rect.fromLTWH(cx - w * 0.31, h * 0.52, w * 0.62, h * 0.16),
            Paint()..color = const Color(0xFFD9534F));
      case 'knit':
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(cx, h * 0.86), width: w * 0.78, height: h * 1.5),
            3.1416, 3.1416, true, fill);
        // 折り返し
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(cx - w * 0.4, h * 0.7, w * 0.8, h * 0.24),
                const Radius.circular(6)),
            dark);
        // ぽんぽん
        canvas.drawCircle(Offset(cx, h * 0.12), h * 0.13,
            Paint()..color = Color.lerp(color, Colors.white, 0.5)!);
      case 'cap':
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(cx - w * 0.06, h * 0.82),
                width: w * 0.7,
                height: h * 1.4),
            3.1416, 3.1416, true, fill);
        // つば(前)
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(cx + w * 0.12, h * 0.68, w * 0.38, h * 0.16),
                const Radius.circular(8)),
            dark);
        canvas.drawCircle(Offset(cx - w * 0.06, h * 0.16), h * 0.06, dark);
      case 'beret':
        canvas.save();
        canvas.translate(cx, h * 0.55);
        canvas.rotate(-0.12);
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset.zero, width: w * 0.82, height: h * 0.62),
            fill);
        canvas.restore();
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(cx - w * 0.03, h * 0.1, w * 0.06, h * 0.16),
                const Radius.circular(3)),
            dark);
    }
  }

  @override
  bool shouldRepaint(covariant _HatPainter old) =>
      old.kind != kind || old.color != color;
}

class _GlassesPainter extends CustomPainter {
  const _GlassesPainter({required this.kind, required this.color});
  final int kind; // 0くろぶち 1あかぶち 2まる 3ひげ
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.14
      ..color = color;
    final lensRect = kind == 2
        ? null
        : RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.08, h * 0.18, w * 0.34, h * 0.56),
            Radius.circular(h * 0.2));
    if (kind == 2) {
      // まるメガネ
      canvas.drawCircle(Offset(w * 0.27, h * 0.48), h * 0.34, stroke);
      canvas.drawCircle(Offset(w * 0.73, h * 0.48), h * 0.34, stroke);
      canvas.drawLine(Offset(w * 0.38, h * 0.42), Offset(w * 0.62, h * 0.42),
          stroke);
    } else {
      canvas.drawRRect(lensRect!, stroke);
      canvas.drawRRect(lensRect.shift(Offset(w * 0.5, 0)), stroke);
      canvas.drawLine(Offset(w * 0.42, h * 0.34), Offset(w * 0.58, h * 0.34),
          stroke);
    }
    if (kind == 3) {
      // ひげメガネ: 鼻とひげ
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(w * 0.5, h * 0.66), width: w * 0.16, height: h * 0.4),
          Paint()..color = const Color(0xFFE9B5A3));
      final mus = Paint()..color = const Color(0xFF4A3527);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(w * 0.34, h * 0.88), width: w * 0.3, height: h * 0.26),
          mus);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(w * 0.66, h * 0.88), width: w * 0.3, height: h * 0.26),
          mus);
    }
  }

  @override
  bool shouldRepaint(covariant _GlassesPainter old) =>
      old.kind != kind || old.color != color;
}

class _TopPainter extends CustomPainter {
  const _TopPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final fill = Paint()..color = color;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = const Color(0x33474038);
    // そで
    final body = Path()
      ..moveTo(w * 0.32, h * 0.08)
      ..lineTo(w * 0.68, h * 0.08)
      ..lineTo(w * 0.92, h * 0.3)
      ..lineTo(w * 0.8, h * 0.5)
      ..lineTo(w * 0.7, h * 0.42)
      ..lineTo(w * 0.7, h * 0.94)
      ..lineTo(w * 0.3, h * 0.94)
      ..lineTo(w * 0.3, h * 0.42)
      ..lineTo(w * 0.2, h * 0.5)
      ..lineTo(w * 0.08, h * 0.3)
      ..close();
    canvas.drawPath(body, fill);
    canvas.drawPath(body, line);
    // えり
    canvas.drawArc(
        Rect.fromCenter(
            center: Offset(w * 0.5, h * 0.1), width: w * 0.2, height: h * 0.18),
        0, 3.1416, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0x55474038));
  }

  @override
  bool shouldRepaint(covariant _TopPainter old) => old.color != color;
}
