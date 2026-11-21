import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// The fixture is a real mock snapshot: home-tv happened to be offline, so 7 of 11.
import 'package:material_ui/material_ui.dart';
import 'package:netmap/data/api.dart';
import 'package:netmap/data/live.dart';

import 'harness.dart';

void main() {
  serviceIcons();
  testWidgets('the panel says how you are connected, in plain words', (t) async {
    final sem = t.ensureSemantics();
    await pumpApp(t);
    expect(find.text('Ciao Alice'), findsOneWidget);
    expect(find.text('Tramite relay'), findsWidgets);
    expect(find.text('10.147.17.4'), findsOneWidget);
    // the legend counts what the map draws: the same words, with numbers
    expect(find.bySemanticsLabel('Diretto: 4'), findsOneWidget);
    expect(find.bySemanticsLabel('Offline: 5'), findsOneWidget);
    // no reassurances or to-dos: just the facts
    expect(find.textContaining('Funziona tutto'), findsNothing);
    expect(find.textContaining('Aggiornato'), findsNothing);
    sem.dispose();
    expect(find.textContaining('da decidere'), findsNothing);
    expect(find.text('Ultime attività'), findsNothing);
  });

  testWidgets('in English too', (t) async {
    final sem = t.ensureSemantics();
    await pumpApp(t, locale: const Locale('en'));
    expect(find.text('Hi Alice'), findsOneWidget);
    expect(find.bySemanticsLabel('Direct: 4'), findsOneWidget);
    sem.dispose();
  });

  testWidgets('an anonymous viewer gets an explanation, not an error', (t) async {
    await pumpApp(
      t,
      live: LiveState(snap: fixtureSnapshot, receivedAt: fixtureNow - 3000),
    );
    expect(find.text('Dispositivo sconosciuto'), findsOneWidget);
    expect(find.text('10.147.17.4'), findsNothing);
  });

  testWidgets('before the first snapshot it is loading', (t) async {
    await pumpApp(t, live: const LiveState());
    expect(find.text('Caricamento…'), findsOneWidget);
  });

  testWidgets('a server that stops answering is said plainly', (t) async {
    await pumpApp(
      t,
      live: LiveState(snap: fixtureSnapshot, me: fixtureMe, offline: true, receivedAt: fixtureNow - 3000),
    );
    expect(find.textContaining('Netmap non risponde'), findsOneWidget);
  });
}

void serviceIcons() {
  testWidgets('copying the address says so on the button itself', (t) async {
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await pumpApp(t);
    await t.tap(find.text('10.147.17.4'));
    await t.pump();
    await t.pump();
    expect(find.text('Copiato'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    await t.pump(const Duration(seconds: 3));
    expect(find.text('10.147.17.4'), findsOneWidget);
  });

  testWidgets('a service icon that does not load leaves the initial', (t) async {
    final links = [
      for (final (i, l) in fixtureSnapshot.links.indexed)
        QuickLink(name: l.name, url: l.url, description: l.description, up: l.up, ms: l.ms, icon: '/api/services/$i/icon?v=x'),
    ];
    final snap = Snapshot(
      updatedAt: fixtureSnapshot.updatedAt,
      networkId: fixtureSnapshot.networkId,
      networkName: fixtureSnapshot.networkName,
      nodes: fixtureSnapshot.nodes,
      links: links,
    );
    await pumpApp(
      t,
      live: LiveState(snap: snap, me: fixtureMe, receivedAt: fixtureNow - 3000),
    );
    await t.pump(const Duration(seconds: 1));
    expect(find.text('J'), findsOneWidget);
    expect(find.text('N'), findsOneWidget);
  });
}
