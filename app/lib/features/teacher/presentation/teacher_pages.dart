import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:design_kingdom/core/state/account.dart';
import 'package:design_kingdom/core/theme/kd_colors.dart';
import 'package:design_kingdom/core/theme/kd_theme.dart';
import 'package:design_kingdom/core/widgets/kd_widgets.dart';
import 'package:design_kingdom/features/teacher/data/teacher_demo_students.dart';

/// 先生用管理画面(/teacher, /teacher/students, /teacher/students/:id)。
/// 表示分岐はクライアントの role を使うが、本番のアクセス制御は
/// Firebase custom claims + Firestore Security Rules 側で強制する
/// (role をクライアント側だけで判定しない)。

/// roleガード: 先生以外にはダッシュボードを見せない。
class _TeacherGuard extends ConsumerWidget {
  const _TeacherGuard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider);
    if (account == null || !account.isTeacher) {
      return Scaffold(
        appBar: AppBar(title: const Text('先生用ページ')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: KdParchmentCard(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.lock, size: 40, color: KdColors.wood700),
                const SizedBox(height: 10),
                Text('このページは先生専用だよ',
                    style: KdTheme.dot(size: 14, color: KdColors.ink900)
                        .copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('先生アカウントでログインすると見られます。',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 14),
                KdPrimaryButton(
                  label: 'ホームへもどる',
                  onPressed: () => context.go('/home'),
                ),
              ]),
            ),
          ),
        ),
      );
    }
    return child;
  }
}

/// ── ダッシュボード ────────────────────────────────────
class TeacherDashboardPage extends ConsumerWidget {
  const TeacherDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(teacherStudentsProvider);
    final account = ref.watch(accountProvider);
    final waiting = [
      for (final s in students)
        for (final sub in s.submissions)
          if (sub.status == 'waiting') (s, sub),
    ];
    final activeToday =
        students.where((s) => s.lastLogin.startsWith('きょう')).length;
    final avgLevel = students.isEmpty
        ? 0.0
        : students.map((s) => s.level).reduce((a, b) => a + b) /
            students.length;

    return _TeacherGuard(
      child: Scaffold(
        backgroundColor: KdColors.parchmentLight,
        appBar: AppBar(
          title: const Text('先生ダッシュボード'),
          actions: [
            IconButton(
              tooltip: '設定',
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.settings),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            KdParchmentCard(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: KdColors.pink100,
                    shape: BoxShape.circle,
                    border: Border.all(color: KdColors.pink500, width: 2),
                  ),
                  child: const Icon(Icons.favorite,
                      size: 22, color: KdColors.pink500),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('おつかれさまです、${account?.nickname ?? '先生'}！',
                            style:
                                KdTheme.dot(size: 14, color: KdColors.heading)
                                    .copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text('生徒たちの今日のようすです。',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ]),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            const KdSectionHeader('きょうのサマリー'),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.1,
              children: [
                _StatTile(
                    icon: Icons.groups,
                    label: '生徒数',
                    value: '${students.length}',
                    unit: '人',
                    color: KdColors.pink100),
                _StatTile(
                    icon: Icons.rate_review,
                    label: '添削待ち',
                    value: '${waiting.length}',
                    unit: '件',
                    color: const Color(0xFFF7E3A8)),
                _StatTile(
                    icon: Icons.login,
                    label: '今日のログイン',
                    value: '$activeToday',
                    unit: '人',
                    color: const Color(0xFFD9EDC9)),
                _StatTile(
                    icon: Icons.trending_up,
                    label: '平均レベル',
                    value: avgLevel.toStringAsFixed(1),
                    unit: '',
                    color: const Color(0xFFD6E9F8)),
              ],
            ),
            const SizedBox(height: 16),
            const KdSectionHeader('添削待ちの提出'),
            const SizedBox(height: 8),
            if (waiting.isEmpty)
              KdParchmentCard(
                child: Text('添削待ちはありません。すばらしい！',
                    style: Theme.of(context).textTheme.bodyMedium),
              )
            else
              for (final (s, sub) in waiting) ...[
                InkWell(
                  onTap: () => context.push('/teacher/students/${s.id}'),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: KdColors.gold500, width: 2),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0xFFB88A18), offset: Offset(0, 2)),
                      ],
                    ),
                    child: Row(children: [
                      const Icon(Icons.hourglass_top,
                          size: 20, color: KdColors.gold500),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(sub.questTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                          fontWeight: FontWeight.w700)),
                              Text('${s.nickname}・${sub.submittedAt}',
                                  style: KdTheme.dot(
                                      size: 10, color: KdColors.wood700)),
                            ]),
                      ),
                      const Icon(Icons.chevron_right,
                          size: 20, color: KdColors.wood700),
                    ]),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            const SizedBox(height: 10),
            KdPrimaryButton(
              label: '生徒一覧を見る',
              onPressed: () => context.push('/teacher/students'),
            ),
          ]),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: KdColors.wood900, width: 2),
        boxShadow: const [
          BoxShadow(color: KdColors.wood900, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(children: [
              Icon(icon, size: 13, color: KdColors.ink900),
              const SizedBox(width: 4),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KdTheme.dot(size: 10, color: KdColors.ink900)),
              ),
            ]),
            const SizedBox(height: 4),
            Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.ideographic,
                children: [
                  Text(value,
                      style: KdTheme.dot(size: 24, color: KdColors.ink900)
                          .copyWith(
                              fontWeight: FontWeight.w700, height: 1.0)),
                  const SizedBox(width: 3),
                  Text(unit,
                      style: KdTheme.dot(size: 11, color: KdColors.ink900)),
                ]),
          ]),
    );
  }
}

