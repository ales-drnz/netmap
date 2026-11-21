// Theme and language: chosen by the viewer, remembered in this browser.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../platform/storage.dart';

const supportedLanguages = ['it', 'en'];

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => switch (readPref('theme')) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  void set(ThemeMode mode) {
    state = mode;
    writePref('theme', mode == ThemeMode.system ? null : mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

/// null = follow the browser language
class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() {
    final saved = readPref('lang');
    return supportedLanguages.contains(saved) ? Locale(saved!) : null;
  }

  void set(Locale? locale) {
    state = locale;
    writePref('lang', locale?.languageCode);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(LocaleNotifier.new);
