// Pumps the whole app with fixed data and a fixed clock: no timers, no
// network, the same picture every time (widget and golden tests).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:netmap/app/settings.dart';
import 'package:netmap/data/api.dart';
import 'package:netmap/data/live.dart';
import 'package:netmap/app/router.dart';
import 'package:netmap/main.dart';

final Snapshot fixtureSnapshot = Snapshot.fromJson(jsonDecode(File('test/fixtures/snapshot.json').readAsStringSync()) as Json);
final WhoAmI fixtureMe = WhoAmI.fromJson(jsonDecode(File('test/fixtures/whoami.json').readAsStringSync()) as Json);

/// "now" in tests: 5 seconds after the fixture was taken
final int fixtureNow = fixtureSnapshot.updatedAt! + 5000;

class FakeLive extends LiveController {
  FakeLive(this.initial);
  final LiveState initial;
  @override
  LiveState build() => initial;
}

class FixedClock extends Clock {
  @override
  int build() => fixtureNow;
}

class FixedTheme extends ThemeModeNotifier {
  FixedTheme(this.mode);
  final ThemeMode mode;
  @override
  ThemeMode build() => mode;
}

class FixedLocale extends LocaleNotifier {
  FixedLocale(this.locale);
  final Locale locale;
  @override
  Locale? build() => locale;
}

Future<void> pumpApp(
  WidgetTester t, {
  Size size = const Size(1280, 800),
  Locale locale = const Locale('it'),
  ThemeMode theme = ThemeMode.light,
  LiveState? live,
  String location = '/',
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        liveProvider.overrideWith(() => FakeLive(live ?? LiveState(snap: fixtureSnapshot, me: fixtureMe, receivedAt: fixtureNow - 3000))),
        clockProvider.overrideWith(FixedClock.new),
        themeModeProvider.overrideWith(() => FixedTheme(theme)),
        localeProvider.overrideWith(() => FixedLocale(locale)),
      ],
      child: NetmapApp(router: buildRouter(initialLocation: location)),
    ),
  );
  await t.pump(const Duration(milliseconds: 600));
}

/// A big network: the mock's members plus [extra] generated people with 1–4
/// devices each, in every state (for the 200-device checks).
Snapshot bigSnapshot({int extra = 60}) {
  const types = ['pc', 'phone', 'laptop', 'tablet', 'tv'];
  String who(int p) => String.fromCharCodes([for (var x = p + 1; x > 0; x ~/= 26) 97 + x % 26]);
  final nodes = [...fixtureSnapshot.nodes];
  var ip = 20;
  for (var p = 0; p < extra; p++) {
    final n = 1 + (p * 7) % 4;
    for (var d = 0; d < n; d++) {
      final k = (p + d) % 9;
      nodes.add(
        NetNode(
          id: 'g${p}_$d',
          name: '${who(p)}x-${types[(p + d) % types.length]}',
          ips: ['10.147.${18 + ip ~/ 250}.${ip++ % 250 + 1}'],
          online: k != 0 && k != 5,
          relayed: k == 3,
          halfOpen: k == 7,
          link: k == 1 || k == 4 ? Link.lan : (k == 3 ? Link.relay : Link.wan),
          latencyMs: 20.0 + k * 9,
          spark: [for (var i = 0; i < 30; i++) 20.0 + k * 9 + (i % 5)],
          uptime: k == 0 ? .4 : .98,
          lastSeen: fixtureNow - (k == 5 ? 20 : 1) * 86400000 ~/ (k == 0 ? 10 : 1),
        ),
      );
    }
  }
  return Snapshot(
    updatedAt: fixtureSnapshot.updatedAt,
    networkId: fixtureSnapshot.networkId,
    networkName: fixtureSnapshot.networkName,
    pollSeconds: 20,
    nodes: nodes,
    events: fixtureSnapshot.events,
    links: fixtureSnapshot.links,
    pending: fixtureSnapshot.pending,
    health: fixtureSnapshot.health,
  );
}

/// A network shaped like a real deployment seen in production (names, boxes
/// and states from it): 43 members, 18 online, 16 inactive, a hub called
/// CONTROLLER, and NO data from the local ZeroTier service (no latency, no
/// link type, no versions), as when its token cannot be read.
Snapshot realSnapshot() {
  final now = fixtureNow;
  const day = 86400000;
  const online = [
    'fazen-laptop',
    'fazen-pc-3',
    'mevem-pc',
    'soda-pc',
    'mattel-pc',
    'cynro-pc',
    'frost-laptop',
    'jek-pc',
    'jan-pc',
    'toasty-pc',
    'kitzu-pc',
    'daniplant-pc',
    'kira-laptop',
    'raffa-pc',
    'fb-pc',
    'neksu-pc',
    'neksu-pc-2',
    'skaino-pc',
  ];
  const recent = ['fazen-pc', 'elias-pc', 'sick-pc', 'raffa-laptop', 'fb-console', 'skaino-laptop', 'otzell-pc', 'silly-pc', 'mich-laptop'];
  const inactive = [
    'fazen-console',
    'fazen-pc-2',
    'fazen-phone',
    'fazen-tablet',
    'artur-laptop',
    'riven-pc',
    'cyther-pc',
    'fuleio-console',
    'fubo-pc',
    'delay-pc',
    'patrick-pc',
    'danny-pc',
    'silvy-pc',
    'phabio-pc',
    'sick-pc-2',
    'sick-phone',
  ];
  var ip = 10;
  NetNode member(String name, {required bool on, required int seen}) => NetNode(
    id: name.hashCode.toUnsigned(40).toRadixString(16).padLeft(10, '0'),
    name: name,
    ips: ['10.121.15.${ip++}'],
    online: on,
    lastSeen: seen,
    uptime: on ? .9 : null,
  );
  return Snapshot(
    updatedAt: now - 5000,
    networkId: '938a694077eb807d',
    networkName: 'NAS-Fazen',
    pollSeconds: 20,
    nodes: [
      NetNode(id: 'c0ffee0001', name: 'CONTROLLER', ips: const ['10.121.15.1'], online: true, hub: true, lastSeen: now),
      for (final n in online) member(n, on: true, seen: now),
      for (final (i, n) in recent.indexed) member(n, on: false, seen: now - (i + 1) * day ~/ 2),
      for (final (i, n) in inactive.indexed) member(n, on: false, seen: now - (10 + i * 5) * day),
    ],
    links: const [
      QuickLink(name: 'Jellyfin', url: 'http://10.121.15.1:8096', up: true, ms: 0),
      QuickLink(name: 'MineSync', url: 'http://10.121.15.1:8080', up: true, ms: 0),
    ],
  );
}

/// [realSnapshot] as seen from fazen-pc-3
LiveState realLive() {
  final s = realSnapshot();
  final me = s.nodes.firstWhere((n) => n.name == 'fazen-pc-3');
  return LiveState(
    snap: s,
    me: WhoAmI(ip: me.ips.first, name: me.name, id: me.id),
    receivedAt: fixtureNow - 3000,
  );
}
