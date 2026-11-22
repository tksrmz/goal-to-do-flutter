import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// テーマ（システムに合わせる・ライト・ダーク）の保存先。ブラウザごとに保存し、
/// 端末間では同期しない（REQ-001 FR-011）。
abstract interface class ThemeModeRepository {
  /// 保存されたテーマ。保存されていなければ [ThemeMode.system]。
  ThemeMode load();

  Future<void> save(ThemeMode mode);
}

/// shared_preferences に保存する。Web ではブラウザの localStorage に入る。
class SharedPreferencesThemeModeRepository implements ThemeModeRepository {
  SharedPreferencesThemeModeRepository(this._preferences);

  static const key = 'themeMode';

  /// 起動時に一度だけ作る。読み込みを済ませておくので、最初の画面から保存したテーマで出せる。
  static Future<SharedPreferencesThemeModeRepository> open() async =>
      SharedPreferencesThemeModeRepository(
        await SharedPreferencesWithCache.create(
          cacheOptions: const SharedPreferencesWithCacheOptions(
            allowList: {key},
          ),
        ),
      );

  final SharedPreferencesWithCache _preferences;

  @override
  ThemeMode load() =>
      ThemeMode.values.asNameMap()[_preferences.getString(key)] ??
      ThemeMode.system;

  @override
  Future<void> save(ThemeMode mode) => _preferences.setString(key, mode.name);
}

/// メモリにだけ持つ。ブラウザの保存領域が使えないときの代わりと、テストに使う。
class MemoryThemeModeRepository implements ThemeModeRepository {
  MemoryThemeModeRepository([this.mode = ThemeMode.system]);

  ThemeMode mode;

  @override
  ThemeMode load() => mode;

  @override
  Future<void> save(ThemeMode mode) async => this.mode = mode;
}
