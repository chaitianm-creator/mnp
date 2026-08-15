/// 外部リンクを開く(Webは新しいタブ、テスト環境ではno-op)。
export 'external_link_stub.dart'
    if (dart.library.js_interop) 'external_link_web.dart';
