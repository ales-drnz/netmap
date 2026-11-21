// The network: how it is set up, whether the hub is healthy, whether what
// ZTNET configures actually reaches the hub, and how it performs over time.
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart' hide Route;

import '../app/shell.dart';
import '../app/theme.dart';
import '../data/api.dart';
import '../data/live.dart';
import '../data/model.dart';
import '../data/naming.dart';
import '../data/stats.dart';
import '../l10n/app_localizations.dart';
import '../l10n/words.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/link_glyph.dart';

class NetworkPage extends ConsumerWidget {
  const NetworkPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final net = ref.watch(networkProvider);
    final now = ref.watch(clockProvider);
    final l = L.of(context);
    if (net == null) return PageFrame(title: l.navNetwork, slivers: const []);
    final snap = net.snap;
    final hubName = net.hub?.name ?? l.hub;
    final cfg = snap.net;
    // no local ZeroTier service: nothing to say about the hub or the chain
    final noLocal = snap.health?.zt == null && snap.health?.local == null;
    final noMetrics = snap.health?.bytes == null;

    // two cards side by side when there is room, as tall as each other
    Widget pair(Widget a, Widget b) => LayoutBuilder(
      builder: (context, box) => box.maxWidth > 760
          ? IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  Expanded(child: a),
                  Expanded(child: b),
                ],
              ),
            )
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 16, children: [a, b]),
    );
    Widget gap() => const SliverToBoxAdapter(child: SizedBox(height: 16));
    final relays = net.devices.where((d) => d.state == LinkState.relay).toList();

    return PageFrame(
      title: snap.networkName.isEmpty ? l.navNetwork : snap.networkName,
      intro: [
        if (cfg?.private != null) cfg!.private! ? l.netPrivate : l.netPublic,
        if (cfg?.creationTime != null) l.netCreated(l.date(cfg!.creationTime!)),
      ].join(' · ').nullIfEmpty,
      slivers: [
        SliverToBoxAdapter(
          child: Fact(label: l.netId, value: snap.networkId, mono: true, copy: snap.networkId),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        SliverToBoxAdapter(
          child: _Kpis(net: net, now: now),
        ),
        gap(),
        SliverToBoxAdapter(
          child: noLocal
              ? SectionCard(
                  title: l.netHubTitle(hubName),
                  child: EmptyNote(title: l.localReason(snap.health?.localReason)),
                )
              : _Chain(snap: snap, hubName: hubName),
        ),
        gap(),
        SliverToBoxAdapter(
          child: noLocal
              ? pair(_Composition(net: net), _Versions(net: net))
              // the hub beside what the network is made of and which versions it runs
              : LayoutBuilder(
                  builder: (context, box) {
                    final wide = box.maxWidth > 760;
                    final side = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 16,
                      children: [
                        _Composition(net: net),
                        if (wide) Expanded(child: _Versions(net: net)) else _Versions(net: net),
                      ],
                    );
                    return wide
                        ? pair(_Hub(net: net, hubName: hubName), side)
                        : Column(
                            spacing: 16,
                            children: [
                              _Hub(net: net, hubName: hubName),
                              side,
                            ],
                          );
                  },
                ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 32, 0, 16),
            child: Semantics(header: true, child: Text(l.netPerf, style: context.em.titleLarge)),
          ),
        ),
        SliverToBoxAdapter(child: _LatencyByDevice(net: net)),
        SliverToBoxAdapter(
          child: _AvailabilityGrid(net: net, now: now),
        ),
        gap(),
        SliverToBoxAdapter(
          child: noMetrics
              ? SectionCard(
                  title: l.netTraffic,
                  child: EmptyNote(title: l.netMetricsOff),
                )
              : pair(_Traffic(snap: snap), _TopUsers(net: net)),
        ),
        if (relays.isNotEmpty) ...[
          gap(),
          SliverToBoxAdapter(
            child: _Relays(relays: relays, now: now),
          ),
        ],
      ],
    );
  }
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.net, required this.now});
  final NetworkView net;
  final int now;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final c = context.colors;
    final k = net.counts;
    // network-wide week comparison: median of recent medians vs previous ones,
    // over the devices that have both
    final both = net.snap.nodes.where((n) => n.latency30?.median != null && n.latency30?.prevMedian != null).toList();
    final recent = median(both.map((n) => n.latency30!.median!));
    final prev = median(both.map((n) => n.latency30!.prevMedian!));
    final drops = net.snap.events.where((e) => now - e.t <= dayMs && (e.kind == EventKind.netdrop || e.kind == EventKind.offline)).length;
    final style = context.em.headlineMedium;
    return Material(
      color: c.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rCard)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: double.infinity,
          child: Wrap(
            spacing: 48,
            runSpacing: 24,
            children: [
              Stat(
                label: l.netOnlineNow,
                value: '${k.online}/${k.active}',
                style: style,
                sub: k.inactive > 0 ? l.inactiveShort(k.inactive) : null,
              ),
              if (net.typical != null)
                Stat(
                  label: l.netTypical,
                  value: l.latencyMs(net.typical!.round()),
                  style: style,
                  sub: recent != null && prev != null && prev > 0
                      ? l.netVsWeek('${recent >= prev ? '+' : '−'}${l.pct((recent / prev - 1).abs(), digits: 0)}')
                      : null,
                ),
              if (net.availability != null) Stat(label: l.netAvailability, value: l.pct(net.availability!), style: style),
              Stat(label: l.netOutages, value: '$drops', style: style),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hub extends StatelessWidget {
  const _Hub({required this.net, required this.hubName});
  final NetworkView net;
  final String hubName;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final zt = net.snap.health?.zt;
    final links = context.links;
    String flag(bool? v, String on, String off) => v == null ? l.netUnknown : (v ? on : off);
    return SectionCard(
      title: l.netHubTitle(hubName),
      child: zt == null
          ? EmptyNote(title: l.netNoLocal)
          : Column(
              children: [
                Fact(
                  label: l.netService,
                  value: zt.online ? l.netOnline : l.netNotOnline,
                  valueColor: zt.online ? links.direct.color : links.oneWay.color,
                ),
                Fact(label: l.dtVersion, value: l.netVersionPort(zt.version ?? '—', zt.port?.toString() ?? '—')),
                Fact(
                  label: l.netTcpFallback,
                  value: flag(zt.tcpFallback, l.netActive, l.netInactive),
                  valueColor: zt.tcpFallback ? links.relay.color : null,
                ),
                Fact(
                  label: l.netForced,
                  value: flag(zt.forceTcpRelay, l.netActive, l.netInactive),
                  valueColor: zt.forceTcpRelay ? links.relay.color : null,
                ),
                Fact(
                  label: l.netPortMapping,
                  value: flag(zt.portMapping, l.netOn, l.netOff),
                  valueColor: zt.portMapping == false ? links.relay.color : null,
                ),
                Fact(label: l.netMetrics, value: flag(net.snap.metrics, l.netOn, l.netOff)),
              ],
            ),
    );
  }
}

/// Configured (ZTNET) → received (the hub's ZeroTier) → applied (allowed on the hub).
class _Chain extends StatelessWidget {
  const _Chain({required this.snap, required this.hubName});
  final Snapshot snap;
  final String hubName;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final c = context.colors;
    final cfg = snap.net;
    final local = snap.health?.local;

    final rows = <(String, String, String?, String?)>[];
    String list(Iterable<String> xs) => xs.isEmpty ? l.netNone : xs.join(', ');
    final dnsCfg = cfg?.dns == null ? l.netNone : [cfg!.dns!.domain, ...cfg.dns!.servers].whereType<String>().join(' · ');
    final dnsRcv = local == null
        ? null
        : (local.dns == null ? l.netNotReceived : [local.dns!.domain, ...local.dns!.servers].whereType<String>().join(' · '));
    rows.add((
      l.netDns,
      dnsCfg,
      dnsRcv,
      local == null ? null : (local.dns == null ? l.netNotApplied : (local.allowDNS == true ? l.netYes : l.netConsentOff)),
    ));
    for (final r in cfg?.routes ?? const <Route>[]) {
      final got = local?.routes.any((x) => x.target == r.target && x.via == r.via);
      final text = r.via == null ? r.target : '${r.target} → ${r.via}';
      rows.add((
        l.netRoutes,
        text,
        got == null ? null : (got ? text : l.netNotReceived),
        got == null ? null : (!got ? l.netNotApplied : (local!.allowManaged == false ? l.netConsentOff : l.netYes)),
      ));
    }
    rows.add((
      l.netAddresses,
      list([for (final p in cfg?.pools ?? const <Pool>[]) '${p.start} – ${p.end}']),
      local == null ? null : list(local.addresses),
      local == null ? null : (local.addresses.isEmpty ? l.netNotApplied : (local.allowManaged == false ? l.netConsentOff : l.netYes)),
    ));

    final bad = context.links.oneWay.color;
    Widget value(String a, String? b) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // RobotoMono has no arrow: the route's → comes from the text font
        Text(
          a,
          style: context.type.bodySmall?.copyWith(fontFamily: fontMono, fontFamilyFallback: const ['RobotoFlex']),
        ),
        // what the hub received, only when it differs
        if (b != null && b != a)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Symbols.cancel_rounded, size: 16, fill: 1, color: bad),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    b == l.netNotReceived ? b : l.netReceivedValue(b),
                    style: context.type.bodySmall?.copyWith(color: bad, fontFamily: b == l.netNotReceived ? null : fontMono),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    // on a phone there is no column header: "yes" says where
    Widget status(String? v, {bool phone = false}) {
      if (v == null) return const SizedBox.shrink();
      final no = v != l.netYes;
      if (phone && !no) v = l.netApplied(hubName);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(no ? Symbols.cancel_rounded : Symbols.check_circle_rounded, size: 18, fill: 1, color: no ? bad : context.links.direct.color),
          const SizedBox(width: 4),
          Flexible(child: Text(v, style: context.type.bodySmall)),
        ],
      );
    }

    // a label only on the first of its run ("Routes" once for every route)
    String? labelAt(int i) => i > 0 && rows[i - 1].$1 == rows[i].$1 ? null : rows[i].$1;
    const pad = EdgeInsets.symmetric(vertical: 12, horizontal: 8);

    return SectionCard(
      title: l.netChain,
      child: local == null
          ? EmptyNote(title: l.netNoLocal)
          : windowSizeOf(context) == WindowSize.compact
          // phones: one block per item, the status under the value
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, (_, a, b, st)) in rows.indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 4,
                      children: [
                        if (labelAt(i) case final label?) Text(label, style: context.type.labelLarge),
                        value(a, b),
                        status(st, phone: true),
                      ],
                    ),
                  ),
              ],
            )
          : Table(
              columnWidths: const {0: FixedColumnWidth(112), 1: FlexColumnWidth(), 2: IntrinsicColumnWidth()},
              defaultVerticalAlignment: TableCellVerticalAlignment.top,
              children: [
                TableRow(
                  children: [
                    const SizedBox(),
                    for (final h in [l.netConfigured, l.netApplied(hubName)])
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                        child: Text(h, style: context.type.labelMedium?.copyWith(color: c.onSurfaceVariant)),
                      ),
                  ],
                ),
                for (final (i, (_, a, b, st)) in rows.indexed)
                  TableRow(
                    children: [
                      Padding(
                        padding: pad.copyWith(left: 0),
                        child: Text(labelAt(i) ?? '', style: context.type.labelLarge),
                      ),
                      Padding(padding: pad, child: value(a, b)),
                      Padding(padding: pad, child: status(st)),
                    ],
                  ),
              ],
            ),
    );
  }
}

