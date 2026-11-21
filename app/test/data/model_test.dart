import 'package:flutter_test/flutter_test.dart';
import 'package:netmap/data/api.dart';
import 'package:netmap/data/model.dart';
import 'package:netmap/data/naming.dart';

import 'helpers.dart';

void main() {
  versionTests();
  test('link state: one-way beats relay, relay beats direct', () {
    expect(linkStateOf(node(online: false)), LinkState.offline);
    expect(linkStateOf(node(halfOpen: true, relayed: true)), LinkState.oneWay);
    expect(linkStateOf(node(relayed: true, link: Link.relay)), LinkState.relay);
    expect(linkStateOf(node(link: Link.lan)), LinkState.atHome);
    expect(linkStateOf(node(link: Link.wan)), LinkState.internet);
    // no path information (the hub's local ZeroTier service can't be read):
    // online, and never claimed to be direct
    expect(linkStateOf(node(link: null)), LinkState.online);
  });

  test('a device shows latency only when online and direct', () {
    final d = toDevice(node(spark: [10, 30, 20], latencyMs: 99), now);
    expect(d.median, 20);
    expect(d.ms, 99);
    expect(toDevice(node(relayed: true), now).median, isNull);
    expect(toDevice(node(online: false), now).median, isNull);
  });

  test('the hub without a recognisable name is a server, other unknowns a PC', () {
    expect(toDevice(node(name: 'gateway', hub: true), now).type, DeviceType.server);
    expect(toDevice(node(name: 'mystery'), now).type, DeviceType.pc);
    expect(toDevice(node(name: 'mystery'), now).owner, 'mystery');
  });

  test('people: you first, then by number of devices, then by name', () {
    final devices = [
      for (final n in ['zed-pc', 'bob-pc', 'bob-phone', 'carol-pc', 'carol-tv', 'carol-phone', 'amy-pc']) toDevice(node(name: n), now),
    ];
    expect(groupPeople(devices, 'zed').map((p) => p.key), ['zed', 'carol', 'bob', 'amy']);
    expect(groupPeople(devices, null).first.key, 'carol');
    final bob = groupPeople(devices, null).firstWhere((p) => p.key == 'bob');
    expect(bob.devices.map((d) => d.name), ['bob-pc', 'bob-phone']);
  });

  test('events by day, newest first', () {
    final d1 = DateTime(2026, 10, 19, 10).millisecondsSinceEpoch;
    final d1b = DateTime(2026, 10, 19, 8).millisecondsSinceEpoch;
    final d0 = DateTime(2026, 10, 18, 23).millisecondsSinceEpoch;
    final days = eventsByDay([
      NetEvent(t: d0, kind: EventKind.online),
      NetEvent(t: d1b, kind: EventKind.offline),
      NetEvent(t: d1, kind: EventKind.spike),
    ]);
    expect(days.map((d) => d.$1.day), [19, 18]);
    expect(days.first.$2.map((e) => e.kind), [EventKind.spike, EventKind.offline]);
    expect(filterOf(EventKind.netdrop), EventFilter.off);
  });
}

void versionTests() {
  test('versions compare as numbers, and the newest is found', () {
    expect(compareVersions('1.14.2', '1.9.10'), greaterThan(0));
    expect(compareVersions('1.12', '1.12.0'), 0);
    expect(compareVersions(null, '1.0'), lessThan(0));
    expect(newestVersion(fixture().nodes), '1.14.2');
    expect(versionsInUse(fixture().nodes).first.$1, '1.14.2');
  });
}
