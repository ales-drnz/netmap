// Paints the map: the hub, a line to each lane, the lanes' titles, the
// owners' brackets, devices, "you".
// One CustomPainter for the whole map keeps 200 devices smooth; each device
// still gets its own semantics node (label + tap), so screen readers can walk
// the map like a list.
import 'dart:math' as math;

import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/rendering.dart' show SemanticsProperties;
import 'package:material_ui/material_ui.dart';

import '../app/theme.dart';
import '../data/model.dart';
import '../widgets/link_glyph.dart';
import 'layout.dart';
import 'shapes.dart';

/// Everything the painter needs from the theme and the page, resolved once.
class MapStyle {
  MapStyle(BuildContext context)
    : colors = context.colors,
      links = context.links,
      text = context.type,
      looks = {for (final s in LinkState.values) s: linkLook(context, s)},
      lineColors = {for (final s in LinkState.values) s: linkColor(context, s)};
  final ColorScheme colors;
  final LinkColors links;
  final TextTheme text;
  final Map<LinkState, LinkLook> looks;
  final Map<LinkState, Color> lineColors;
}

class MapPainter extends CustomPainter {
  MapPainter({
    required this.layout,
    required this.style,
    required this.origin,
    required this.scale,
    required this.hubName,
    required this.youWord,
    required this.hubWord,
    required this.semanticLabel,
    this.rankWords = const [],
    this.meId,
    this.selectedId,
    this.focusVisible = false,
    this.onTapNode,
  });

  final MapLayout layout;
  final MapStyle style;

  /// world → canvas: canvas = world - origin
  final Offset origin;

  /// current zoom, for the level of detail
  final double scale;

  final String? hubName;
  final String youWord;
  final String hubWord;
  final String Function(MapNode) semanticLabel;

  /// the word of each state rank (see [stateRank]), for the lanes' titles
  final List<String> rankWords;
  final String? meId;
  final String? selectedId;
  final bool focusVisible;
  final void Function(MapNode)? onTapNode;

  bool get _labels => scale >= namesMinScale;
  bool get _icons => scale >= .38;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(-origin.dx, -origin.dy);
    final c = style.colors;

    // 1. under everything: the lines to the lanes, their titles and rules,
    // and each owner's name on a bracket over their devices
    for (final s in layout.shapes) {
      _shape(canvas, s);
    }

    // 2. the hub, its name on the first side free of lines
    _hub(canvas, [
      for (final s in layout.shapes)
        if (s is MapLine) ..._segments(s),
    ]);

