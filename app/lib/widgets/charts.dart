// Small charts, drawn by hand: no charting library to download or bundle.
// Each one has a spoken summary (Semantics label), and empty slots stay empty:
// the page never draws data it does not have.
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../app/theme.dart';
import '../data/model.dart';
import '../data/stats.dart';
import '../l10n/app_localizations.dart';
import '../widgets/shape.dart';
import 'link_glyph.dart';

/// The last 24 hours in 60 cells of 24 minutes, oldest first: the darker the
/// cell, the more the device was online; a full grey cell = offline the whole
/// slot; a low tick = no data. With [ends], "24 h ago" and "now" underneath.
class AvailabilityStrip extends StatelessWidget {
  const AvailabilityStrip({super.key, required this.beats, this.height = 16, required this.semanticLabel, this.ends = true});
  final List<double?> beats;
  final double height;
  final String semanticLabel;
  final bool ends;

  @override
  Widget build(BuildContext context) {
    final strip = Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _Strip(beats, [for (var s = -1; s <= 5; s++) availabilityColor(context, s)])),
      ),
    );
    if (!ends) return strip;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [strip, const SizedBox(height: 4), const AvailabilityEnds()]);
  }
}

/// "24 h ago" … "now", under an [AvailabilityStrip].
class AvailabilityEnds extends StatelessWidget {
  const AvailabilityEnds({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final style = context.type.labelSmall?.copyWith(color: context.colors.onSurfaceVariant);
    return ExcludeSemantics(
      child: Row(
        children: [
          Text(l.availAgo24, style: style),
          const Spacer(),
          Text(l.availNow, style: style),
        ],
      ),
    );
  }
}

class _Strip extends CustomPainter {
  _Strip(this.beats, this.steps);
  final List<double?> beats;

  /// colours of the steps -1..5
  final List<Color> steps;

  @override
  void paint(Canvas canvas, Size size) {
    const n = 60, gap = 1.0;
    final w = (size.width - gap * (n - 1)) / n;
    for (var i = 0; i < n; i++) {
      final step = seqStep(i < beats.length ? beats[i] : null);
      final x = i * (w + gap);
      // no data: a low tick on the baseline
      final r = step == -1 ? Rect.fromLTWH(x, size.height - 4, w, 4) : Rect.fromLTWH(x, 0, w, size.height);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(rMark)), Paint()..color = steps[step + 1]);
    }
  }

  @override
  bool shouldRepaint(_Strip o) => o.beats != beats || o.steps[6] != steps[6];
}

/// Latency samples as a line (gaps where there was no direct latency), with
/// the median and, if known, the previous week's median as reference lines.
class LatencyLine extends StatelessWidget {
  const LatencyLine({super.key, required this.samples, this.median, this.previous, this.height = 120, required this.semanticLabel});
  final List<double?> samples;
  final double? median;
  final double? previous;
  final double height;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    child: SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _Line(
          samples,
          median,
          previous,
          L.of(context),
          context.colors.primary,
          context.colors.outline,
          context.colors.tertiary,
          context.type.bodySmall!.copyWith(color: context.colors.onSurfaceVariant),
        ),
      ),
    ),
  );
}

class _Line extends CustomPainter {
  _Line(this.xs, this.median, this.prev, this.l, this.color, this.grid, this.prevColor, this.label);
  final List<double?> xs;
  final double? median, prev;
  final L l;
  final Color color, grid, prevColor;
  final TextStyle label;

