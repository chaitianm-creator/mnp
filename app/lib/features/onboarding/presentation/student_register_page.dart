import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:design_kingdom/core/config/enrollment_config.dart';
import 'package:design_kingdom/core/state/account.dart';
import 'package:design_kingdom/core/theme/kd_colors.dart';
import 'package:design_kingdom/core/theme/kd_theme.dart';
import 'package:design_kingdom/core/widgets/kd_scenery.dart';
import 'package:design_kingdom/core/widgets/kd_widgets.dart';

/// SC-04 入団手続き(生徒用アカウント新規登録)。
/// 「登録フォーム」ではなく「ギルドの入団書類」として演出する。
/// 本番は Firebase Auth(メール+配布パスワード) + users/{uid} 作成に差し替え。
class StudentRegisterPage extends ConsumerStatefulWidget {
  const StudentRegisterPage({super.key});

  @override
  ConsumerState<StudentRegisterPage> createState() =>
      _StudentRegisterPageState();
}

class _StudentRegisterPageState extends ConsumerState<StudentRegisterPage> {
  final _nickname = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  DiagnosisType? _strong;
  DiagnosisType? _weak;
  String? _experience;
  final Set<String> _interests = {};
  bool _submitting = false;

  // 配布パスワードの照合状態
  static const _passwordEmptyMessage = '配布パスワードを入力してください';
  static const _passwordWrongMessage = '配布パスワードが正しくありません';
  bool _passwordVerified = false;
  String? _passwordError = _passwordEmptyMessage;
  bool _showPassword = false;
  int _verifySeq = 0; // 連打時に古い照合結果で上書きしないための通し番号

  static const _experiences = [
    ('none', 'デザインは はじめて', Icons.spa),
    ('little', 'すこしだけ 経験がある', Icons.brush),
    ('work', '仕事で つかったことがある', Icons.work_outline),
    ('pro', '現役で デザインをしている', Icons.workspace_premium),
  ];

  static const _interestOptions = [
    ('banner', 'バナー'),
    ('sns', 'SNS画像'),
    ('flyer', 'チラシ'),
    ('pop', 'POP'),
    ('web', 'Webデザイン'),
    ('logo', 'ロゴ'),
    ('other', 'その他'),
  ];

