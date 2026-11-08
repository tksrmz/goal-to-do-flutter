import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../providers/providers.dart';
import 'all_page.dart';
import 'login_page.dart';
import 'today_page.dart';

part 'router.g.dart';

/// ルーティング（DES-001 6.4）。
///
/// - 未ログインで認証が必要な画面を開くと `/login` へ、ログイン済みで `/login` を開くと `/today` へ移る
/// - 認証状態が変わったら `redirect` を評価し直す（`refreshListenable`）
@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final authChanged = ValueNotifier<int>(0);
  ref
    ..listen(userIdProvider, (_, _) => authChanged.value++)
    ..onDispose(authChanged.dispose);

  final router = GoRouter(
    initialLocation: '/today',
    refreshListenable: authChanged,
    redirect: (context, state) =>
        authRedirect(ref.read(userIdProvider), state.matchedLocation),
    // 存在しない URL は今日の画面へ（未ログインなら、そこからさらにログインへ）
    onException: (context, state, router) => router.go('/today'),
    routes: [
      GoRoute(path: '/', redirect: (context, state) => '/today'),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: LoginPage()),
      ),
      GoRoute(
        path: '/today',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: TodayPage()),
      ),
      GoRoute(
        path: '/all',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: AllPage()),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}

/// 認証状態によるリダイレクト先。そのままでよければ `null`。
@visibleForTesting
String? authRedirect(AsyncValue<String?> userId, String location) {
  // 起動直後、保存されたログイン状態を読み込むまでは動かさない（リロード前の画面に戻すため。AC-005）。
  // その間、App は画面を読み込み中の表示で覆う。
  if (!userId.hasValue && !userId.hasError) return null;
  final signedIn = userId.value != null;
  final onLogin = location == '/login';
  if (!signedIn) return onLogin ? null : '/login';
  if (onLogin) return '/today';
  return null;
}