  @override
  void paint(Canvas canvas, Size size) {
    final vals = xs.whereType<double>().toList();
    if (vals.isEmpty) return;
    final hi = [...vals, ?prev].reduce(math.max) * 1.15;
    TextPainter text(String t) => TextPainter(
      text: TextSpan(text: t, style: label),
      textDirection: TextDirection.ltr,
    )..layout();
    final refs = [
      if (prev != null) (prev!, prevColor, text(l.chartPrevWeek(prev!.round()))),
      if (median != null) (median!, grid, text(l.chartMedian(median!.round()))),
    ];
    // the reference labels sit at the right of the plot, as wide as they need
    final right = refs.isEmpty ? 0.0 : refs.map((r) => r.$3.width).reduce(math.max) + 8;
    const left = 0.0;
    final w = size.width - right - left;
    double y(double v) => size.height - 4 - (v / hi) * (size.height - 8);
    double x(int i) => left + (xs.length == 1 ? w / 2 : i * w / (xs.length - 1));

    // label centres, pushed apart when the two lines are close
    final at = [for (final r in refs) y(r.$1)];
    if (at.length == 2 && (at[0] - at[1]).abs() < refs[0].$3.height) {
      final mid = (at[0] + at[1]) / 2, half = refs[0].$3.height / 2;
      final prevBelow = refs[0].$1 < refs[1].$1;
      at[0] = mid + (prevBelow ? half : -half);
      at[1] = mid + (prevBelow ? -half : half);
    }

    void ref(double v, Color c, TextPainter tp, double labelY) {
      final p = Paint()
        ..color = c
        ..strokeWidth = 1.2;
      canvas.drawPath(
        dashPath(
          Path()
            ..moveTo(left, y(v))
            ..lineTo(left + w, y(v)),
          4,
          4,
        ),
        p..style = PaintingStyle.stroke,
      );
      tp.paint(canvas, Offset(left + w + 6, (labelY - tp.height / 2).clamp(0, size.height - tp.height)));
    }

    for (final (i, (v, c, tp)) in refs.indexed) {
      ref(v, c, tp, at[i]);
    }

    final line = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    Path? path;
    for (var i = 0; i < xs.length; i++) {
      final v = xs[i];
      if (v == null) {
        if (path != null) canvas.drawPath(path, line);
        path = null;
        continue;
      }
      if (path == null) {
        path = Path()..moveTo(x(i), y(v));
        // an isolated point is still visible
        canvas.drawCircle(Offset(x(i), y(v)), 1.6, Paint()..color = color);
      } else {
        path.lineTo(x(i), y(v));
      }
    }
    if (path != null) canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(_Line o) => o.xs != xs || o.color != color;
}

/// One bar per day (30 days, oldest first). [split] stacks a second series on top.
class DailyBars extends StatelessWidget {
  const DailyBars({
    super.key,
    required this.values,
    this.split,
    this.height = 72,
    required this.semanticLabel,
    this.color,
    this.splitColor,
  });
  final List<num> values;
  final List<num>? split;
  final double height;
  final String semanticLabel;
  final Color? color;
  final Color? splitColor;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    child: SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _Bars(values, split, color ?? context.colors.primary, splitColor ?? context.links.relay.color)),
    ),
  );
}

class _Bars extends CustomPainter {
  _Bars(this.values, this.split, this.color, this.splitColor);
  final List<num> values;
  final List<num>? split;
  final Color color, splitColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final totals = [for (var i = 0; i < values.length; i++) values[i] + (split != null && i < split!.length ? split![i] : 0)];
    final hi = totals.reduce(math.max).toDouble();
    if (hi <= 0) return;
    final w = size.width / values.length;
    for (var i = 0; i < values.length; i++) {
      final a = values[i] / hi * size.height;
      final b = split != null && i < split!.length ? split![i] / hi * size.height : 0.0;
      final x = i * w + 1;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, size.height - a, w - 2, math.max(a, 1)), const Radius.circular(rMark)),
        Paint()..color = color.withValues(alpha: i == values.length - 1 ? .55 : 1),
      );
      if (b > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, size.height - a - b, w - 2, math.max(b, 1.5)), const Radius.circular(rMark)),
          Paint()..color = splitColor,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_Bars o) => o.values != values || o.split != split || o.color != color;
}

/// A sequential colour for an availability fraction (seqStep), from the
/// scheme's primary tones: darker = more online. -1 = no data (a pale tick),
/// 0 = offline (the offline colour).
Color availabilityColor(BuildContext context, int step) {
  final c = context.colors;
  return switch (step) {
    -1 => c.surfaceContainerHighest,
    0 => linkColor(context, LinkState.offline),
    1 => Color.lerp(c.surfaceContainerHighest, c.primary, .15)!,
    2 => Color.lerp(c.surfaceContainerHighest, c.primary, .35)!,
    3 => Color.lerp(c.surfaceContainerHighest, c.primary, .55)!,
    4 => Color.lerp(c.surfaceContainerHighest, c.primary, .75)!,
    _ => c.primary,
  };
}