    // 3. devices, each name under its circle
    for (final n in layout.nodes) {
      _node(canvas, n, halo: c.surface, underOwner: layout.grouped.contains(n.device.id));
    }
  }

  /// a line as straight pieces (a curve in 8)
  static Iterable<(Offset, Offset)> _segments(MapLine l) sync* {
    final c1 = l.c1, c2 = l.c2;
    if (c1 == null || c2 == null) {
      yield (l.a, l.b);
      return;
    }
    Offset at(double t) {
      final u = 1 - t;
      return l.a * (u * u * u) + c1 * (3 * u * u * t) + c2 * (3 * u * t * t) + l.b * (t * t * t);
    }

    for (var i = 0; i < 8; i++) {
      yield (at(i / 8), at((i + 1) / 8));
    }
  }

  Color _tone(Tone t) {
    final c = style.colors;
    return switch (t) {
      Tone.surface => c.surface,
      Tone.outline => c.outline,
      Tone.outlineVariant => c.outlineVariant,
      Tone.primary => c.primary,
      Tone.onSurfaceVariant => c.onSurfaceVariant,
      Tone.surfaceContainerHigh => c.surfaceContainerHigh,
      Tone.secondaryContainer => c.secondaryContainer,
    };
  }

  /// a width in screen px, as world units (it grows when zooming in)
  double _px(double w) => w / math.min(scale, 1);

  void _shape(Canvas canvas, MapShape s) {
    switch (s) {
      case MapDot(:final center, :final radius, :final state):
        canvas.drawCircle(center, radius, Paint()..color = style.lineColors[state]!);
      case MapLine(:final a, :final b, :final c1, :final c2, :final width, :final alpha, :final tone, :final state):
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = _px(width)
          ..color = (state != null ? style.lineColors[state]! : _tone(tone)).withValues(alpha: alpha);
        if (c1 == null || c2 == null) {
          canvas.drawLine(a, b, paint);
        } else {
          canvas.drawPath(
            Path()
              ..moveTo(a.dx, a.dy)
              ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, b.dx, b.dy),
            paint,
          );
        }
      case GroupBand(:final rect, :final fill):
        // fully rounded: a band the circles sit on, no outline
        canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)), Paint()..color = _tone(fill));
      case MapText(
        :final words,
        :final at,
        :final anchor,
        :final size,
        :final weight,
        :final tone,
        :final state,
        :final minScreen,
        :final minScale,
        :final maxWidth,
      ):
        if (scale < minScale) return;
        final text = switch (words) {
          Literal(:final text) => text,
          YouWord() => youWord,
          StateCount(:final rank, :final count) => '${rank < rankWords.length ? rankWords[rank] : ''} · $count',
        };
        final st = style.text.labelMedium!.copyWith(
          color: state != null ? style.lineColors[state] : _tone(tone),
          fontWeight: weight,
          fontSize: math.max(size, minScreen / scale),
        );
        final tp = _layout(text, st, maxWidth: maxWidth);
        final x = switch (anchor) {
          Anchor.center => at.dx - tp.width / 2,
          Anchor.left => at.dx,
          Anchor.right => at.dx - tp.width,
        };
        _text(canvas, text, Offset(x, at.dy - tp.height / 2), st, maxWidth: maxWidth, halo: style.colors.surface);
    }
  }

  /// whether the segment a–b touches [r]
  static bool _crosses(Offset a, Offset b, Rect r) {
    if (r.contains(a) || r.contains(b)) return true;
    double cross(Offset o, Offset x, Offset y) => (x.dx - o.dx) * (y.dy - o.dy) - (x.dy - o.dy) * (y.dx - o.dx);
    bool hit(Offset p, Offset q) {
      final d1 = cross(p, q, a), d2 = cross(p, q, b), d3 = cross(a, b, p), d4 = cross(a, b, q);
      return (d1 > 0) != (d2 > 0) && (d3 > 0) != (d4 > 0);
    }

    return hit(r.topLeft, r.topRight) || hit(r.topRight, r.bottomRight) || hit(r.bottomRight, r.bottomLeft) || hit(r.bottomLeft, r.topLeft);
  }

  void _hub(Canvas canvas, List<(Offset, Offset)> segments) {
    final c = style.colors;
    // neutral: the hub is infrastructure, not a state
    canvas.drawCircle(Offset.zero, MapLayout.hubRadius, Paint()..color = c.inverseSurface);
    _icon(canvas, Symbols.dns_rounded, Offset.zero, 40, c.onInverseSurface);
    final label = hubName ?? hubWord;
    final st = style.text.labelLarge!.copyWith(color: c.onSurface, fontWeight: FontWeight.w700, fontSize: (13 / scale).clamp(14.0, 40.0));
    final tp = _layout(label, st);
    // the first side (below, above, right, left) that no line crosses
    const g = MapLayout.hubRadius + 8;
    final candidates = [
      Offset(-tp.width / 2, g),
      Offset(-tp.width / 2, -g - tp.height),
      Offset(g, -tp.height / 2),
      Offset(-g - tp.width, -tp.height / 2),
    ];
    final at = candidates.firstWhere(
      (o) => !segments.any((seg) => _crosses(seg.$1, seg.$2, (o & Size(tp.width, tp.height)).inflate(2))),
      orElse: () => candidates.first,
    );
    _text(canvas, label, at, st, halo: c.surface);
  }

  void _node(Canvas canvas, MapNode n, {required Color halo, required bool underOwner}) {
    final d = n.device;
    final c = style.colors;
    final look = style.looks[d.state]!;
    // every device the same size: its lane, not only its colour, says
    // whether it is online
    const r = MapLayout.nodeRadius;
    canvas.save();
    canvas.translate(n.pos.dx, n.pos.dy);

    if (d.id == meId) {
      // you: a ring close around your device
      canvas.drawCircle(
        Offset.zero,
        r + 6,
        Paint()
          ..color = c.onSurface
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
    if (d.id == selectedId) {
      canvas.drawCircle(
        Offset.zero,
        r + (d.id == meId ? 12 : 8),
        Paint()
          ..color = c.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = focusVisible ? 4 : 3,
      );
    }

    // inactive (more than 7 days): always there, dimmed; the name stays legible
    canvas.drawCircle(Offset.zero, r, Paint()..color = d.active ? look.fill : look.fill.withValues(alpha: .45));

    if (_icons) _icon(canvas, deviceIcon(d.type), Offset.zero, 21, d.active ? look.on : look.on.withValues(alpha: .7));

    // relay and one-way get a small badge naming the state, the same size on
    // screen at any zoom (online and offline need none: their lane says it)
    if (_icons && (d.state == LinkState.relay || d.state == LinkState.oneWay)) {
      final br = math.min(10.0, 7 / scale);
      final b = Offset(r * .78, r * .78);
      canvas.drawCircle(b, br + 1.5, Paint()..color = halo);
      canvas.drawCircle(b, br, Paint()..color = look.stroke);
      _icon(canvas, linkIcon(d.state), b, br * 1.4, c.surface);
    }

    if (d.id == meId && !underOwner) {
      // "You", with no owner name above: a small tag on the circle's top-right
      final tp = _layout(youWord, style.text.labelSmall!.copyWith(color: c.onPrimary, fontWeight: FontWeight.w800));
      final w = tp.width + 12;
      final center = Offset(r * .8 + w / 2 - 6, -r * .8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: w + 3, height: 21), const Radius.circular(11)),
        Paint()..color = c.surface,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: w, height: 18), const Radius.circular(9)),
        Paint()..color = c.primary,
      );
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    }

    if (_labels) {
      final st = style.text.labelMedium!.copyWith(
        color: d.active ? c.onSurface : c.onSurfaceVariant,
        fontWeight: d.id == meId ? FontWeight.w800 : FontWeight.w500,
        fontSize: math.max(12, 11 / scale),
      );
      final tp = _layout(d.name, st, maxWidth: nameW);
      final at = Offset(-tp.width / 2, MapLayout.nodeRadius + 7);
      // a halo in the colour behind the name keeps it readable over any line
      final h = _layout(
        d.name,
        st.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..strokeJoin = StrokeJoin.round
            ..color = halo,
          color: null,
        ),
        maxWidth: nameW,
      );
      h.paint(canvas, at);
      tp.paint(canvas, at);
    }
    canvas.restore();
  }

  void _icon(Canvas canvas, IconData icon, Offset center, double size, Color color) {
    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: size,
          color: color,
          height: 1,
          fontVariations: const [FontVariation('FILL', 1), FontVariation('wght', 500)],
        ),
      ),
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  TextPainter _layout(String s, TextStyle st, {double maxWidth = double.infinity}) => TextPainter(
    text: TextSpan(text: s, style: st),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: maxWidth);

  void _text(Canvas canvas, String s, Offset at, TextStyle st, {bool center = false, double maxWidth = 400, Color? halo}) {
    if (halo != null) {
      final h = _layout(
        s,
        st.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..color = halo,
          color: null,
        ),
        maxWidth: maxWidth,
      );
      h.paint(canvas, at - Offset(center ? h.width / 2 : 0, 0));
    }
    final tp = _layout(s, st, maxWidth: maxWidth);
    tp.paint(canvas, at - Offset(center ? tp.width / 2 : 0, 0));
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder =>
      (size) => [
        for (final n in layout.nodes)
          CustomPainterSemantics(
            key: ValueKey(n.device.id),
            // at least 48 dp on screen whatever the zoom (24 dp radius)
            rect: Rect.fromCircle(center: n.pos - origin, radius: math.max(30, 24 / scale)),
            properties: SemanticsProperties(
              label: semanticLabel(n),
              button: true,
              selected: n.device.id == selectedId,
              textDirection: TextDirection.ltr,
              onTap: onTapNode == null ? null : () => onTapNode!(n),
            ),
          ),
      ];

  @override
  bool shouldRebuildSemantics(MapPainter oldDelegate) =>
      oldDelegate.layout != layout || oldDelegate.selectedId != selectedId || oldDelegate.origin != origin;

  @override
  bool shouldRepaint(MapPainter oldDelegate) {
    final old = oldDelegate;
    return old.layout != layout ||
        old.selectedId != selectedId ||
        old.focusVisible != focusVisible ||
        old.meId != meId ||
        old._labels != _labels ||
        old._icons != _icons ||
        old.scale != scale ||
        old.style.colors != style.colors;
  }
}
