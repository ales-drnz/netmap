// A device: its link, owner and a few numbers (speed, last seen, availability
// over 24 hours), then the technical details (addresses, versions, paths,
// latency over time, packets, recent events), all shown at once.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../app/theme.dart';
import '../data/api.dart';
import '../data/live.dart';
import '../data/model.dart';
import '../data/stats.dart';
import '../l10n/app_localizations.dart';
import '../l10n/words.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/link_glyph.dart';

class DeviceDetail extends ConsumerWidget {
  const DeviceDetail({super.key, required this.id, this.onClose, this.scroll, this.padding = const EdgeInsets.fromLTRB(24, 20, 24, 32)});
  final String id;
  final VoidCallback? onClose;
  final ScrollController? scroll;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final net = ref.watch(networkProvider);
    final now = ref.watch(clockProvider);
    final l = L.of(context);
    final c = context.colors;
    final d = net?.byId(id);
    if (net == null || d == null) {
      return Padding(
        padding: padding,
        child: EmptyNote(title: l.devNone),
      );
    }
    final me = net.me?.id == d.id;
    final n = d.node;
    final look = linkLook(context, d.state);
    final idle = n.idleSec ?? (n.lastSeen == null ? null : (now - n.lastSeen!) / 1000);
    final availability = n.uptime == null ? null : l.dtAvailPct(l.pct(n.uptime!));

    final stats = [
      if (d.median != null) Stat(label: l.dtSpeed, value: l.dtSpeedMs(d.median!.round())),
      Stat(label: l.dtLastSeen, value: d.online ? l.dtNow : (n.lastSeen == null ? l.neverSeen : l.ago(n.lastSeen!, now))),
      if (n.uptime != null) Stat(label: l.dtAvailability, value: l.pct(n.uptime!)),
    ];

    return ListView(
      controller: scroll,
      padding: padding,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            LinkGlyph(
              state: d.state,
              size: 64,
              child: Icon(deviceIcon(d.type), size: 30, fill: 1, color: look.on),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(header: true, child: Text(d.name, style: context.em.headlineSmall)),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: l.state(d.state),
                          style: TextStyle(color: linkColor(context, d.state), fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: ' · ${l.dtOwner(d.ownerLabel, l.type(d.type).toLowerCase())}'),
                        if (me) TextSpan(text: ' · ${l.you}'),
                        if (!d.active) TextSpan(text: ' · ${l.stateInactive}'),
                      ],
                    ),
                    style: context.type.bodyMedium?.copyWith(color: c.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (onClose != null) IconButton(tooltip: l.closeDetails, onPressed: onClose, icon: const Icon(Symbols.close_rounded)),
          ],
        ),
        const SizedBox(height: 24),
        // one row; on a phone it wraps
        LayoutBuilder(
          builder: (context, box) => Wrap(spacing: box.maxWidth < 400 ? 24 : 32, runSpacing: 16, children: stats),
        ),
        if (n.beats.any((b) => b != null)) ...[
          const SizedBox(height: 24),
          AvailabilityStrip(beats: n.beats, semanticLabel: availability ?? l.dtAvailability),
        ],
        _Technical(device: d, net: net, now: now, idle: idle),
      ],
    );
  }
}

/// A section heading in the details: the same rhythm for each.
Widget _head(BuildContext context, String text, {String? trailing}) => Padding(
  padding: const EdgeInsets.only(top: 32, bottom: 8),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      Expanded(
        child: Semantics(header: true, child: Text(text, style: context.em.titleMedium)),
      ),
      if (trailing != null) Text(trailing, style: context.type.labelLarge?.copyWith(color: context.colors.onSurfaceVariant)),
    ],
  ),
);

