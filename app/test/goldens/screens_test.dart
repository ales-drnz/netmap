// Golden images of the main screens, light and dark, desktop and phone.
// `flutter test --update-goldens test/goldens` rewrites them after a wanted
// change; otherwise any pixel difference fails the test.
@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:netmap/data/live.dart';

import '../harness.dart';

const desktop = Size(1280, 800);
const phone = Size(390, 844);

void main() {
  bigNetwork();
  // a real deployment's shape (see realSnapshot): wide screen, dark, and a phone
  for (final (name, size, theme) in [
    ('desktop', const Size(1920, 1080), ThemeMode.dark),
    ('laptop', const Size(1440, 900), ThemeMode.light),
    ('phone', phone, ThemeMode.dark),
  ]) {
    testWidgets('real network · $name · ${theme.name}', (t) async {
      await pumpApp(t, size: size, theme: theme, live: realLive());
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('real_${name}_${theme.name}.png'));
    });
  }
  testWidgets('real network · device detail', (t) async {
    final live = realLive();
    final id = live.snap!.nodes.firstWhere((n) => n.name == 'fazen-pc-3').id;
    await pumpApp(t, size: const Size(1440, 900), theme: ThemeMode.dark, live: live, location: '/devices/$id');
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('real_detail_dark.png'));
  });
  for (final (page, location) in [('devices', '/devices/0000000003'), ('activity', '/activity'), ('network', '/network')]) {
    for (final (name, size) in [('desktop', desktop), ('phone', phone)]) {
      for (final theme in [ThemeMode.light, ThemeMode.dark]) {
        testWidgets('$page · $name · ${theme.name}', (t) async {
          await pumpApp(t, size: size, theme: theme, location: location);
          await expectLater(find.byType(MaterialApp), matchesGoldenFile('${page}_${name}_${theme.name}.png'));
        });
      }
    }
  }
  for (final (name, size) in [('desktop', desktop), ('phone', phone)]) {
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('home · $name · ${theme.name}', (t) async {
        await pumpApp(t, size: size, theme: theme);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('home_${name}_${theme.name}.png'));
      });
    }
  }
}

void bigNetwork() {
  testWidgets('home · 200 devices · desktop · light', (t) async {
    final s = bigSnapshot(extra: 80);
    expect(s.nodes.length, greaterThanOrEqualTo(150));
    await pumpApp(
      t,
      live: LiveState(snap: s, me: fixtureMe, receivedAt: fixtureNow - 3000),
    );
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('home_big_desktop_light.png'));
  });
}
