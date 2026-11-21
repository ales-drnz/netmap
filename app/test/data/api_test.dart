import 'package:flutter_test/flutter_test.dart';
import 'package:netmap/data/api.dart';

import 'helpers.dart';

void main() {
  iconField();
  test('parses a real snapshot of the mock', () {
    final s = fixture();
    expect(s.networkName, 'home-net');
    expect(s.nodes, hasLength(13));
    final hub = s.nodes.singleWhere((n) => n.hub);
    expect(hub.name, 'nas');
    expect(hub.link, Link.hub);
    final pc = s.nodes.firstWhere((n) => n.name == 'alice-pc');
    expect(pc.ips, ['10.147.17.3']);
    expect(pc.lastSeen, isNotNull);
    expect(pc.spark, isNotEmpty);
    expect(pc.beats, hasLength(60));
    expect(pc.labels.first.name, 'always on');
    expect(pc.traffic?.days, hasLength(30));
    expect(s.pending.map((p) => p.name), containsAll(['guest-laptop', 'old-laptop']));
    expect(s.pending.firstWhere((p) => p.name == 'old-laptop').deauthorized, isTrue);
    expect(s.events, isNotEmpty);
    expect(s.events.any((e) => e.kind == EventKind.netdrop && e.count == 3), isTrue);
    expect(s.health?.zt?.version, '1.14.2');
    expect(s.health?.local?.routes, hasLength(2));
    expect(s.health?.bytes?.days, isNotEmpty);
    expect(s.net?.dns?.domain, 'home.zt');
    expect(s.links.map((l) => l.name), ['Jellyfin', 'Nextcloud']);
    expect(s.links.first.hours, hasLength(24));
  });

  test('is lenient: missing, null and mistyped fields never throw', () {
    final s = Snapshot.fromJson({
      'networkId': 'x',
      'nodes': [
        {
          'id': 'a',
          'name': 'a',
          'online': 'yes',
          'latencyMs': null,
          'spark': [1, null, 'x'],
          'lastSeen': 'not a date',
        },
        'garbage',
      ],
      'events': [
        {'t': 1, 'kind': 'future-kind'},
        {'t': 2, 'kind': 'online', 'name': 'a'},
      ],
      'health': {'zt': null, 'bytes': null},
    });
    expect(s.nodes, hasLength(1));
    final n = s.nodes.single;
    expect(n.online, isFalse);
    expect(n.latencyMs, isNull);
    expect(n.spark, [1.0, null, null]);
    expect(n.lastSeen, isNull);
    expect(s.events.single.kind, EventKind.online);
    expect(s.health?.zt, isNull);
  });

  test('lastSeen and updatedAt accept epoch ms or ISO strings', () {
    expect(epochMs(1700000000000), 1700000000000);
    expect(epochMs('2026-10-19T12:00:00Z'), DateTime.utc(2026, 10, 19, 12).millisecondsSinceEpoch);
    expect(epochMs(null), isNull);
  });

  test('public IP addresses are not part of the model', () {
    // the server strips them; the Dart model has no field that could hold them
    final s = fixture();
    for (final n in s.nodes) {
      for (final ip in n.ips) {
        expect(ip, startsWith('10.147.17.'));
      }
    }
  });
}

void iconField() {
  test('a service icon is a same-origin path, or nothing', () {
    expect(QuickLink.fromJson({'name': 'J', 'url': 'http://x', 'icon': '/api/services/0/icon?v=abc'}).icon, '/api/services/0/icon?v=abc');
    expect(QuickLink.fromJson({'name': 'J', 'url': 'http://x'}).icon, isNull);
  });
}
