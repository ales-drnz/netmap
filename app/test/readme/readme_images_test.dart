// The screenshots in the README (imgs/*.png), drawn by the app itself with
// the mock's data, in English. They are goldens too: if the app changes, this
// test fails until `flutter test --update-goldens test/readme` refreshes them,
// so the README never shows an old interface.
@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:netmap/data/live.dart';

import '../harness.dart';

const desktop = Size(1440, 900);
const en = Locale('en');

/// imgs/ at the root of the repository
String img(String name) => '../../../imgs/$name.png';

void main() {
  testWidgets('overview: the map, you, the hub and every device in a box', (t) async {
    await pumpApp(t, size: desktop, locale: en);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile(img('overview')));
  });

  testWidgets('map: a device in plain words', (t) async {
    final sem = t.ensureSemantics();
    await pumpApp(t, size: desktop, locale: en);
    t.semantics.tap(find.semantics.byLabel(RegExp(r'^carol-pc,')));
    // a tap on the map opens the device beside it
    await t.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile(img('map')));
    sem.dispose();
  });

  testWidgets('devices: every device and its technical details', (t) async {
    await pumpApp(t, size: desktop, locale: en, location: '/devices/0000000002');
    await expectLater(find.byType(MaterialApp), matchesGoldenFile(img('devices')));
  });

  testWidgets('stats: the network over time', (t) async {
    await pumpApp(t, size: const Size(1440, 2300), locale: en, location: '/network');
    await expectLater(find.byType(MaterialApp), matchesGoldenFile(img('stats')));
  });

  testWidgets('dark theme', (t) async {
    await pumpApp(t, size: desktop, locale: en, theme: ThemeMode.dark);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile(img('dark')));
  });

  testWidgets('on a phone', (t) async {
    await pumpApp(t, size: const Size(390, 844), locale: en);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile(img('phone')));
  });

  testWidgets('a big network, from afar', (t) async {
    await pumpApp(
      t,
      size: desktop,
      locale: en,
      live: LiveState(snap: bigSnapshot(extra: 80), me: fixtureMe, receivedAt: fixtureNow - 3000),
    );
    await expectLater(find.byType(MaterialApp), matchesGoldenFile(img('big')));
  });
}
