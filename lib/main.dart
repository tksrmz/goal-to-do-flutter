import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options_dev.dart';

/// `--dart-define=USE_FIREBASE_EMULATOR=true` でローカルの Emulator Suite に接続する。
const _useFirebaseEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('Hello World!'))),
    );
  }
}