/// ── 生徒一覧(検索つき) ─────────────────────────────────
class TeacherStudentsPage extends ConsumerStatefulWidget {
  const TeacherStudentsPage({super.key});

  @override
  ConsumerState<TeacherStudentsPage> createState() =>
      _TeacherStudentsPageState();
}

class _TeacherStudentsPageState extends ConsumerState<TeacherStudentsPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final students = ref.watch(teacherStudentsProvider);
    final filtered = [
      for (final s in students)
        if (_query.isEmpty || s.nickname.contains(_query)) s,
    ];

    return _TeacherGuard(
      child: Scaffold(
        backgroundColor: KdColors.parchmentLight,
        appBar: AppBar(title: const Text('生徒一覧')),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            TextField(
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: InputDecoration(
                hintText: 'ニックネームで検索',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide:
                      const BorderSide(color: KdColors.border, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('${filtered.length}人',
                style: KdTheme.dot(size: 11, color: KdColors.wood700)),
            const SizedBox(height: 6),
            for (final s in filtered) ...[
              InkWell(
                onTap: () => context.push('/teacher/students/${s.id}'),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: s.isActive ? Colors.white : const Color(0xFFEFE7D5),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: KdColors.border, width: 2),
                    boxShadow: const [
                      BoxShadow(color: KdColors.wood900, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: KdColors.pink100,
                        shape: BoxShape.circle,
                        border: Border.all(color: KdColors.wood900, width: 2),
                      ),
                      child: const Icon(Icons.person,
                          size: 22, color: KdColors.pink700),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Text(s.nickname,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                          fontWeight: FontWeight.w700)),
                              const SizedBox(width: 6),
                              if (!s.isActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: KdColors.lava500,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text('一時停止中',
                                      style: KdTheme.dot(
                                          size: 9, color: Colors.white)),
                                ),
                            ]),
                            Text(
                                'Lv.${s.level}・納品${s.deliveredCount}件・最終: ${s.lastLogin}',
                                style: KdTheme.dot(
                                    size: 10, color: KdColors.wood700)),
                          ]),
                    ),
                    if (s.submissions.any((x) => x.status == 'waiting'))
                      const Icon(Icons.hourglass_top,
                          size: 18, color: KdColors.gold500),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right,
                        size: 20, color: KdColors.wood700),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ]),
        ),
      ),
    );
  }
}

/// ── 生徒詳細 ─────────────────────────────────────────
class TeacherStudentDetailPage extends ConsumerStatefulWidget {
  const TeacherStudentDetailPage({super.key, required this.studentId});
  final String studentId;

  @override
  ConsumerState<TeacherStudentDetailPage> createState() =>
      _TeacherStudentDetailPageState();
}

