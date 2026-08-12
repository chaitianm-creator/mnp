import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// きせかえ(主人公の服)の選択状態。SharedPreferencesに保存する。
final outfitProvider =
    NotifierProvider<OutfitNotifier, int>(OutfitNotifier.new);

class OutfitNotifier extends Notifier<int> {
  static const _key = 'outfit_id';

  @override
  int build() {
    _load();
    return 0;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getInt(_key) ?? 0;
      if (v != state) state = v;
    } catch (_) {}
  }

  Future<void> select(int i) async {
    state = i;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key, i);
    } catch (_) {}
  }
}
