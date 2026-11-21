// Where everything goes on the map. Pure and deterministic: the same people
// always land in the same places, so a live update never reshuffles the map,
// and it can be unit tested.
//
// The map is a set of lanes, one per state (direct, online, relay, no reply,
// offline, inactive), stacked beside the hub (below it on phones) and each
// joined to it by a line in the state's colour. In a lane each person's
// devices sit together, in person order ("you" first): a little space around
// every person, and over two or more devices their owner's name on a thin
// bracket. A person's devices never break across rows unless they alone are
// wider than a row.
import 'dart:math' as math;
import 'dart:ui';

import '../data/model.dart';
import 'shapes.dart';

/// a device on the map
class MapNode {
  const MapNode(this.device, this.pos, {required this.index});
  final Device device;

  /// world coordinates (hub at 0,0)
  final Offset pos;

  /// reading order (used for keyboard navigation)
  final int index;
}

class MapLayout {
  const MapLayout({required this.nodes, required this.bounds, this.shapes = const [], this.grouped = const {}, this.columns = 0});
  final List<MapNode> nodes;

  /// drawn under the devices, in order: lines, titles, owners
  final List<MapShape> shapes;

  /// devices under their owner's name: "you" needs no tag there
  final Set<String> grouped;

  /// the most devices in a row of a lane
  final int columns;

  /// everything, hub included, with a margin
  final Rect bounds;

  static const double hubRadius = 48;
  static const double nodeRadius = 22;

  static const MapLayout empty = MapLayout(nodes: [], bounds: Rect.fromLTRB(-200, -200, 200, 200));

  MapNode? byId(String id) => nodes.where((n) => n.device.id == id).firstOrNull;
}

/// distance between two devices side by side; a name gets [nameW] of it
const double pitch = 128;
const double nameW = pitch - 12;

/// extra space between two people's devices in a row (less on phones,
/// where every px of width makes the names bigger)
const double groupGap = 28;
const double _groupGapNarrow = 20;

/// distance between two rows (room for the names under the circles and the
/// owners' names above the next row)
const double rowPitch = 104;

/// wide screens: where the lanes start, right of the hub
const double _x0 = 140;

/// phones: the lanes start right of the line down from the hub
const double _busX = 24;
const double _laneGap = 40;

/// from a lane's top: its title, its rule, its first row of devices
const double _titleY = 14;
const double _ruleY = 28;
const double _firstRow = 90;

/// below the last row: the names under the circles
const double _below = 50;

/// the band under a group's circles reaches this far above and below their
/// centres; the owner's name sits just above it
const double _bandHalf = MapLayout.nodeRadius + 6;
const double _ownerUp = _bandHalf + 13;

/// the zoom below which names (devices and owners) are hidden
const double namesMinScale = .55;

/// One person's devices in one lane.
class _Group {
  _Group(this.person, this.devices);
  final Person person;
  final List<Device> devices;
}

/// a run of a group's devices on one row
typedef _Segment = ({_Group group, int row, double left, double right, bool first});

