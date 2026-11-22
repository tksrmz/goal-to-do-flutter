import 'package:flutter_test/flutter_test.dart';
import 'package:goal_to_do/data/theme_mode_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fakes.dart';

void main() {
  Brightness brightness(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(AppBar))).brightness;

  void setSystemBrightness(WidgetTester tester, Brightness value) {
    tester.platformDispatcher.platformBrightnessTestValue = value;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  }

  Future<void> selectTheme(WidgetTester tester, String label) async {
    await tester.tap(find.byTooltip('テーマ'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<ThemeMode>, label),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('AC-061: 既定では端末の設定に合わせる', (tester) async {
    setSystemBrightness(tester, Brightness.dark);
    await pumpApp(tester, auth: FakeAuthRepository(signedInAs: 'uid'));
    expect(brightness(tester), Brightness.dark);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(brightness(tester), Brightness.light);
  });

  testWidgets('AC-062: ダーク・ライトを選ぶと端末の設定によらず切り替わり、保存される', (tester) async {
    setSystemBrightness(tester, Brightness.light);
    final themeModes = MemoryThemeModeRepository();
    await pumpApp(
      tester,
      auth: FakeAuthRepository(signedInAs: 'uid'),
      themeModes: themeModes,
    );

    await selectTheme(tester, 'ダーク');
    expect(brightness(tester), Brightness.dark);
    expect(themeModes.mode, ThemeMode.dark);

    // すべての画面へ移っても同じテーマのまま
    await tester.tap(find.text('すべて'));
    await tester.pumpAndSettle();
    expect(brightness(tester), Brightness.dark);

    setSystemBrightness(tester, Brightness.dark);
    await selectTheme(tester, 'ライト');
    expect(brightness(tester), Brightness.light);
    expect(themeModes.mode, ThemeMode.light);

    await selectTheme(tester, 'システムに合わせる');
    expect(brightness(tester), Brightness.dark);
    expect(themeModes.mode, ThemeMode.system);
  });

  testWidgets('AC-063: 保存したテーマで起動する（ログイン画面も含む）', (tester) async {
    setSystemBrightness(tester, Brightness.light);
    await pumpApp(
      tester,
      auth: FakeAuthRepository(),
      themeModes: MemoryThemeModeRepository(ThemeMode.dark),
    );
    expect(
      Theme.of(tester.element(find.text('ログイン').first)).brightness,
      Brightness.dark,
    );
  });
}
