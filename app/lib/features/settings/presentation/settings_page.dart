import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:design_kingdom/core/firebase/firebase_bootstrap.dart';
import 'package:design_kingdom/core/theme/kd_colors.dart';
import 'package:design_kingdom/core/widgets/kd_widgets.dart';

/// SC-53 設定 + SC-54 アカウント管理(退会 = ストア審査必須要件 US-E10-02)。
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _sound = true;
  bool _notification = true;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      setState(() {
        _sound = prefs.getBool('sound_enabled') ?? true;
        _notification = prefs.getBool('notification_enabled') ?? true;
      });
    });
  }

  Future<void> _save(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _confirmDelete() async {
    // 2段階確認(US-E10-02): 画像を含む全削除の明示
    final first = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KdColors.surface,
        title: const Text('王国から旅立つ？'),
        content: const Text(
            'アカウントを削除すると、レベル・実績・提出した画像を含むすべてのデータが完全に削除されます。この操作は取り消せません。'),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: const Text('やめる')),
          TextButton(
              onPressed: () => ctx.pop(true),
              child: const Text('削除にすすむ',
                  style: TextStyle(color: KdColors.lava500))),
        ],
      ),
    );
    if (first != true || !mounted) return;

    final second = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KdColors.surface,
        title: const Text('ほんとうに削除する？'),
        content: const Text('みぽりん先生も住民たちも、あなたのことを忘れません。それでも削除しますか？'),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: const Text('やめる')),
          TextButton(
              onPressed: () => ctx.pop(true),
              child: const Text('完全に削除する',
                  style: TextStyle(color: KdColors.lava500))),
        ],
      ),
    );
    if (second != true || !mounted) return;

    await _deleteAccount();
  }

  Future<void> _deleteAccount() async {
    if (useFirebase) {
      // 本番: deleteAccount(Functions) → 全サブコレクション+Storage+Authを削除
      await callDeleteAccount();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // ローカルデータも全消去 → 次回起動はオンボーディングへ
    if (!mounted) return;
    context.go('/welcome');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('せってい')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          KdParchmentCard(
            child: Column(children: [
              SwitchListTile(
                title: const Text('サウンド'),
                value: _sound,
                activeColor: KdColors.pink500,
                onChanged: (v) {
                  setState(() => _sound = v);
                  _save('sound_enabled', v);
                },
              ),
              SwitchListTile(
                title: const Text('通知（王国からの手紙）'),
                value: _notification,
                activeColor: KdColors.pink500,
                onChanged: (v) {
                  setState(() => _notification = v);
                  _save('notification_enabled', v);
                },
              ),
            ]),
          ),
          const SizedBox(height: 12),
          KdParchmentCard(
            child: Column(children: [
              ListTile(
                title: const Text('利用規約'),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () {/* TODO(release): url_launcher で規約URLへ */},
              ),
              ListTile(
                title: const Text('プライバシーポリシー'),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () {/* TODO(release): url_launcher でポリシーURLへ */},
              ),
              ListTile(
                title: const Text('お問い合わせ'),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () {/* TODO(release): サポートフォームへ */},
              ),
            ]),
          ),
          const SizedBox(height: 12),
          KdParchmentCard(
            child: ListTile(
              title: const Text('アカウントを削除する',
                  style: TextStyle(color: KdColors.lava500)),
              subtitle: const Text('すべてのデータが完全に削除されます'),
              onTap: _confirmDelete,
            ),
          ),
        ]),
      ),
    );
  }
}
