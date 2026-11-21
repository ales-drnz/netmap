import 'package:flutter_test/flutter_test.dart';
import 'package:netmap/data/api.dart';
import 'package:netmap/data/stats.dart';
import 'package:netmap/data/status.dart';

import 'helpers.dart';

Verdict v(Snapshot? s, {int? receivedAt, bool offline = false}) =>
    verdict(snap: s, receivedAt: receivedAt ?? now - 2000, now: now, offline: offline);

void main() {
  group('verdict', () {
    test('is loading before the first snapshot', () {
      expect(v(null, receivedAt: 0).reason, isA<Loading>());
      expect(v(null, receivedAt: 0, offline: true).tone, Tone.danger);
    });

    test('is ok when nothing is wrong', () {
      final r = v(snap());
      expect(r.tone, Tone.ok);
      expect(r.counts.online, 2);
      expect(r.counts.direct, 2);
      expect(r.counts.atHome, 1);
      expect(r.counts.internet, 1);
      expect(r.counts.relay, 0);
      expect(r.ageSec, 2);
    });

    test('follows the priority order', () {
      final relayNodes = [node(relayed: true, link: Link.relay)];
      expect((v(snap(nodes: relayNodes)).reason as Relayed).count, 1);

      const fallback = Health(zt: ZtStatus(online: true, tcpFallback: true, allowTcpFallback: true, portMapping: true));
      expect(v(snap(nodes: relayNodes, health: fallback)).reason, isA<TcpFallback>());

      final drop = NetEvent(t: now - 600000, kind: EventKind.netdrop, count: 3);
      final r = v(snap(nodes: relayNodes, health: fallback, events: [drop])).reason as NetDrop;
      expect(r.count, 3);
      expect(r.t, now - 600000);
      // an old netdrop does not count
      final old = NetEvent(t: now - 2 * hourMs, kind: EventKind.netdrop, count: 3);
      expect(v(snap(nodes: relayNodes, health: fallback, events: [old])).reason, isA<TcpFallback>());

      final ztnet = v(snap(health: fallback, events: [drop], error: 'ECONNREFUSED', updatedAt: now - 180000));
      expect(ztnet.tone, Tone.danger);
      final st = ztnet.reason as Stale;
      expect(st.ztnet, isTrue);
      expect(st.ageSec, 180);
      expect(st.error, 'ECONNREFUSED');

      expect(v(snap(), offline: true).reason, isA<Stale>());
      final late = v(snap(), receivedAt: now - 120000).reason as Stale;
      expect(late.ztnet, isFalse);
      expect(late.ageSec, 120);
    });

    test('keeps inactive devices out of the counts', () {
      final r = v(
        snap(
          nodes: [
            node(),
            node(name: 'b', online: false, lastSeen: now - 3 * dayMs),
            node(name: 'c', online: false, lastSeen: now - 30 * dayMs),
            NetNode(id: 'd', name: 'd'),
          ],
        ),
      );
      expect(r.counts.active, 2);
      expect(r.counts.online, 1);
      expect(r.counts.offline, 1);
      expect(r.counts.inactive, 2);
    });

    test('a device with no path information is online, not direct', () {
      final r = v(
        snap(
          nodes: [
            node(link: null),
            node(name: 'b'),
          ],
        ),
      );
      expect(r.counts.online, 2);
      expect(r.counts.unknown, 1);
      expect(r.counts.direct, 1);
      expect(r.counts.internet, 1);
    });

    test('one-way devices still count as direct, and are counted on their own', () {
      final r = v(
        snap(
          nodes: [
            node(halfOpen: true),
            node(name: 'b'),
          ],
        ),
      );
      expect(r.counts.direct, 2);
      expect(r.counts.oneWay, 1);
    });
  });

  group('stats', () {
    test('typical latency is the median of per-device medians', () {
      final nodes = [
        node(name: 'a', spark: [1, 1, 100]), // median 1
        node(name: 'b', spark: [null, 20, 20]), // median 20
        node(name: 'c', spark: [50, 50, 50]), // median 50
        node(name: 'd', spark: [500], relayed: true), // relayed: excluded
        node(name: 'e', spark: [500], hub: true), // hub: excluded
      ];
      expect(typicalLatency(nodes), 20);
      expect(typicalLatency(const []), isNull);
    });

    test('availability averages the devices active in the window, not only the online ones', () {
      final nodes = [
        node(name: 'a', uptime: 1),
        node(name: 'b', online: false, uptime: .5, lastSeen: now - hourMs),
        node(name: 'c', online: false, uptime: 0, lastSeen: now - 5 * dayMs),
      ];
      expect(availability(nodes, now), .75);
      expect(availability([node(uptime: null)], now), isNull);
    });

    test('active = online or seen within 7 days', () {
      expect(isActive(node(online: false, lastSeen: now - 6 * dayMs), now), isTrue);
      expect(isActive(node(online: false, lastSeen: now - 8 * dayMs), now), isFalse);
    });

    test('quantiles and steps', () {
      expect(quantile([1, 2, 3, 4], .95), 4);
      expect(median([3, 1, 2]), 2);
      expect(seqStep(null), -1);
      expect(seqStep(0), 0);
      expect(seqStep(.995), 5);
      expect(seqStep(.95), 4);
      expect(seqStep(.1), 1);
    });
  });
}
