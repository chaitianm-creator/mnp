import 'package:web/web.dart' as web;

/// Web: 外部URLを新しいタブで開く。
void openExternal(String url) {
  web.window.open(url, '_blank');
}
