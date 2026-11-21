import 'dart:ui' show Tristate;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:netmap/widgets/floating_toolbar.dart';

import 'harness.dart';

void main() {
  noFlash();
  testWidgets('wide: the toolbar names every section', (t) async {
    await pumpApp(t);
    expect(find.text('Mappa'), findsOneWidget);
    expect(find.bySemanticsLabel('Dispositivi'), findsOneWidget);
    expect(find.bySemanticsLabel('Navigazione principale'), findsOneWidget);
  });

  testWidgets('navigating changes the selected item', (t) async {
    await pumpApp(t, locale: const Locale('en'));
    final sem = t.ensureSemantics();
    await t.tap(find.bySemanticsLabel('Devices'));
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Search by name, person or address'), findsOneWidget);
    Finder inBar(String label) => find.descendant(of: find.byType(FloatingNavToolbar), matching: find.bySemanticsLabel(label));
    expect(t.getSemantics(inBar('Devices')).flagsCollection.isSelected, Tristate.isTrue);
    expect(t.getSemantics(inBar('Map')).flagsCollection.isSelected, Tristate.isFalse);
    sem.dispose();
  });

  testWidgets('phone: the toolbar moves to the bottom', (t) async {
    await pumpApp(t, size: const Size(390, 844));
    final y = t.getCenter(find.bySemanticsLabel('Navigazione principale')).dy;
    expect(y, greaterThan(700));
  });
}

void noFlash() {
  testWidgets('changing page never shows the previous one, not even for a frame', (t) async {
    await pumpApp(t, locale: const Locale('en'));
    final old = t.getRect(find.text('Hi Alice')).inflate(8);
    Future<List<int>> sample() async => (await t.runAsync(() async {
      final image = await captureImage(find.byType(MaterialApp).evaluate().single);
      final data = (await image.toByteData())!;
      return [
        for (var y = old.top.ceil(); y < old.bottom.floor(); y += 2)
          for (var x = old.left.ceil(); x < old.right.floor(); x += 2) data.getUint32((y * image.width + x) * 4),
      ];
    }))!;
    final before = await sample();
    await t.tap(find.descendant(of: find.byType(FloatingNavToolbar), matching: find.bySemanticsLabel('Devices')));
    await t.pump(); // the route changes
    await t.pump(const Duration(milliseconds: 16)); // the new page's first frame
    final after = await sample();
    // where the old greeting was, (almost) nothing of the old page is left:
    // the new page replaces it on its first frame
    final same = [for (var i = 0; i < before.length; i++) before[i] == after[i]].where((x) => x).length;
    expect(same / before.length, lessThan(.1));
  });
}