/// [narrow]: the map's free area is taller than wide (phones): the lanes go
/// below the hub, three devices wide. Otherwise they go beside it, as many
/// devices wide (6 to 16) as make the map biggest in a free area [aspect]
/// times as wide as tall.
MapLayout layoutMap(List<Person> people, {String? meId, bool narrow = false, double aspect = 1.6}) {
  if (people.isEmpty) return MapLayout.empty;
  final me = people.first.devices.any((d) => d.id == meId) ? people.first : null;

  // each lane: one group per person, in person order, devices by name
  final lanes = <int, List<_Group>>{};
  for (final p in people) {
    final byRank = <int, List<Device>>{};
    for (final d in p.devices) {
      byRank.putIfAbsent(stateRank(d), () => []).add(d);
    }
    for (final e in byRank.entries) {
      lanes.putIfAbsent(e.key, () => []).add(_Group(p, e.value..sort((a, b) => a.name.compareTo(b.name))));
    }
  }
  final ranks = lanes.keys.toList()..sort();
  final gap = narrow ? _groupGapNarrow : groupGap;
  double laneH(_Flow f) => _firstRow + (f.rows - 1) * rowPitch + _below;
  Map<int, _Flow> flowsFor(int cols) => {for (final r in ranks) r: _flow(lanes[r]!, cols, gap)};
  double heightOf(Map<int, _Flow> fs) => ranks.fold(0.0, (a, r) => a + laneH(fs[r]!)) + _laneGap * (ranks.length - 1);

  var cols = 3;
  var flows = flowsFor(cols);
  if (!narrow) {
    // the widest rows that still make the whole map biggest on screen
    var best = 0.0;
    for (var c = 6; c <= 16; c++) {
      final fs = flowsFor(c);
      final w = (MapLayout.hubRadius + 110) + _x0 + fs.values.fold(0.0, (a, f) => math.max(a, f.width)) + 80;
      final h = math.max(heightOf(fs), 2 * (MapLayout.hubRadius + 34)) + 80;
      final fit = math.min(aspect / w, 1 / h);
      if (fit > best * 1.0001) {
        best = fit;
        cols = c;
        flows = fs;
      }
    }
  }
  final height = heightOf(flows);

  // wide: lanes to the right of the hub, centred on it; narrow: below it
  final left = narrow ? _busX : _x0;
  var top = narrow ? MapLayout.hubRadius + 40 : -height / 2;

  final nodes = <MapNode>[];
  final connectors = <MapShape>[], lines = <MapShape>[], bands = <MapShape>[], labels = <MapShape>[];
  final grouped = <String>{};
  for (final rank in ranks) {
    final flow = flows[rank]!;
    final laneHeight = laneH(flow);
    final state = rankState(rank);
    final count = lanes[rank]!.fold(0, (a, g) => a + g.devices.length);
    final titleY = top + _titleY;
    double rowY(int row) => top + _firstRow + row * rowPitch;

    labels.add(MapDot(Offset(left + 5, titleY), 5, state));
    labels.add(MapText(StateCount(rank, count), Offset(left + 16, titleY), anchor: Anchor.left, size: 13, state: state, minScreen: 11));
    lines.add(MapLine(Offset(left, top + _ruleY), Offset(left + flow.width, top + _ruleY), width: 1, alpha: .8));

    // to the lane's title: a smooth line from the hub
    final end = Offset(left - 10, titleY);
    if (narrow) {
      // straight down from the hub, then a bend into the title; the longer
      // lines go first, so each lane's colour shows down to its bend
      const a = Offset(0, MapLayout.hubRadius + 4);
      final bend = Offset(0, end.dy - 24);
      connectors.insertAll(0, [
        MapLine(a, bend, width: 2, state: state, alpha: .9),
        MapLine(bend, end, c1: Offset(0, end.dy), c2: Offset(0, end.dy), width: 2, state: state, alpha: .9),
      ]);
    } else {
      final a = Offset.fromDirection(math.atan2(end.dy, end.dx).clamp(-.7, .7), MapLayout.hubRadius + 4);
      final mx = (a.dx + end.dx) / 2;
      connectors.add(MapLine(a, end, c1: Offset(mx, a.dy), c2: Offset(mx, end.dy), width: 2, state: state, alpha: .9));
    }

    for (final (d, row, x) in flow.places) {
      nodes.add(MapNode(d, Offset(left + x, rowY(row)), index: 0));
    }
    // two or more devices of one person: they sit on a shared band, their
    // owner's name just above it (yours tinted, and called "you")
    for (final s in flow.segments) {
      final mine = s.group.person == me;
      grouped.addAll(s.group.devices.map((d) => d.id));
      final y = rowY(s.row);
      bands.add(
        GroupBand(
          left + s.left,
          left + s.right,
          y,
          height: 2 * _bandHalf,
          ids: {for (final d in s.group.devices) d.id},
          fill: mine ? Tone.secondaryContainer : Tone.surfaceContainerHigh,
        ),
      );
      if (s.first) {
        labels.add(
          MapText(
            mine ? const YouWord() : Literal(s.group.person.label),
            Offset(left + s.left + 2, y - _ownerUp),
            anchor: Anchor.left,
            size: 12,
            tone: mine ? Tone.primary : Tone.onSurfaceVariant,
            minScreen: 11,
            minScale: namesMinScale,
            maxWidth: s.right - s.left - 4,
          ),
        );
      }
    }
    top += laneHeight + _laneGap;
  }
  return _finish(nodes, [...connectors, ...lines, ...bands, ...labels], grouped, columns: cols, narrow: narrow);
}