  @override
  void dispose() {
    _nickname.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _nickname.text.trim().isNotEmpty &&
      _email.text.contains('@') &&
      _passwordVerified &&
      _strong != null &&
      _weak != null &&
      _experience != null &&
      _interests.isNotEmpty &&
      !_submitting;

  /// 入力のたびに照合(前後空白は除去・大文字小文字は区別)。
  /// 照合ロジックは enrollmentCodeVerifierProvider に分離してあり、
  /// 将来は Firebase Functions / Firestore 招待コード照合へ差し替える。
  Future<void> _onPasswordChanged(String value) async {
    final seq = ++_verifySeq;
    if (value.trim().isEmpty) {
      setState(() {
        _passwordVerified = false;
        _passwordError = _passwordEmptyMessage;
      });
      return;
    }
    final ok = await ref.read(enrollmentCodeVerifierProvider).verify(value);
    if (!mounted || seq != _verifySeq) return;
    setState(() {
      _passwordVerified = ok;
      _passwordError = ok ? null : _passwordWrongMessage;
    });
  }

  Future<void> _register() async {
    // 念のため送信時にも再照合(本番のサーバー検証と同じタイミング)
    final ok = await ref
        .read(enrollmentCodeVerifierProvider)
        .verify(_password.text);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _passwordVerified = false;
        _passwordError = _password.text.trim().isEmpty
            ? _passwordEmptyMessage
            : _passwordWrongMessage;
      });
      return;
    }
    setState(() => _submitting = true);
    await ref.read(accountProvider.notifier).registerStudent(UserAccount(
          role: UserRole.student,
          nickname: _nickname.text.trim(),
          email: _email.text.trim(),
          strongType: _strong,
          weakType: _weak,
          designExperience: _experience,
          learningInterests: _interests.toList(),
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
        ));
    if (!mounted) return;
    context.go('/enrollment-complete');
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
            Center(child: KdRibbonBanner('デザインギルド 入団手続き', fontSize: 14)),
            const SizedBox(height: 14),
            // ── 基本情報 ──
            KdParchmentCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const KdSectionHeader('あなたのなまえ'),
                    const SizedBox(height: 8),
                    _field(
                      controller: _nickname,
                      hint: 'ニックネーム（王国での呼び名）',
                      icon: Icons.person,
                    ),
                    const SizedBox(height: 14),
                    const KdSectionHeader('れんらく先'),
                    const SizedBox(height: 8),
                    _field(
                      controller: _email,
                      hint: 'メールアドレス',
                      icon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 10),
                    _field(
                      controller: _password,
                      hint: '配布パスワード（先生からもらったもの）',
                      icon: Icons.vpn_key,
                      obscure: !_showPassword,
                      errorText: _passwordError,
                      onChanged: _onPasswordChanged,
                      suffix: IconButton(
                        tooltip: _showPassword ? 'パスワードを隠す' : 'パスワードを表示',
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 20,
                          color: KdColors.wood700,
                        ),
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                      ),
                    ),
                  ]),
            ),
            const SizedBox(height: 12),
            // ── 診断(つよみ・よわみ) ──
            KdParchmentCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const KdSectionHeader('しんだんの結果を教えて'),
                    const SizedBox(height: 4),
                    Text('じぶんに近いタイプをえらんでね。どれもすてきな才能だよ♪',
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 12),
                    Text('あなたの つよみ',
                        style: KdTheme.dot(size: 12, color: KdColors.pink700)
                            .copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    _diagnosisGrid(
                      selected: _strong,
                      onSelect: (d) => setState(() => _strong = d),
                    ),
                    const SizedBox(height: 14),
                    Text('ちょっと にがてかも',
                        style: KdTheme.dot(size: 12, color: KdColors.ocean500)
                            .copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    _diagnosisGrid(
                      selected: _weak,
                      onSelect: (d) => setState(() => _weak = d),
                      accent: KdColors.ocean500,
                    ),
                  ]),
            ),
            const SizedBox(height: 12),
            // ── 経験 ──
            KdParchmentCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const KdSectionHeader('デザインの経験は？'),
                    const SizedBox(height: 10),
                    for (final (id, label, icon) in _experiences) ...[
                      _selectRow(
                        selected: _experience == id,
                        icon: icon,
                        label: label,
                        onTap: () => setState(() => _experience = id),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ]),
            ),
            const SizedBox(height: 12),
            // ── 学びたい分野(複数選択) ──
            KdParchmentCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const KdSectionHeader('学びたい分野をえらんでね'),
                    const SizedBox(height: 4),
                    Text('いくつでもOK！あとから変えられるよ。',
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final (id, label) in _interestOptions)
                        _interestChip(id, label),
                    ]),
                  ]),
            ),
            const SizedBox(height: 18),
            KdPrimaryButton(
              label: 'この内容で入団する',
              onPressed: _canSubmit ? _register : null,
            ),
            const SizedBox(height: 12),
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: KdColors.pink500, width: 1.5),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.favorite,
                      size: 14, color: KdColors.pink500),
                  const SizedBox(width: 6),
                  Text('書けたら「入団する」を押してね♪',
                      style: KdTheme.dot(size: 12, color: KdColors.pink700)),
                ]),
              ),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ]),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
    String? errorText,
    Widget? suffix,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      onChanged: (v) {
        setState(() {});
        onChanged?.call(v);
      },
      decoration: InputDecoration(
        hintText: hint,
        errorText: errorText,
        errorStyle: const TextStyle(color: KdColors.lava500, fontSize: 12),
        prefixIcon: Icon(icon, size: 20, color: KdColors.wood700),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: KdColors.border, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: KdColors.border, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: KdColors.pink500, width: 2.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: KdColors.lava500, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: KdColors.lava500, width: 2.5),
        ),
      ),
    );
  }

  Widget _diagnosisGrid({
    required DiagnosisType? selected,
    required ValueChanged<DiagnosisType> onSelect,
    Color accent = KdColors.pink500,
  }) {
    const icons = {
      DiagnosisType.warrior: Icons.sports_martial_arts,
      DiagnosisType.mage: Icons.auto_fix_high,
      DiagnosisType.priest: Icons.volunteer_activism,
      DiagnosisType.merchant: Icons.storefront,
    };
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.2,
      children: [
        for (final d in DiagnosisType.values)
          InkWell(
            onTap: () => onSelect(d),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: selected == d ? KdColors.pink100 : Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: selected == d ? accent : KdColors.border,
                  width: selected == d ? 2.5 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                      color:
                          selected == d ? accent : KdColors.wood900,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: Row(children: [
                Icon(icons[d],
                    size: 22,
                    color: selected == d ? KdColors.pink700 : KdColors.wood700),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.label,
                            style:
                                KdTheme.dot(size: 13, color: KdColors.ink900)
                                    .copyWith(fontWeight: FontWeight.w700)),
                        Text(d.trait,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontSize: 10)),
                      ]),
                ),
              ]),
            ),
          ),
      ],
    );
  }

  Widget _selectRow({
    required bool selected,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? KdColors.pink100 : Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? KdColors.pink500 : KdColors.border,
            width: selected ? 2.5 : 2,
          ),
          boxShadow: [
            BoxShadow(
                color: selected ? KdColors.pink700 : KdColors.wood900,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(children: [
          Icon(icon, color: selected ? KdColors.pink700 : KdColors.wood700),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
          if (selected)
            const Icon(Icons.check_circle,
                size: 20, color: KdColors.pink500),
        ]),
      ),
    );
  }

  Widget _interestChip(String id, String label) {
    final selected = _interests.contains(id);
    return InkWell(
      onTap: () => setState(() {
        selected ? _interests.remove(id) : _interests.add(id);
      }),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? KdColors.pink500 : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? KdColors.pink700 : KdColors.border,
            width: 2,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (selected) ...[
            const Icon(Icons.check, size: 14, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: KdTheme.dot(
                  size: 12,
                  color: selected ? Colors.white : KdColors.ink900)),
        ]),
      ),
    );
  }
}
