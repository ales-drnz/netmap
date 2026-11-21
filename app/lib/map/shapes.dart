// What the map layout asks the painter to draw under the devices: lines,
// owner brackets, dots and labels. Pure data in world units, with colours
// named by their role, so the layout stays free of the theme and of words
// (the painter resolves both).
import 'dart:ui';

import '../data/model.dart';

/// A theme colour role (resolved by the painter).
enum Tone { surface, outline, outlineVariant, primary, onSurfaceVariant, surfaceContainerHigh, secondaryContainer }

/// How a device's state ranks on the map, one lane each: 0 direct,
/// 1 online (path unknown), 2 relay, 3 no reply, 4 offline, 5 inactive.
int stateRank(Device d) {
  if (!d.active) return 5;
  return switch (d.state) {
    LinkState.atHome || LinkState.internet => 0,
    LinkState.online => 1,
    LinkState.relay => 2,
    LinkState.oneWay => 3,
    LinkState.offline => 4,
  };
}

/// the state a rank is drawn with (its colour)
LinkState rankState(int rank) =>
    const [LinkState.internet, LinkState.online, LinkState.relay, LinkState.oneWay, LinkState.offline, LinkState.offline][rank];

/// The words of a label, resolved by the painter.
sealed class Words {
  const Words();
}

/// a name, as is
class Literal extends Words {
  const Literal(this.text);
  final String text;
}

/// the localized "you"
class YouWord extends Words {
  const YouWord();
}

/// "Online · 18": a state rank's word and a count
class StateCount extends Words {
  const StateCount(this.rank, this.count);
  final int rank;
  final int count;
}

sealed class MapShape {
  const MapShape();
}

/// A straight line, or a cubic one when [c1] and [c2] are given. Its colour
/// is a state's when [state] is set, else [tone].
class MapLine extends MapShape {
  const MapLine(this.a, this.b, {this.c1, this.c2, this.width = 2, this.alpha = 1, this.tone = Tone.outlineVariant, this.state});
  final Offset a, b;
  final Offset? c1, c2;

  /// on screen, in px
  final double width;
  final double alpha;
  final Tone tone;
  final LinkState? state;
}

/// A small dot in a state's colour (before a lane's title).
class MapDot extends MapShape {
  const MapDot(this.center, this.radius, this.state);
  final Offset center;
  final double radius;
  final LinkState state;
}

/// One owner's devices on a row sit on a shared, fully rounded band: from
/// [left] to [right], centred on the circles' row [y], [height] tall, filled
/// with [fill]. [ids]: the devices on it.
class GroupBand extends MapShape {
  const GroupBand(this.left, this.right, this.y, {required this.ids, this.height = 60, this.fill = Tone.surfaceContainerHigh});
  final double left, right, y, height;
  final Set<String> ids;
  final Tone fill;

  Rect get rect => Rect.fromLTRB(left, y - height / 2, right, y + height / 2);
}

enum Anchor { center, left, right }

/// A one-line label: [at] is its vertical centre and, by [anchor], its
/// horizontal centre, left or right edge. [size] in world units, never under
/// [minScreen] px on screen; hidden below [minScale]; longer than [maxWidth]
/// (world units) it ends in …
class MapText extends MapShape {
  const MapText(
    this.words,
    this.at, {
    this.anchor = Anchor.center,
    this.size = 12,
    this.weight = FontWeight.w700,
    this.tone = Tone.onSurfaceVariant,
    this.state,
    this.minScreen = 0,
    this.minScale = 0,
    this.maxWidth = 400,
  });
  final Words words;
  final Offset at;
  final Anchor anchor;
  final double size;
  final FontWeight weight;
  final Tone tone;

  /// a state's colour instead of [tone]
  final LinkState? state;
  final double minScreen;
  final double minScale;
  final double maxWidth;
}
