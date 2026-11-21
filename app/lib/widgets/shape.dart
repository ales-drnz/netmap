// Path helpers shared by the hand-drawn charts and the map.
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

/// [source] cut into dashes of [on] with gaps of [off].
Path dashPath(Path source, double on, double off) {
  final out = Path();
  for (final ui.PathMetric m in source.computeMetrics()) {
    var d = 0.0;
    while (d < m.length) {
      out.addPath(m.extractPath(d, d + on), Offset.zero);
      d += on + off;
    }
  }
  return out;
}
