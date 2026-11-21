import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'app/router.dart';
import 'app/settings.dart';
import 'app/theme.dart';
import 'l10n/app_localizations.dart';
import 'platform/document.dart';

void main() {
  // real paths (/devices/…), not #/devices: links can be shared, and the
  // server already answers every path with the app
  usePathUrlStrategy();
  runApp(const ProviderScope(child: NetmapApp()));
}

class NetmapApp extends ConsumerStatefulWidget {
  const NetmapApp({super.key, this.router});

  /// tests pass their own router (e.g. starting on another page)
  final GoRouter? router;

  @override
  ConsumerState<NetmapApp> createState() => _NetmapAppState();
}

class _NetmapAppState extends ConsumerState<NetmapApp> {
  late final GoRouter _router = widget.router ?? buildRouter();

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    debugShowCheckedModeBanner: false,
    onGenerateTitle: (context) => L.of(context).appTitle,
    theme: netmapTheme(Brightness.light),
    darkTheme: netmapTheme(Brightness.dark),
    themeMode: ref.watch(themeModeProvider),
    locale: ref.watch(localeProvider),
    supportedLocales: L.supportedLocales,
    localizationsDelegates: const [L.delegate, ...GlobalMaterialLocalizations.delegates],
    // Italian browsers get Italian, everyone else English
    localeResolutionCallback: (locale, supported) =>
        supported.firstWhere((l) => l.languageCode == locale?.languageCode, orElse: () => const Locale('en')),
    routerConfig: _router,
    builder: (context, child) {
      // <html lang> follows the language on screen, for screen readers
      setDocumentLanguage(Localizations.localeOf(context).languageCode);
      // nothing on screen animates: every change is instant
      return MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!);
    },
  );
}