class _TeacherStudentDetailPageState
    extends ConsumerState<TeacherStudentDetailPage> {
  final _noteController = TextEditingController();
  bool _noteLoaded = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<String?> _textDialog(String title, String hint,
      {String confirm = '送信'}) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KdColors.surface,
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(), child: const Text('やめる')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: Text(confirm)),
        ],
      ),
    );
  }

  Future<bool> _confirm(String title, String message,
      {String confirm = '実行する', bool destructive = false}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KdColors.surface,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('やめる')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirm,
                style: TextStyle(
                    color: destructive ? KdColors.lava500 : null)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(teacherStudentsProvider.notifier);
    final student = ref
        .watch(teacherStudentsProvider)
        .where((s) => s.id == widget.studentId)
        .firstOrNull;

    if (student == null) {
      return const Scaffold(body: Center(child: Text('生徒が見つかりません')));
    }
    if (!_noteLoaded) {
      _noteController.text = student.teacherNote;
      _noteLoaded = true;
    }

    return _TeacherGuard(
      child: Scaffold(
        backgroundColor: KdColors.parchmentLight,
        appBar: AppBar(title: Text(student.nickname)),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            // ── プロフィール ──
            KdParchmentCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: KdColors.pink100,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: KdColors.wood900, width: 2.5),
                        ),
                        child: const Icon(Icons.person,
                            size: 26, color: KdColors.pink700),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(student.nickname,
                                  style: KdTheme.dot(
                                          size: 16, color: KdColors.heading)
                                      .copyWith(
                                          fontWeight: FontWeight.w700)),
                              // PII: メールはマスク表示(フル表示しない)
                              Text(maskEmail(student.email),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall),
                            ]),
                      ),
                      if (!student.isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: KdColors.lava500,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('一時停止中',
                              style:
                                  KdTheme.dot(size: 10, color: Colors.white)),
                        ),
                    ]),
                    const Divider(height: 20),
                    _kv('レベル', 'Lv.${student.level}（XP ${student.xp}）'),
                    _kv('連続日数', '${student.streak}日'),
                    _kv('練習クエスト', '${student.practiceCleared} / 3'),
                    _kv('納品数', '${student.deliveredCount}件'),
                    _kv('最終ログイン', student.lastLogin),
                    _kv('学びたい分野', student.learningInterests.join('、')),
                    if (student.assignedQuest != null)
                      _kv('個別割当', student.assignedQuest!),
                  ]),
            ),
            const SizedBox(height: 14),
            // ── 提出物と添削 ──
            const KdSectionHeader('提出物'),
            const SizedBox(height: 8),
            if (student.submissions.isEmpty)
              KdParchmentCard(
                child: Text('まだ提出はありません。',
                    style: Theme.of(context).textTheme.bodyMedium),
              )
            else
              for (final (i, sub) in student.submissions.indexed) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: KdColors.border, width: 2),
                    boxShadow: const [
                      BoxShadow(color: KdColors.wood900, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(sub.questTitle,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                          ),
                          _statusChip(sub.status),
                        ]),
                        Text(sub.submittedAt,
                            style: KdTheme.dot(
                                size: 10, color: KdColors.wood700)),
                        if (sub.comment != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: KdColors.pink50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: KdColors.pink100, width: 1.5),
                            ),
                            child: Text('コメント: ${sub.comment}',
                                style:
                                    Theme.of(context).textTheme.bodySmall),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final comment = await _textDialog(
                                    '添削コメント', '生徒に届くコメントを書いてください');
                                if (comment == null || comment.isEmpty) return;
                                notifier.addComment(student.id, i, comment);
                                _snack('添削コメントを送りました');
                              },
                              icon: const Icon(Icons.rate_review, size: 16),
                              label: const Text('添削コメント',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: sub.status == 'resubmit'
                                  ? null
                                  : () async {
                                      // 影響の大きい操作: 確認ダイアログ必須
                                      final ok = await _confirm(
                                          '再提出を依頼する？',
                                          '${student.nickname}さんに「${sub.questTitle}」の再提出を依頼します。');
                                      if (!ok) return;
                                      notifier.requestResubmission(
                                          student.id, i);
                                      _snack('再提出を依頼しました');
                                    },
                              icon: const Icon(Icons.replay, size: 16),
                              label: const Text('再提出依頼',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ]),
                      ]),
                ),
                const SizedBox(height: 8),
              ],
            const SizedBox(height: 10),
            // ── アクション ──
            const KdSectionHeader('アクション'),
            const SizedBox(height: 8),
            KdParchmentCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                ListTile(
                  leading:
                      const Icon(Icons.send, color: KdColors.ocean500),
                  title: const Text('メッセージを送る'),
                  onTap: () async {
                    final msg = await _textDialog(
                        'メッセージ', '${student.nickname}さんへのメッセージ');
                    if (msg == null || msg.isEmpty) return;
                    _snack('メッセージを送りました');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.assignment,
                      color: KdColors.grass500),
                  title: const Text('クエストを個別に割り当てる'),
                  subtitle: student.assignedQuest != null
                      ? Text('現在: ${student.assignedQuest}')
                      : null,
                  onTap: () async {
                    const options = [
                      'はじめの一歩　文字を見やすく並べてみよう',
                      'いろのちから　目立つ色をえらぼう',
                      'そろえるまほう　まっすぐ整列させよう',
                      '新商品『もちもち王国パン』のPOP',
                    ];
                    final selected = await showDialog<String>(
                      context: context,
                      builder: (ctx) => SimpleDialog(
                        backgroundColor: KdColors.surface,
                        title: const Text('割り当てるクエスト'),
                        children: [
                          for (final o in options)
                            SimpleDialogOption(
                              onPressed: () => Navigator.of(ctx).pop(o),
                              child: Text(o),
                            ),
                        ],
                      ),
                    );
                    if (selected == null) return;
                    final ok = await _confirm('クエストを割り当てる？',
                        '${student.nickname}さんに「$selected」を割り当てます。');
                    if (!ok) return;
                    notifier.assignQuest(student.id, selected);
                    _snack('クエストを割り当てました');
                  },
                ),
                ListTile(
                  leading: Icon(
                      student.isActive
                          ? Icons.pause_circle
                          : Icons.play_circle,
                      color: KdColors.lava500),
                  title: Text(
                      student.isActive ? 'アカウントを一時停止する' : '一時停止を解除する',
                      style: const TextStyle(color: KdColors.lava500)),
                  onTap: () async {
                    // 破壊的操作: 確認ダイアログ必須
                    final suspend = student.isActive;
                    final ok = await _confirm(
                      suspend ? 'ほんとうに一時停止する？' : '一時停止を解除する？',
                      suspend
                          ? '${student.nickname}さんはログインできなくなります。この操作はいつでも解除できます。'
                          : '${student.nickname}さんが再びログインできるようになります。',
                      confirm: suspend ? '一時停止する' : '解除する',
                      destructive: suspend,
                    );
                    if (!ok) return;
                    notifier.setSuspended(student.id, suspend);
                    _snack(suspend ? '一時停止しました' : '解除しました');
                  },
                ),
              ]),
            ),
            const SizedBox(height: 14),
            // ── 先生用メモ(生徒には見えない) ──
            const KdSectionHeader('先生用メモ'),
            const SizedBox(height: 8),
            KdParchmentCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('※ このメモは生徒には表示されません',
                        style: KdTheme.dot(size: 10, color: KdColors.wood700)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _noteController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: '指導のメモ、気づいたことなど',
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: KdPrimaryButton(
                        label: 'メモを保存',
                        onPressed: () {
                          notifier.saveNote(
                              student.id, _noteController.text.trim());
                          _snack('メモを保存しました');
                        },
                      ),
                    ),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 96,
          child: Text(key,
              style: KdTheme.dot(size: 11, color: KdColors.wood700)),
        ),
        Expanded(
            child: Text(value,
                style: Theme.of(context).textTheme.bodyMedium)),
      ]),
    );
  }

  Widget _statusChip(String status) {
    final (label, color) = switch (status) {
      'waiting' => ('添削待ち', KdColors.gold500),
      'resubmit' => ('再提出依頼中', KdColors.lava500),
      _ => ('添削済み', KdColors.grass500),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: KdTheme.dot(size: 9, color: Colors.white)),
    );
  }
}
