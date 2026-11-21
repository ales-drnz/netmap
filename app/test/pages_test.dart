import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'harness.dart';

void main() {
  testWidgets('devices: search by person, filter by link', (t) async {
    await pumpApp(t, location: '/devices');
    await t.enterText(find.byType(TextField).first, 'carol');
    await t.pump();
    expect(find.text('carol-pc'), findsOneWidget);
    expect(find.text('carol2-pc'), findsOneWidget);
    expect(find.text('bob-phone'), findsNothing);

    await t.enterText(find.byType(TextField).first, '');
    await t.tap(find.widgetWithText(FilterChip, 'Tramite relay'));
    await t.pump();
    expect(find.text('frank-console'), findsOneWidget);
    expect(find.text('alice-pc'), findsNothing);
  });

  testWidgets('devices: inactive devices are always listed, with the word', (t) async {
    await pumpApp(t, location: '/devices');
    await t.scrollUntilVisible(find.text('lab-pi'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('Inattivo'), findsWidgets);
  });

  testWidgets('a device: link in the header, numbers, then its technical details, all shown', (t) async {
    await pumpApp(t, location: '/devices/0000000003');
    expect(find.text('alice-phone'), findsWidgets);
    expect(find.textContaining('Tramite relay · telefono di Alice · Tu'), findsOneWidget);
    // no explanatory sentence, no "—" for unknown numbers
    expect(find.textContaining('strada diretta'), findsNothing);
    expect(find.text('—'), findsNothing);
    expect(find.text('Ultimo contatto'), findsOneWidget);
    // technical details shown at once: nothing to expand
    expect(find.byType(ExpansionTile), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(find.text('Dettagli tecnici'), findsOneWidget);
    expect(find.text('ID nodo'), findsOneWidget);
    expect(find.text('Indirizzo ZeroTier'), findsWidgets);
  });

  testWidgets('wide devices page: never an empty pane', (t) async {
    await pumpApp(t, location: '/devices');
    await t.pump();
    // you (alice-phone) are shown on the right
    expect(find.text('ID nodo'), findsOneWidget);
    expect(find.textContaining('telefono di Alice'), findsOneWidget);
  });

  testWidgets('activity: requests waiting first, once, filter by kind', (t) async {
    await pumpApp(t, location: '/activity');
    expect(find.text('In attesa · 2'), findsOneWidget);
    expect(find.text('guest-laptop'), findsOneWidget);
    // the waiting requests are not repeated as events; the revoked one says so
    expect(find.textContaining('guest-laptop'), findsOneWidget);
    expect(find.textContaining('old-laptop'), findsOneWidget);
    expect(find.textContaining('revocato'), findsOneWidget);
    await t.tap(find.widgetWithText(ChoiceChip, 'Latenza alta'));
    await t.pump();
    expect(find.textContaining('Latenza alta su'), findsWidgets);
    expect(find.textContaining('è andato offline'), findsNothing);
    expect(find.text('In attesa · 2'), findsNothing);
  });

  testWidgets('activity: who dropped together is said, not behind a button', (t) async {
    await pumpApp(t, location: '/activity');
    await t.scrollUntilVisible(find.text('bob-tablet, carol2-pc, lab-pi'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('search lives only in Devices: no global search', (t) async {
    await pumpApp(t);
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.keyK);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await t.pump();
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.byTooltip('Cerca (Ctrl K)'), findsNothing);
  });
}
