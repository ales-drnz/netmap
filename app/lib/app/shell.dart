// The frame around every page: a floating toolbar for navigation (top-centre on
// wide screens, bottom-centre on phones) and the overflow menu with theme,
// language and the version.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../widgets/floating_toolbar.dart';
import 'settings.dart';
import 'theme.dart';
import 'version.dart';

/// Window size classes (M3): compact < 600 ≤ medium < 840 ≤ expanded.
enum WindowSize { compact, medium, expanded }

WindowSize windowSizeOf(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  return w < 600 ? WindowSize.compact : (w < 840 ? WindowSize.medium : WindowSize.expanded);
}

/// Space a page must leave free for the floating toolbar.
EdgeInsets toolbarInsets(BuildContext context) =>
    windowSizeOf(context) == WindowSize.expanded ? const EdgeInsets.only(top: 104) : const EdgeInsets.only(bottom: 96);

const _routes = ['/', '/devices', '/activity', '/network'];

/// Width of the wide toolbar with every section named (measured: 584 px in
/// English, 590 px in Italian), rounded up. Panels beside it use this to know
/// whether they fit next to it at the top.
const double wideToolbarWidth = 600;

/// Whether a panel [panelWidth] wide, 24 px from the left or right edge, fits
/// beside the centred toolbar at the top of a [screenWidth] screen.
bool fitsBesideToolbar(double screenWidth, double panelWidth) => (screenWidth - wideToolbarWidth) / 2 >= 24 + panelWidth + 16;

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  int get _selected {
    if (location == '/') return 0;
    for (var i = 1; i < _routes.length; i++) {
      if (location.startsWith(_routes[i])) return i;
    }
    return -1;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final wide = windowSizeOf(context) == WindowSize.expanded;
    final dests = [
      ToolbarDestination(icon: Symbols.hub_rounded, label: l.navMap),
      ToolbarDestination(icon: Symbols.devices_rounded, label: l.navDevices),
      ToolbarDestination(icon: Symbols.history_rounded, label: l.navActivity),
      ToolbarDestination(icon: Symbols.lan_rounded, label: l.navNetwork),
    ];
    final c = context.colors;
    final toolbar = FloatingNavToolbar(
      semanticLabel: l.navMain,
      labels: switch (MediaQuery.sizeOf(context).width) {
        >= 760 => ToolbarLabels.all,
        >= 440 => ToolbarLabels.selected,
        _ => ToolbarLabels.none,
      },
      destinations: dests,
      selected: _selected,
      onSelected: (i) => context.go(_routes[i]),
      trailing: [_MoreMenu(onPrimaryContainer: c.onPrimaryContainer)],
    );

    return Focus(
      autofocus: true,
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(child: child),
            if (wide)
              // centred at the top; taps beside it reach the page below
              Positioned(
                left: 0,
                right: 0,
                top: 24,
                child: SafeArea(child: Center(child: toolbar)),
              )
            else
              Positioned(
                left: 0,
                right: 0,
                bottom: 16,
                child: SafeArea(top: false, child: Center(child: toolbar)),
              ),
          ],
        ),
      ),
    );
  }
}

class _MoreMenu extends ConsumerWidget {
  const _MoreMenu({required this.onPrimaryContainer});
  final Color onPrimaryContainer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final mode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    MenuItemButton check(String label, bool on, VoidCallback f) =>
        MenuItemButton(onPressed: f, leadingIcon: Icon(on ? Symbols.check_rounded : null, size: 20), child: Text(label));
    return MenuAnchor(
      menuChildren: [
        SubmenuButton(
          leadingIcon: const Icon(Symbols.contrast_rounded),
          menuChildren: [
            check(l.themeSystem, mode == ThemeMode.system, () => ref.read(themeModeProvider.notifier).set(ThemeMode.system)),
            check(l.themeLight, mode == ThemeMode.light, () => ref.read(themeModeProvider.notifier).set(ThemeMode.light)),
            check(l.themeDark, mode == ThemeMode.dark, () => ref.read(themeModeProvider.notifier).set(ThemeMode.dark)),
          ],
          child: Text(l.theme),
        ),
        SubmenuButton(
          leadingIcon: const Icon(Symbols.translate_rounded),
          menuChildren: [
            check(l.languageSystem, locale == null, () => ref.read(localeProvider.notifier).set(null)),
            check('Italiano', locale?.languageCode == 'it', () => ref.read(localeProvider.notifier).set(const Locale('it'))),
            check('English', locale?.languageCode == 'en', () => ref.read(localeProvider.notifier).set(const Locale('en'))),
          ],
          child: Text(l.language),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(l.version(appVersion), style: context.type.labelMedium?.copyWith(color: context.colors.onSurfaceVariant)),
        ),
      ],
      builder: (context, controller, _) => IconButton(
        tooltip: l.more,
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
        icon: Icon(Symbols.more_vert_rounded, color: onPrimaryContainer),
      ),
    );
  }
}
