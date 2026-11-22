import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../providers/providers.dart';

/// 認証が必要な画面の共通の枠。今日・すべてへのナビゲーションとログアウトを置く（REQ-001 7章）。
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.title,
    required this.body,
    this.floatingActionButton,
  });

  final String title;
  final Widget body;
  final Widget? floatingActionButton;

  static const _destinations = [
    (
      path: '/today',
      label: '今日',
      icon: Icons.today_outlined,
      selectedIcon: Icons.today,
    ),
    (
      path: '/all',
      label: 'すべて',
      icon: Icons.account_tree_outlined,
      selectedIcon: Icons.account_tree,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final selected = _destinations.indexWhere((d) => d.path == location);
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          const _ThemeModeMenu(),
          IconButton(
            tooltip: 'ログアウト',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: body,
          ),
        ),
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected < 0 ? 0 : selected,
        onDestinationSelected: (index) => context.go(_destinations[index].path),
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

/// テーマの切り替え（REQ-001 FR-011）。アイコンは選んでいるテーマを表す。
class _ThemeModeMenu extends ConsumerWidget {
  const _ThemeModeMenu();

  static const _options = [
    (mode: ThemeMode.system, label: 'システムに合わせる', icon: Icons.brightness_auto),
    (mode: ThemeMode.light, label: 'ライト', icon: Icons.light_mode),
    (mode: ThemeMode.dark, label: 'ダーク', icon: Icons.dark_mode),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appThemeModeProvider);
    return PopupMenuButton<ThemeMode>(
      tooltip: 'テーマ',
      icon: Icon(_options.firstWhere((o) => o.mode == current).icon),
      initialValue: current,
      onSelected: ref.read(appThemeModeProvider.notifier).select,
      itemBuilder: (context) => [
        for (final o in _options)
          CheckedPopupMenuItem(
            value: o.mode,
            checked: o.mode == current,
            child: Text(o.label),
          ),
      ],
    );
  }
}