class _LatencyByDevice extends StatelessWidget {
  const _LatencyByDevice({required this.net});
  final NetworkView net;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final c = context.colors;
    final rows = [
      for (final d in net.devices.where((d) => d.state.isDirect && d.median != null))
        (d, quantile(numbers(d.node.spark), .1) ?? d.median!, d.median!, quantile(numbers(d.node.spark), .9) ?? d.median!),
    ]..sort((a, b) => a.$3.compareTo(b.$3));
    if (rows.isEmpty) return const SizedBox.shrink();
    final hi = rows.map((r) => r.$4).reduce(math.max) * 1.1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SectionCard(
        title: l.netLatencyBy,
        child: Column(
          children: [
            for (final (d, lo, med, top) in rows.take(14))
              _LatencyRow(device: d, lo: lo, med: med, top: top, hi: hi, color: c.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _LatencyRow extends StatelessWidget {
  const _LatencyRow({required this.device, required this.lo, required this.med, required this.top, required this.hi, required this.color});
  final Device device;
  final double lo, med, top, hi;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final d = device;
    final trend = d.node.latency30?.trend;
    // slower than the week before: by how much, only when it is worth saying
    final worse = trend != null && trend >= 1.1 ? '+${l.pct(trend - 1, digits: 0)}' : null;
    return InsetInk(
      inset: 12,
      onTap: () => context.go('/devices/${d.id}'),
      child: Semantics(
        label: [d.name, l.latencyMs(med.round()), ?worse].join(', '),
        button: true,
        excludeSemantics: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Row(
            children: [
              SizedBox(
                width: 120,
                child: Text(d.name, overflow: TextOverflow.ellipsis, style: context.type.bodySmall),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) => SizedBox(
                    height: 14,
                    child: Stack(
                      children: [
                        Positioned(
                          left: box.maxWidth * lo / hi,
                          width: math.max(4, box.maxWidth * (top - lo) / hi),
                          top: 4,
                          height: 6,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: linkColor(context, d.state).withValues(alpha: .3),
                              borderRadius: BorderRadius.circular(rMark),
                            ),
                          ),
                        ),
                        Positioned(
                          left: box.maxWidth * med / hi - 5,
                          top: 2,
                          child: LinkGlyph(state: d.state, size: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  l.latencyMs(med.round()),
                  textAlign: TextAlign.end,
                  style: context.type.labelMedium?.copyWith(color: color),
                ),
              ),
              SizedBox(
                width: 48,
                child: Text(
                  worse ?? '',
                  textAlign: TextAlign.end,
                  style: context.type.labelMedium?.copyWith(color: context.links.oneWay.color, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvailabilityGrid extends StatelessWidget {
  const _AvailabilityGrid({required this.net, required this.now});
  final NetworkView net;
  final int now;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final rows = net.devices.where((d) => isActive(d.node, now, window: dayMs) && d.node.beats.any((b) => b != null)).toList()
      ..sort((a, b) => (a.node.uptime ?? 1).compareTo(b.node.uptime ?? 1));
    if (rows.isEmpty) return const SizedBox.shrink();
    Widget line(Widget name, Widget strip, Widget value) => Row(
      children: [
        SizedBox(width: 120, child: name),
        Expanded(child: strip),
        SizedBox(width: 56, child: value),
      ],
    );
    return SectionCard(
      title: l.netAvailGrid,
      child: Column(
        children: [
          for (final d in rows.take(24))
            Semantics(
              label: '${d.name}: ${d.node.uptime == null ? '' : l.dtAvailPct(l.pct(d.node.uptime!))}',
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: line(
                  Text(d.name, overflow: TextOverflow.ellipsis, style: context.type.bodySmall),
                  AvailabilityStrip(beats: d.node.beats, height: 14, ends: false, semanticLabel: ''),
                  Text(d.node.uptime == null ? '' : l.pct(d.node.uptime!), textAlign: TextAlign.end, style: context.type.labelMedium),
                ),
              ),
            ),
          const SizedBox(height: 4),
          line(const SizedBox(), const AvailabilityEnds(), const SizedBox()),
        ],
      ),
    );
  }
}

class _Traffic extends StatelessWidget {
  const _Traffic({required this.snap});
  final Snapshot snap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final b = snap.health?.bytes;
    if (b == null || b.days.isEmpty) {
      return SectionCard(
        title: l.netTraffic,
        child: EmptyNote(title: l.netMetricsOff),
      );
    }
    final total = b.total.udp + b.total.tcp;
    final share = total == 0 ? 0.0 : b.total.tcp / total;
    return SectionCard(
      title: l.netTraffic,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.bytes(total), style: context.em.headlineSmall),
          Row(
            children: [
              _Key(color: context.colors.primary, text: 'UDP ${l.bytes(b.total.udp)}'),
              const SizedBox(width: 16),
              _Key(color: context.links.relay.color, text: 'TCP ${l.bytes(b.total.tcp)} · ${l.netTcpShare(l.pct(share))}'),
            ],
          ),
          const SizedBox(height: 12),
          DailyBars(
            values: [for (final d in b.days) d.udp],
            split: [for (final d in b.days) d.tcp],
            height: 96,
            semanticLabel: '${l.netTraffic}: ${l.bytes(total)}, ${l.netTcpShare(l.pct(share))}',
          ),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(rMark)),
      ),
      const SizedBox(width: 8),
      Text(text, style: context.type.bodySmall),
    ],
  );
}

class _TopUsers extends StatelessWidget {
  const _TopUsers({required this.net});
  final NetworkView net;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final c = context.colors;
    final rows = [
      for (final p in net.people) (p.label, p.devices.fold<int>(0, (s, d) => s + (d.node.traffic?.packets ?? 0))),
    ].where((r) => r.$2 > 0).toList()..sort((a, b) => b.$2.compareTo(a.$2));
    final hi = rows.isEmpty ? 1 : rows.first.$2;
    return SectionCard(
      title: l.netTop,
      child: rows.isEmpty
          ? EmptyNote(title: l.netMetricsOff)
          : Column(
              children: [
                for (final (who, packets) in rows.take(8))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 90,
                          child: Text(who, overflow: TextOverflow.ellipsis, style: context.type.bodySmall),
                        ),
                        Expanded(
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: math.max(.02, packets / hi),
                            child: Container(
                              height: 12,
                              decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(rMark)),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 56,
                          child: Text(l.compact(packets), textAlign: TextAlign.end, style: context.type.labelMedium),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Relays extends StatelessWidget {
  const _Relays({required this.relays, required this.now});
  final List<Device> relays;
  final int now;

  @override
  Widget build(BuildContext context) {
    if (relays.isEmpty) return const SizedBox.shrink();
    return SectionCard(
      title: L.of(context).netRelays,
      child: Column(
        children: [for (final d in relays) DeviceTile(device: d, now: now, onTap: () => context.go('/devices/${d.id}'))],
      ),
    );
  }
}

class _Versions extends StatelessWidget {
  const _Versions({required this.net});
  final NetworkView net;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final vs = versionsInUse(net.snap.nodes);
    return SectionCard(
      title: l.netVersions,
      child: Column(
        children: [for (final (i, (v, n)) in vs.indexed) Fact(label: v, value: l.netDevicesCount(n), bold: i == 0)],
      ),
    );
  }
}

class _Composition extends StatelessWidget {
  const _Composition({required this.net});
  final NetworkView net;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final byType = <DeviceType, int>{};
    for (final d in net.devices) {
      byType[d.type] = (byType[d.type] ?? 0) + 1;
    }
    final rows = byType.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return SectionCard(
      title: l.netComposition,
      child: Text([for (final e in rows) l.devicesOfType(e.key.name, e.value)].join(' · '), style: context.type.bodyLarge),
    );
  }
}
