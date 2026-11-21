// Every text/background pair the app uses, measured with the WCAG formula in
// both themes: 4.5:1 for text, 3:1 for shapes, lines and icons.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:netmap/app/theme.dart';

void main() {
  dimmed();
  for (final b in Brightness.values) {
    final t = netmapTheme(b);
    final c = t.colorScheme;
    final l = t.extension<LinkColors>()!;
    final surfaces = {
      'surface': c.surface,
      'surfaceContainerLow': c.surfaceContainerLow,
      'surfaceContainer': c.surfaceContainer,
      'surfaceContainerHigh': c.surfaceContainerHigh,
      'surfaceContainerHighest': c.surfaceContainerHighest,
    };

    group(b.name, () {
      test('text on surfaces ≥ 4.5', () {
        for (final MapEntry(:key, :value) in surfaces.entries) {
          for (final (name, fg) in [
            ('onSurface', c.onSurface),
            ('onSurfaceVariant', c.onSurfaceVariant),
            ('primary', c.primary),
            ('direct', l.direct.color),
            ('relay', l.relay.color),
            ('oneWay', l.oneWay.color),
          ]) {
            expect(contrastRatio(fg, value), greaterThanOrEqualTo(4.5), reason: '$name on $key');
          }
        }
      });

      test('text on containers ≥ 4.5', () {
        for (final (name, fg, bg) in [
          ('onPrimary', c.onPrimary, c.primary),
          ('onPrimaryContainer', c.onPrimaryContainer, c.primaryContainer),
          ('onSecondaryContainer', c.onSecondaryContainer, c.secondaryContainer),
          ('onTertiaryContainer', c.onTertiaryContainer, c.tertiaryContainer),
          ('onDirectContainer', l.direct.onContainer, l.direct.container),
          // device icons on the flat state circles
          ('onDirect', l.direct.onColor, l.direct.color),
          ('onRelay', l.relay.onColor, l.relay.color),
          ('onOneWay', l.oneWay.onColor, l.oneWay.color),
          ('offline icon', c.onSurfaceVariant, c.outlineVariant),
          ('onRelayContainer', l.relay.onContainer, l.relay.container),
          ('onOneWayContainer', l.oneWay.onContainer, l.oneWay.container),
          ('onInverseSurface', c.onInverseSurface, c.inverseSurface),
        ]) {
          expect(contrastRatio(fg, bg), greaterThanOrEqualTo(4.5), reason: name);
        }
      });

      test('shapes and lines ≥ 3 against the map', () {
        for (final (name, fg) in [
          ('direct', l.direct.color),
          ('relay', l.relay.color),
          ('oneWay', l.oneWay.color),
          ('outline', c.outline),
          ('primary', c.primary),
        ]) {
          expect(contrastRatio(fg, c.surface), greaterThanOrEqualTo(3), reason: name);
          expect(contrastRatio(fg, c.surfaceContainerHigh), greaterThanOrEqualTo(3), reason: '$name on boxes');
        }
      });
    });
  }
}

void dimmed() {
  test('inactive devices: dimmed text still reads at AA', () {
    for (final b in Brightness.values) {
      final c = netmapTheme(b).colorScheme;
      final dimmed = Color.alphaBlend(c.onSurfaceVariant.withValues(alpha: .8), c.surface);
      expect(contrastRatio(dimmed, c.surface), greaterThanOrEqualTo(4.5), reason: b.name);
    }
  });
}