class _Technical extends StatelessWidget {
  const _Technical({required this.device, required this.net, required this.now, this.idle});
  final Device device;
  final NetworkView net;
  final int now;
  final double? idle;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final c = context.colors;
    final n = device.node;
    final newest = newestVersion(net.snap.nodes);
    final lat = n.latency30;
    final samples = numbers(n.spark).length;
    final events = net.snap.events.where((e) => e.id == n.id).take(6).toList();
    final med = lat?.median ?? deviceMedian(n);
    final trend = lat?.trend;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _head(context, l.dtTechnical),
        for (final ip in n.ips) Fact(label: l.dtAddress, value: ip, mono: true, copy: ip),
        Fact(label: l.dtNodeId, value: n.id, mono: true, copy: n.id),
        if (n.version != null)
          Fact(label: l.dtVersion, value: newest != null && newest != n.version ? '${n.version} · ${l.dtNewest(newest)}' : n.version!),
        if (device.online && device.state != LinkState.online && device.state != LinkState.oneWay)
          Fact(
            label: l.dtVia,
            value: switch (device.state) {
              LinkState.atHome => l.dtViaLocal,
              LinkState.relay => l.dtViaRelay,
              _ => l.dtViaInternet,
            },
          ),
        if (n.paths != null) Fact(label: l.dtPaths, value: l.dtPathsValue(n.paths!, n.pathsDead ?? 0, n.family ?? 4)),
        if (device.online && n.idleSec != null) Fact(label: l.dtLastPacket, value: l.dtSecondsAgo(n.idleSec!.round())),
        if (n.since != null) Fact(label: l.dtMemberFor, value: l.duration((now - n.since!) / 1000)),
        if (n.note != null) Fact(label: l.dtNote, value: n.note!),
        if (n.labels.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final lb in n.labels) Chip(label: Text(lb.name), visualDensity: VisualDensity.compact)],
            ),
          ),
        if (samples > 0) ...[
          _head(context, l.dtLatency, trailing: med == null ? null : l.dtMedianP95(med.round(), (lat?.p95 ?? med).round())),
          if (lat?.prevMedian != null)
            Text(
              [
                l.dtWeekPrev(lat!.prevMedian!.round()),
                if (trend != null) '(${trend >= 1 ? '+' : '−'}${l.pct((trend - 1).abs(), digits: 0)})',
              ].join(' '),
              style: context.type.bodySmall?.copyWith(color: c.onSurfaceVariant),
            ),
          const SizedBox(height: 8),
          LatencyLine(
            samples: n.spark,
            median: deviceMedian(n),
            previous: lat?.prevMedian,
            height: 96,
            semanticLabel: med == null ? l.dtLatency : l.dtMedianP95(med.round(), (lat?.p95 ?? med).round()),
          ),
        ],
        if (n.traffic != null) ...[
          _head(context, l.dtPackets),
          Text(
            '${l.dtPacketsTotal(l.compact(n.traffic!.packets))} · ${l.dtErrors(n.traffic!.errors)}',
            style: context.type.bodySmall?.copyWith(color: c.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          DailyBars(values: n.traffic!.days, semanticLabel: l.dtPacketsTotal(l.compact(n.traffic!.packets))),
        ],
        if (events.isNotEmpty) ...[_head(context, l.dtRecent), for (final e in events) EventRow(event: e, now: now, dense: true)],
        const SizedBox(height: 8),
      ],
    );
  }
}

/// One event in a list: an icon for its kind, the sentence and the time on
/// the first line, its data (if any) below.
class EventRow extends StatelessWidget {
  const EventRow({super.key, required this.event, required this.now, this.dense = false});
  final NetEvent event;
  final int now;
  final bool dense;

  static (IconData, LinkState?) look(EventKind k) => switch (k) {
    EventKind.offline => (Symbols.power_settings_new_rounded, LinkState.offline),
    EventKind.online => (Symbols.power_rounded, LinkState.internet),
    EventKind.relay => (Symbols.alt_route_rounded, LinkState.relay),
    EventKind.direct => (Symbols.bolt_rounded, LinkState.internet),
    EventKind.spike => (Symbols.speed_rounded, LinkState.oneWay),
    EventKind.pending => (Symbols.person_add_rounded, null),
    EventKind.netdrop => (Symbols.group_off_rounded, LinkState.oneWay),
  };

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final (title, sub) = l.event(event);
    final (icon, state) = look(event.kind);
    return ActivityRow(
      icon: icon,
      color: state == null ? context.colors.tertiary : linkColor(context, state),
      title: title,
      sub: dense ? null : sub,
      end: now - event.t < dayMs ? l.ago(event.t, now) : l.time(event.t),
      dense: dense,
    );
  }
}

/// The row of the activity list: a bare icon, the title with [end] on the
/// same line, an optional line below.
class ActivityRow extends StatelessWidget {
  const ActivityRow({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.sub,
    required this.end,
    this.endMono = false,
    this.dense = false,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String? sub;
  final String end;
  final bool endMono;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? 8 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // at the start of its 40 dp column: the left edge lines up with the headers above
          SizedBox(
            width: 40,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Icon(icon, size: 24, fill: 1, color: color),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(title, style: context.type.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      end,
                      style: context.type.bodySmall?.copyWith(color: c.onSurfaceVariant, fontFamily: endMono ? fontMono : null),
                    ),
                  ],
                ),
                if (sub != null) Text(sub!, style: context.type.bodySmall?.copyWith(color: c.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
