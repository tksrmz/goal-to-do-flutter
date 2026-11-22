import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'providers/providers.dart';
import 'ui/router.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  static final _theme = _themeFor(Brightness.light);
  static final _darkTheme = _themeFor(Brightness.dark);

  static ThemeData _themeFor(Brightness brightness) => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.indigo,
      brightness: brightness,
    ),
  );

  @override
  Widget build(BuildContext context) {
    // 書き込みの失敗を知らせる。失敗したバッチは、ローカルでの反映も取り消される（6.3.7）
    ref.listen(writeErrorsProvider, (_, next) {
      if (next.error == null) return;
      _messengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('保存できませんでした。操作は取り消されました')),
      );
    });

    // 保存されたログイン状態を読み込むまでは、画面の代わりに読み込み中を出す。その間 redirect は
    // 動かないので、読み込み後にリロード前の画面がそのまま出る（AC-005）。
    // ここで別の MaterialApp を出すと、ブラウザの URL が `/` に書き換わってしまうので、
    // ルーターは最初から出しておき、builder で覆う。
    final userId = ref.watch(userIdProvider);
    final authLoading = !userId.hasValue && !userId.hasError;

    return MaterialApp.router(
      title: 'Goal to Do',
      theme: _theme,
      darkTheme: _darkTheme,
      themeMode: ref.watch(appThemeModeProvider),
      scaffoldMessengerKey: _messengerKey,
      routerConfig: ref.watch(routerProvider),
      locale: const Locale('ja'),
      supportedLocales: const [Locale('ja')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => authLoading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : child!,
    );
  }
}
