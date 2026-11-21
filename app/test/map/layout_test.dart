import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:netmap/data/api.dart';
import 'package:netmap/data/model.dart';
import 'package:netmap/map/layout.dart';
import 'package:netmap/map/shapes.dart';

import '../data/helpers.dart';

/// a letters-only owner name (trailing digits would be ignored when grouping)
String who(int p) => p == 0 ? 'me' : String.fromCharCodes([for (var x = p; x > 0; x ~/= 26) 97 + x % 26]);

/// a network of [people] people with 1..7 devices each, in every state
List<Person> network(int people) {
  const types = ['pc', 'phone', 'laptop', 'tablet', 'tv', 'console', 'nas'];
  final devices = <Device>[];
  for (var p = 0; p < people; p++) {
    final n = p % 9 == 0 ? 7 : 1 + (p * 7) % 4;
    for (var d = 0; d < n; d++) {
      final k = (p + d) % 7;
      devices.add(
        toDevice(
          node(
            name: '${who(p)}x-${types[d]}',
            online: k != 5 && k != 6,
            relayed: k == 2,
            halfOpen: k == 3,
            link: k == 0 ? Link.lan : (k == 1 ? null : Link.wan),
            lastSeen: k == 6 ? now - 30 * 86400000 : now,
          ),
          now,
        ),
      );
    }
  }
  return groupPeople(devices, 'mex');
}

String meId(List<Person> people) => people.first.devices.first.id;

void main() {
  for (final narrow in [false, true]) {
    final where = narrow ? 'narrow' : 'wide';

    test('$where: each lane holds exactly its state\'s devices, in person order', () {
      final people = network(30);
      final l = layoutMap(people, meId: meId(people), narrow: narrow);
      final all = [for (final p in people) ...p.devices];
      expect(l.nodes, hasLength(all.length));
      var lastBottom = double.negativeInfinity;
      for (var rank = 0; rank <= 5; rank++) {
        final expected = [
          for (final d in all)
            if (stateRank(d) == rank) d.id,
        ];
        final lane = l.nodes.where((n) => stateRank(n.device) == rank).toList()..sort((a, b) => a.index.compareTo(b.index));
        expect([for (final n in lane) n.device.id], expected, reason: 'lane $rank');
        if (lane.isEmpty) continue;
        // lanes are stacked: none reaches into another
        final top = lane.map((n) => n.pos.dy).reduce((a, b) => a < b ? a : b);
        expect(top, greaterThan(lastBottom));
        lastBottom = lane.map((n) => n.pos.dy).reduce((a, b) => a > b ? a : b);
      }
    });

    test('$where: a person\'s devices sit together, on one row unless wider than a row', () {
      final people = network(40);
      final l = layoutMap(people, meId: meId(people), narrow: narrow);
      final cols = l.columns;
      final order = [for (final n in l.nodes) n.device.id];
      for (final p in people) {
        for (var rank = 0; rank <= 5; rank++) {
          final mine = [
            for (final n in l.nodes)
              if (n.device.owner == p.key && stateRank(n.device) == rank) n,
          ];
          if (mine.isEmpty) continue;
          // contiguous in reading order
          final at = [for (final n in mine) order.indexOf(n.device.id)]..sort();
          expect(at.last - at.first, mine.length - 1, reason: '${p.key} in lane $rank');
          final rows = mine.map((n) => n.pos.dy).toSet();
          if (mine.length <= cols) {
            expect(rows, hasLength(1), reason: '${p.key} broken across rows');
          } else {
            expect(rows, hasLength((mine.length / cols).ceil()));
          }
          if (mine.length >= 2) {
            expect(l.grouped.containsAll(mine.map((n) => n.device.id)), isTrue);
          } else {
            expect(l.grouped.contains(mine.single.device.id), isFalse);
          }
        }
      }
    });

    test('$where: nothing overlaps, even with 200 devices, and it is fast', () {
      final people = network(90);
      expect(people.expand((p) => p.devices).length, greaterThanOrEqualTo(200));
      final sw = Stopwatch()..start();
      final l = layoutMap(people, meId: meId(people), narrow: narrow);
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(500));

      final cells = [for (final n in l.nodes) nodeRect(n.pos)];
      for (var a = 0; a < cells.length; a++) {
        for (var b = a + 1; b < cells.length; b++) {
          expect(cells[a].overlaps(cells[b]), isFalse, reason: '${l.nodes[a].device.name} overlaps ${l.nodes[b].device.name}');
        }
      }
      final hub = Rect.fromCircle(center: Offset.zero, radius: MapLayout.hubRadius + 8);
      expect(cells.any((r) => r.overlaps(hub)), isFalse);
      // an owner's band holds exactly their devices' circles, and touches no
      // one else's circle or any name
      for (final s in l.shapes.whereType<GroupBand>()) {
        final r = s.rect;
        for (final n in l.nodes) {
          final circle = Rect.fromCircle(center: n.pos, radius: MapLayout.nodeRadius);
          final name = Rect.fromLTRB(
            n.pos.dx - nameW / 2,
            n.pos.dy + MapLayout.nodeRadius + 10,
            n.pos.dx + nameW / 2,
            n.pos.dy + MapLayout.nodeRadius + 26,
          );
          expect(name.overlaps(r), isFalse, reason: 'band over the name of ${n.device.name}');
          if (s.ids.contains(n.device.id) && (n.pos.dy - r.center.dy).abs() < 1) {
            expect(r.contains(circle.topLeft) && r.contains(circle.bottomRight), isTrue, reason: '${n.device.name} off its band');
          } else {
            expect(circle.overlaps(r), isFalse, reason: 'band under ${n.device.name}');
          }
        }
      }
      for (final n in l.nodes) {
        expect(l.bounds.contains(n.pos), isTrue);
      }
    });
  }

  test('your devices are labelled with the "you" word, others with their name', () {
    final people = network(12);
    final l = layoutMap(people, meId: meId(people));
    final owners = [for (final t in l.shapes.whereType<MapText>()) t.words].where((w) => w is! StateCount).toList();
    expect(owners.whereType<YouWord>(), isNotEmpty);
    expect(owners.whereType<Literal>().map((w) => w.text), isNot(contains('Mex')));
  });

  test('deterministic: the same network gives the same map', () {
    final a = layoutMap(network(30)), b = layoutMap(network(30));
    expect([for (final n in a.nodes) n.pos], [for (final n in b.nodes) n.pos]);
  });

  test('reading order goes top to bottom', () {
    final l = layoutMap(network(20));
    final ys = [for (final n in l.nodes) (n.pos.dy / 60).floor()];
    expect(ys, [...ys]..sort());
    expect([for (final n in l.nodes) n.index], List.generate(l.nodes.length, (i) => i));
  });
}
