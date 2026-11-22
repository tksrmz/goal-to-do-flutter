import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';
import 'data/theme_mode_repository.dart';
import 'firebase_options_dev.dart';
import 'providers/providers.dart';

/// `--dart-define=USE_FIREBASE_EMULATOR=true` でローカルの Emulator Suite に接続する。
const _useFirebaseEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // URL を `/#/today` ではなく `/today` にする。Hosting は全パスを index.html へ書き換える（firebase.json）
  usePathUrlStrategy();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final firestore = FirebaseFirestore.instance;
  // NFR-007: Web のオフライン永続化を有効にし、複数タブ間で同期する。
  // 設定は Firestore の他の API を呼ぶ前に行う必要がある。
  firestore.settings = const Settings(
    persistenceEnabled: true,
    webPersistentTabManager: WebPersistentMultipleTabManager(),
  );

  if (_useFirebaseEmulator) {
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    firestore.useFirestoreEmulator('localhost', 8080);
  }

  // FR-011: 保存したテーマを最初の画面から使えるよう、先に読み込む
  final themeModes = await _openThemeModeRepository();

  runApp(
    ProviderScope(
      overrides: [themeModeRepositoryProvider.overrideWithValue(themeModes)],
      child: const App(),
    ),
  );
}

/// ブラウザの保存領域が使えない（無効にされているなど）ときも起動できるよう、メモリで代わりにする。
Future<ThemeModeRepository> _openThemeModeRepository() async {
  try {
    return await SharedPreferencesThemeModeRepository.open();
  } catch (_) {
    return MemoryThemeModeRepository();
  }
}
