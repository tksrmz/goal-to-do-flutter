import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goal_to_do/ui/router.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fakes.dart';

void main() {
  Future<void> signIn(WidgetTester tester, String password) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'メールアドレス'),
      FakeAuthRepository.email,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'パスワード'),
      password,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'ログイン'));
    await tester.pumpAndSettle();
  }

  testWidgets('AC-003, AC-006: 未ログインならログイン画面が出て、新規登録の導線はない', (tester) async {
    await pumpApp(tester, auth: FakeAuthRepository());
    expect(find.widgetWithText(FilledButton, 'ログイン'), findsOneWidget);
    expect(find.textContaining('登録'), findsNothing);
    expect(find.text('今日やるべきタスクはありません'), findsNothing);
  });

  testWidgets('AC-002: 誤ったパスワードではエラーが出てログインできない', (tester) async {
    await pumpApp(tester, auth: FakeAuthRepository());
    await signIn(tester, 'wrong');
    expect(find.text('メールアドレスまたはパスワードが正しくありません'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'ログイン'), findsOneWidget);
  });

  testWidgets('AC-001, AC-004: ログインすると今日の画面へ、ログアウトするとログイン画面へ', (tester) async {
    await pumpApp(tester, auth: FakeAuthRepository());
    await signIn(tester, FakeAuthRepository.password);
    expect(find.widgetWithText(AppBar, '今日'), findsOneWidget);

    await tester.tap(find.byTooltip('ログアウト'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'ログイン'), findsOneWidget);
  });

  group('authRedirect', () {
    test('AC-003: 未ログインならどの画面からもログインへ', () {
      const signedOut = AsyncData<String?>(null);
      expect(authRedirect(signedOut, '/today'), '/login');
      expect(authRedirect(signedOut, '/all'), '/login');
      expect(authRedirect(signedOut, '/login'), isNull);
    });

    test('ログイン済みでログイン画面を開くと今日へ。それ以外はそのまま（AC-005）', () {
      const signedIn = AsyncData<String?>('uid');
      expect(authRedirect(signedIn, '/login'), '/today');
      expect(authRedirect(signedIn, '/all'), isNull);
    });

    test('ログイン状態の読み込み中は動かさない', () {
      expect(authRedirect(const AsyncLoading<String?>(), '/all'), isNull);
    });
  });
}