/// A lane's groups in rows of at most [cols] devices: a group goes on the
/// next row when it does not fit what is left of this one, and breaks only
/// when it alone is wider than a row (then from the start of a new row).
typedef _Flow = ({List<(Device, int, double)> places, List<_Segment> segments, int rows, double width});

_Flow _flow(List<_Group> groups, int cols, double gap) {
  final places = <(Device, int, double)>[];
  final segments = <_Segment>[];
  var row = 0, used = 0;
  var x = 0.0, width = 0.0;
  for (final g in groups) {
    final n = g.devices.length;
    if (used > 0 && (used + n > cols || n > cols)) {
      row++;
      used = 0;
      x = 0;
    }
    var segStart = x;
    var first = true;
    for (final (k, d) in g.devices.indexed) {
      if (used == cols) {
        if (n > 1) segments.add((group: g, row: row, left: segStart + 4, right: x - 4, first: first));
        first = false;
        row++;
        used = 0;
        x = 0;
        segStart = 0;
      }
      places.add((d, row, x + pitch / 2));
      x += pitch;
      used++;
      width = math.max(width, x);
      if (k == n - 1 && n > 1) segments.add((group: g, row: row, left: segStart + 4, right: x - 4, first: first));
    }
    x += gap;
  }
  return (places: places, segments: segments, rows: row + 1, width: width);
}

/// the painted area of a device: its circle and its name underneath
Rect nodeRect(Offset p) =>
    Rect.fromLTRB(p.dx - nameW / 2, p.dy - MapLayout.nodeRadius - 6, p.dx + nameW / 2, p.dy + MapLayout.nodeRadius + 26);

/// Reading order (top to bottom, left to right, rows of 60 px) and bounds
/// around everything with a margin.
MapLayout _finish(List<MapNode> nodes, List<MapShape> shapes, Set<String> grouped, {required int columns, required bool narrow}) {
  final ordered = [...nodes]
    ..sort((a, b) {
      final ra = (a.pos.dy / 60).floor(), rb = (b.pos.dy / 60).floor();
      return ra != rb ? ra.compareTo(rb) : a.pos.dx.compareTo(b.pos.dx);
    });
  // the hub, and its name on whichever side it ends up (on phones: above
  // it, the line down to the lanes takes the side below)
  final hubW = narrow ? MapLayout.hubRadius + 8 : MapLayout.hubRadius + 110;
  var bounds = Rect.fromCenter(center: Offset.zero, width: 2 * hubW, height: 2 * (MapLayout.hubRadius + 34));
  for (final n in ordered) {
    bounds = bounds.expandToInclude(nodeRect(n.pos));
  }
  for (final s in shapes) {
    final r = switch (s) {
      MapLine(:final a, :final b) => Rect.fromPoints(a, b),
      MapDot(:final center, :final radius) => Rect.fromCircle(center: center, radius: radius),
      GroupBand(:final rect) => rect,
      // a rough width: the painter measures the real text
      MapText(:final at, :final size, :final maxWidth) => Rect.fromLTWH(at.dx, at.dy - size, math.min(maxWidth, 14 * size * .6), size * 2),
    };
    bounds = bounds.expandToInclude(r);
  }
  return MapLayout(
    nodes: [for (final (i, n) in ordered.indexed) MapNode(n.device, n.pos, index: i)],
    shapes: shapes,
    grouped: grouped,
    columns: columns,
    // a margin (thinner on phones, where the width sets the zoom)
    bounds: bounds.inflate(narrow ? 16 : 40),
  );
}
