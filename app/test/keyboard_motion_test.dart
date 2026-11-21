import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:netmap/map/map_painter.dart';

import 'harness.dart';

MapPainter painter(WidgetTester t) =>
    t.widget<CustomPaint>(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is MapPainter)).painter! as MapPainter;

void main() {
  testWidgets('Tab reaches the toolbar, Enter follows it', (t) async {
    await pumpApp(t, locale: const Locale('en'));
    // Tab until the "Devices" item has focus
    var found = false;
    for (var i = 0; i < 15 && !found; i++) {
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      // each item is a Semantics node labelled with its name
      found = FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<Semantics>()?.properties.label == 'Devices';
    }
    expect(found, isTrue);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump();
    expect(find.text('Search by name, person or address'), findsOneWidget);
  });

  testWidgets('the map is drawn at once, without an entry animation', (t) async {
    await pumpApp(t);
    expect(painter(t).layout.nodes, isNotEmpty);
    expect(t.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('text at twice the size still fits (no overflow)', (t) async {
    t.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    for (final location in ['/', '/devices', '/activity', '/network']) {
      await pumpApp(t, location: location);
      expect(t.takeException(), isNull, reason: location);
    }
  });
}
