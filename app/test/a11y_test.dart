// Accessibility guidelines from flutter_test on every page, both themes,
// desktop and phone: tap targets ≥ 48 dp and labelled tap targets.
//
// Text contrast is checked in contrast_test.dart on the colour pairs
// themselves: flutter_test's textContrastGuideline samples pixels and is made
// for the blocky test font; with the real, anti-aliased fonts loaded here it
// reports ~2:1 for text that measures 15:1.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'harness.dart';

void main() {
  const pages = ['/', '/devices', '/devices/0000000003', '/activity', '/network'];
  for (final location in pages) {
    for (final (name, size) in [('desktop', const Size(1280, 800)), ('phone', const Size(390, 844))]) {
      for (final theme in [ThemeMode.light, ThemeMode.dark]) {
        testWidgets('a11y $location · $name · ${theme.name}', (t) async {
          final handle = t.ensureSemantics();
          await pumpApp(t, size: size, theme: theme, location: location);
          await expectLater(t, meetsGuideline(androidTapTargetGuideline));
          await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
          handle.dispose();
        });
      }
    }
  }
}
