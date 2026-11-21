// How a link state looks. Every device is a circle; colour tells the state at
// a glance and never alone: there is always the word next to it, and on the
// map its lane and, for relay and no reply, a small badge icon.
//   green circle            = direct (at home / over the internet)
//   amber circle + route    = through a relay
//   red circle + arrow      = one-way (we send, nothing comes back)
//   teal circle             = online, how unknown (no local ZeroTier data)
//   small grey circle       = offline
// The circles are flat: a full colour, no outline. [LinkLook.stroke] is the
// state's strong colour, used for its badge.
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../app/theme.dart';
import '../data/model.dart';
import '../data/naming.dart';

class LinkLook {
  const LinkLook({required this.fill, required this.stroke, required this.on});
  final Color fill;
  final Color stroke;

  /// content (icon, text) drawn on [fill]
  final Color on;
}

LinkLook linkLook(BuildContext context, LinkState s) {
  final l = context.links, c = context.colors;
  return switch (s) {
    // flat: a full circle in the state's colour, no outline
    LinkState.atHome || LinkState.internet => LinkLook(fill: l.direct.color, stroke: l.direct.color, on: l.direct.onColor),
    // online, path unknown: the app's own colour, no claim of direct or relay
    LinkState.online => LinkLook(fill: c.primary, stroke: c.primary, on: c.onPrimary),
    LinkState.relay => LinkLook(fill: l.relay.color, stroke: l.relay.color, on: l.relay.onColor),
    LinkState.oneWay => LinkLook(fill: l.oneWay.color, stroke: l.oneWay.color, on: l.oneWay.onColor),
    LinkState.offline => LinkLook(fill: c.outline, stroke: c.outline, on: c.surface),
  };
}

/// The strong colour of a state (text, lines).
Color linkColor(BuildContext context, LinkState s) => switch (s) {
  LinkState.atHome || LinkState.internet => context.links.direct.color,
  LinkState.online => context.colors.primary,
  LinkState.relay => context.links.relay.color,
  LinkState.oneWay => context.links.oneWay.color,
  LinkState.offline => context.colors.onSurfaceVariant,
};

/// The small icon that names a state next to its shape.
IconData linkIcon(LinkState s) => switch (s) {
  LinkState.atHome => Symbols.home_rounded,
  LinkState.internet => Symbols.public_rounded,
  LinkState.online => Symbols.check_rounded,
  LinkState.relay => Symbols.alt_route_rounded,
  LinkState.oneWay => Symbols.east_rounded,
  LinkState.offline => Symbols.power_settings_new_rounded,
};

IconData deviceIcon(DeviceType t) => switch (t) {
  DeviceType.pc => Symbols.desktop_windows_rounded,
  DeviceType.laptop => Symbols.laptop_chromebook_rounded,
  DeviceType.phone => Symbols.smartphone_rounded,
  DeviceType.tablet => Symbols.tablet_android_rounded,
  DeviceType.tv => Symbols.tv_rounded,
  DeviceType.server => Symbols.dns_rounded,
  DeviceType.console => Symbols.sports_esports_rounded,
  DeviceType.iot => Symbols.sensors_rounded,
};

/// The state's circle. Decorative: the state's word is always next to it or
/// in its semantics label.
class LinkGlyph extends StatelessWidget {
  const LinkGlyph({super.key, required this.state, this.size = 16, this.child});
  final LinkState state;
  final double size;
  final Widget? child;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: linkLook(context, state).fill, shape: BoxShape.circle),
      child: child,
    ),
  );
}
