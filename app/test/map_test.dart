import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:netmap/map/map_view.dart';
import 'package:netmap/pages/device_detail.dart';
import 'package:netmap/pages/devices_page.dart';

import 'harness.dart';

void main() {
  readouts();
  testWidgets('every device on the map is a labelled button for screen readers', (t) async {
    final sem = t.ensureSemantics();
    await pumpApp(t);
    expect(find.semantics.byLabel(RegExp(r'^alice-phone, Tu, Alice, Tramite relay$')), findsOne);
    expect(find.semantics.byLabel(RegExp(r'^carol-pc, Carol, Senza risposta$')), findsOne);
    expect(find.semantics.byLabel(RegExp(r'^lab-pi, Lab, Offline, Inattivo$')), findsOne);
    sem.dispose();
  });

  testWidgets('tapping a device opens it beside the map; closing it clears it', (t) async {
    final sem = t.ensureSemantics();
    await pumpApp(t);
    t.semantics.tap(find.semantics.byLabel(RegExp(r'^carol-pc,')));
    await t.pump();
    // still on the map, with the device's panel beside it
    expect(find.byType(MapView), findsOneWidget);
    expect(find.byType(DevicesPage), findsNothing);
    expect(find.byType(DeviceDetail), findsOneWidget);
    expect(find.text('Dettagli tecnici'), findsOneWidget);
    await t.tap(find.descendant(of: find.byType(DeviceDetail), matching: find.byTooltip('Chiudi')));
    await t.pump();
    expect(find.byType(DeviceDetail), findsNothing);
    sem.dispose();
  });

  testWidgets('on a phone the device takes the sheet', (t) async {
    final sem = t.ensureSemantics();
    await pumpApp(t, size: const Size(390, 844));
    t.semantics.tap(find.semantics.byLabel(RegExp(r'^carol-pc,')));
    await t.pump();
    expect(find.byType(DeviceDetail), findsOneWidget);
    expect(find.text('Ciao Alice'), findsNothing);
    sem.dispose();
  });

  testWidgets('the keyboard walks the map', (t) async {
    await pumpApp(t);
    // focus the map, then use the arrows
    final map = find.byType(MapView);
    final focus = Focus.of(t.element(find.descendant(of: map, matching: find.byType(InteractiveViewer))));
    focus.requestFocus();
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pump(const Duration(milliseconds: 300));
    final container = ProviderScope.containerOf(t.element(map));
    final first = container.read(selectedDeviceProvider);
    expect(first, isNotNull);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pump(const Duration(milliseconds: 300));
    expect(container.read(selectedDeviceProvider), isNot(first));
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump();
    expect(container.read(selectedDeviceProvider), isNull);
  });
}

void readouts() {
  testWidgets('screen readers hear each toolbar item once, and which service a button opens', (t) async {
    final sem = t.ensureSemantics();
    await pumpApp(t);
    expect(find.bySemanticsLabel('Dispositivi'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Dispositivi\nDispositivi')), findsNothing);
    expect(find.bySemanticsLabel(RegExp(r'^Apri, Jellyfin')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Apri, Nextcloud')), findsOneWidget);
    sem.dispose();
  });
}
