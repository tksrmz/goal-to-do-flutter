import 'package:flutter_test/flutter_test.dart';
import 'package:goal_to_do/data/theme_mode_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  void useStorage(Map<String, Object> data) =>
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData(data);

  test('保存されていなければシステムに合わせる', () async {
    useStorage({});
    final repository = await SharedPreferencesThemeModeRepository.open();
    expect(repository.load(), ThemeMode.system);
  });

  test('保存したテーマを、開き直しても読み込める', () async {
    useStorage({});
    await (await SharedPreferencesThemeModeRepository.open()).save(
      ThemeMode.dark,
    );
    final reopened = await SharedPreferencesThemeModeRepository.open();
    expect(reopened.load(), ThemeMode.dark);
  });

  test('知らない値が保存されていたらシステムに合わせる', () async {
    useStorage({SharedPreferencesThemeModeRepository.key: 'sepia'});
    final repository = await SharedPreferencesThemeModeRepository.open();
    expect(repository.load(), ThemeMode.system);
  });
}
