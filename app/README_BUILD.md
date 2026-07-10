# デザイン王国 — ビルド手順(Flutter 3.44+)

## Web(DEMOモード・Firebase不要)
```bash
cd app
flutter pub get
flutter build web        # → build/web/ に出力
# または開発実行:
flutter run -d chrome
```
※ ブラウザではウィンドウをスマホ幅に、または DevTools(F12)のデバイスモードで確認してください。

## テスト
```bash
flutter test             # 状態機械6 + コアジャーニー2
```

## モバイル(Android/iOS)
プラットフォームフォルダは同梱していません。初回のみ生成してください:
```bash
cd app
flutter create . --platforms android,ios --project-name design_kingdom
flutter run
```

## 本番モード(Firebase)
```bash
flutterfire configure    # firebase_options.dart 生成後、
                         # lib/core/firebase/firebase_bootstrap.dart の initializeApp に options を渡す
flutter build web --dart-define=USE_FIREBASE=true
```

## Firebase Hostingへの公開(https://<project>.web.app)
```bash
cd app && flutter build web && cd ..
firebase login
firebase use <your-project-id>   # または firebase projects:create
firebase deploy --only hosting
# → https://<your-project-id>.web.app で公開されます
```
※ firebase.json に hosting 設定(public: app/build/web, SPA rewrite)は同梱済みです。
