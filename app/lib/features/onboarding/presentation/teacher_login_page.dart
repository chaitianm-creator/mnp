import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:design_kingdom/core/state/account.dart';
import 'package:design_kingdom/core/theme/kd_colors.dart';
import 'package:design_kingdom/core/theme/kd_theme.dart';
import 'package:design_kingdom/core/widgets/kd_scenery.dart';
import 'package:design_kingdom/core/widgets/kd_widgets.dart';

/// 先生・スタッフ用ログイン。
/// DEMO: 先生コード(sensei)一致でローカルに teacher アカウントを作成する。
/// 本番は Firebase Auth + custom claims(role=teacher) に差し替え —
/// role をクライアント入力だけで確定しない(firestore.rules 側で強制)。
class TeacherLoginPage extends ConsumerStatefulWidget {
  const TeacherLoginPage({super.key});

  @override
  ConsumerState<TeacherLoginPage> createState() => _TeacherLoginPageState();
}

class _TeacherLoginPageState extends ConsumerState<TeacherLoginPage> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  String? _error;

  static const _demoTeacherCode = 'sensei';

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_code.text.trim() != _demoTeacherCode) {
      setState(() => _error = '先生コードがちがうみたい。もう一度確認してね。');
      return;
    }
    await ref.read(accountProvider.notifier).loginTeacher(
        nickname: _name.text.trim().isEmpty ? '先生' : _name.text.trim());
    if (!mounted) return;
    context.go('/teacher');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        const Positioned.fill(
          child: CustomPaint(painter: KdSceneryPainter(showCastle: false)),
        ),
        SafeArea(
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => context.go('/welcome'),
                icon: const Icon(Icons.arrow_back, color: KdColors.wood900),
              ),
            ),
            Center(child: KdRibbonBanner('先生・スタッフ用', fontSize: 14)),
            const SizedBox(height: 16),
            KdParchmentCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const KdSectionHeader('先生としてログイン'),
                    const SizedBox(height: 4),
                    Text('生徒の学習状況を見られる管理画面へ入ります。',
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(
                        hintText: 'お名前（表示用）',
                        prefixIcon: Icon(Icons.person, size: 20),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _code,
                      obscureText: true,
                      onChanged: (_) => setState(() => _error = null),
                      decoration: const InputDecoration(
                        hintText: '先生コード（DEMO: sensei）',
                        prefixIcon: Icon(Icons.vpn_key, size: 20),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!,
                          style: const TextStyle(
                              color: KdColors.lava500, fontSize: 13)),
                    ],
                    const SizedBox(height: 14),
                    KdPrimaryButton(label: 'ログイン', onPressed: _login),
                  ]),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text('※ 本番では Firebase Auth と custom claims で役割を検証します',
                  style: KdTheme.dot(size: 10, color: KdColors.ink900)),
            ),
          ]),
        ),
      ]),
    );
  }
}
