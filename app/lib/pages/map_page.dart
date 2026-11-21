// Home: the map, with a small floating panel (you, your address, services),
// the legend with the counts at the bottom, and the zoom controls.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../app/shell.dart';
import '../app/theme.dart';
import '../data/live.dart';
import '../data/model.dart';
import '../data/status.dart';
import '../l10n/app_localizations.dart';
import '../l10n/words.dart';
import '../map/map_view.dart';
import '../widgets/home_sections.dart';
import '../widgets/link_glyph.dart';
import 'device_detail.dart';

/// Width of the floating panel on wide screens.
const double _panelW = 360;

/// Width of a picked device's panel, on the right of the map.
const double _detailW = 440;

/// Height of every floating bar (toolbar, legend, zoom): 48 + 2 × 8.
const double _barH = 64;

/// the same margin on both sides, as wide as the panel's: what sits at the
/// bottom is centred on the window and never under the panel
const double _centred = 24 + _panelW + 24;

class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  final _map = MapController();

  /// phone: the part of the screen the sheet covers when it rests (the
  /// toolbar's 96 px, then you, your address and the legend)
  static const double _peek = 376;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final wide = windowSizeOf(context) == WindowSize.expanded;
    final size = MediaQuery.sizeOf(context);
    final selected = ref.watch(selectedDeviceProvider);
    void close() => ref.read(selectedDeviceProvider.notifier).select(null);
    // a picked device opens beside the map: the map makes room for it
    final obstruction = wide
        ? EdgeInsets.fromLTRB(24 + _panelW + 16, 104, selected == null ? 24 : 24 + _detailW + 16, 24 + _barH + 16)
        : const EdgeInsets.fromLTRB(8, 24, 8, _peek + 8);

    final zoom = _ZoomBar(controller: _map, compact: !wide);
    // the toolbar is centred at the top: where there is room beside it the
    // panel goes up to the top too, otherwise below it
    final panelTop = fitsBesideToolbar(size.width, _panelW) ? 24.0 : toolbarInsets(context).top;
    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: c.surface)),
        Positioned.fill(
          child: MapView(controller: _map, obstruction: obstruction, narrow: !wide),
        ),
        if (wide) ...[
          Positioned(
            left: 24,
            top: panelTop,
            width: _panelW,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: size.height - panelTop - 24),
              child: const _Panel(),
            ),
          ),
          // the bottom row: the legend centred on the window, like the
          // toolbar above, and the zoom bar on the right, the same height
          const Positioned(
            left: _centred,
            right: _centred,
            bottom: 24,
            child: Center(child: _Legend(bar: true)),
          ),
          Positioned(right: 24, bottom: 24, child: zoom),
          if (selected != null)
            Positioned(
              right: 24,
              top: fitsBesideToolbar(size.width, _detailW) ? 24 : toolbarInsets(context).top,
              bottom: 24 + _barH + 16,
              width: _detailW,
              child: Material(
                color: c.surfaceContainer,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rCard)),
                clipBehavior: Clip.antiAlias,
                child: DeviceDetail(key: ValueKey(selected), id: selected, onClose: close),
              ),
            ),
        ] else ...[
          Positioned(right: 16, bottom: _peek + 16, child: zoom),
          Positioned.fill(
            child: DraggableScrollableSheet(
              initialChildSize: (_peek / size.height).clamp(.2, .7),
              minChildSize: (128 / size.height).clamp(.1, .3),
              maxChildSize: .92,
              // a picked device takes the sheet's place, with a way back
              builder: (context, scroll) => selected == null
                  ? _Panel(sheet: true, scroll: scroll)
                  : Material(
                      color: c.surfaceContainer,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(rCard))),
                      clipBehavior: Clip.antiAlias,
                      child: DeviceDetail(
                        key: ValueKey(selected),
                        id: selected,
                        scroll: scroll,
                        onClose: close,
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 112),
                      ),
                    ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Zoom in, zoom out, show everything: a small floating bar, as tall as the
/// legend beside it.
class _ZoomBar extends StatelessWidget {
  const _ZoomBar({required this.controller, this.compact = false});
  final MapController controller;

  /// phone: pinch zooms, so only "show everything" is offered
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Material(
      color: context.colors.surfaceContainer,
      shape: const StadiumBorder(),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!compact) ...[
              IconButton(tooltip: l.zoomOut, onPressed: () => controller.zoomBy(1 / 1.3), icon: const Icon(Symbols.remove_rounded)),
              IconButton(tooltip: l.zoomIn, onPressed: () => controller.zoomBy(1.3), icon: const Icon(Symbols.add_rounded)),
            ],
            IconButton(tooltip: l.zoomFit, onPressed: controller.fit, icon: const Icon(Symbols.fit_screen_rounded)),
          ],
        ),
      ),
    );
  }
}

/// What the circles mean, with how many there are of each: only the states
/// that are on the map. The same words as everywhere else.
class _Legend extends ConsumerWidget {
  const _Legend({this.bar = false});

  /// a floating bar over the map (desktop), or plain in the phone's sheet
  final bool bar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(networkProvider.select((n) => n?.devices));
    if (devices == null || devices.isEmpty) return const SizedBox.shrink();
    final l = L.of(context);
    int count(bool Function(LinkState) f) => devices.where((d) => f(d.state)).length;
    final rows = [
      (LinkState.internet, l.stateDirect, count((s) => s == LinkState.atHome || s == LinkState.internet)),
      (LinkState.online, l.stateOnline, count((s) => s == LinkState.online)),
      (LinkState.relay, l.stateRelay, count((s) => s == LinkState.relay)),
      (LinkState.oneWay, l.stateOneWay, count((s) => s == LinkState.oneWay)),
      (LinkState.offline, l.stateOffline, count((s) => s == LinkState.offline)),
    ].where((r) => r.$3 > 0);
    final items = [
      for (final (s, word, n) in rows)
        Semantics(
          container: true,
          label: '$word: $n',
          excludeSemantics: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinkGlyph(state: s, size: 14),
              const SizedBox(width: 8),
              Text('$n', style: context.em.labelLarge),
              const SizedBox(width: 4),
              Text(word, style: context.type.labelLarge?.copyWith(color: context.colors.onSurfaceVariant)),
            ],
          ),
        ),
    ];
    final wrap = Wrap(spacing: 24, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: items);
    if (!bar) return Semantics(container: true, label: l.legend, child: wrap);
    return Semantics(
      container: true,
      label: l.legend,
      child: Material(
        color: context.colors.surfaceContainer,
        shape: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _barH),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20), child: wrap),
        ),
      ),
    );
  }
}

class _Panel extends ConsumerWidget {
  const _Panel({this.sheet = false, this.scroll});
  final bool sheet;

  /// the sheet's scroll controller (phone)
  final ScrollController? scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = L.of(context);
    final net = ref.watch(networkProvider);
    return Material(
      color: c.surfaceContainer,
      shape: sheet
          ? const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(rCard)))
          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(rCard)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        controller: scroll,
        primary: false,
        padding: EdgeInsets.fromLTRB(24, sheet ? 16 : 24, 24, sheet ? 112 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (sheet)
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: c.onSurfaceVariant.withValues(alpha: .4), borderRadius: BorderRadius.circular(2)),
                ),
              ),
            if (net == null)
              Text(l.loading, style: context.em.headlineSmall)
            else ...[
              _You(net: net),
              if (sheet) ...[const SizedBox(height: 24), const _Legend()],
              if (net.snap.links.isNotEmpty) ...[const SizedBox(height: 32), const ServicesSection()],
            ],
            const _Problem(),
          ],
        ),
      ),
    );
  }
}

/// You: your device, how it is connected, and your address to copy.
class _You extends StatelessWidget {
  const _You({required this.net});
  final NetworkView net;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final c = context.colors;
    final me = net.me;
    final title = switch (me?.state) {
      null => l.meUnknownTitle,
      LinkState.atHome || LinkState.internet => l.meDirectTitle,
      LinkState.online => l.meOnlineTitle,
      LinkState.relay => l.meRelayTitle,
      LinkState.oneWay => l.meOneWayTitle,
      LinkState.offline => l.meOfflineTitle,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (me != null) ...[
              LinkGlyph(
                state: me.state,
                size: 56,
                child: Icon(deviceIcon(me.type), size: 28, fill: 1, color: linkLook(context, me.state).on),
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    me == null ? net.snap.networkName : l.hello(me.ownerLabel),
                    style: context.type.bodyMedium?.copyWith(color: c.onSurfaceVariant),
                  ),
                  Semantics(header: true, child: Text(title, style: context.em.headlineSmall)),
                ],
              ),
            ),
          ],
        ),
        if (me?.ip != null) ...[const SizedBox(height: 16), _CopyAddress(ip: me!.ip!)],
      ],
    );
  }
}

/// Your address, and a tap copies it: the button says "Copied" for a moment
/// instead of a message sliding in.
class _CopyAddress extends StatefulWidget {
  const _CopyAddress({required this.ip});
  final String ip;

  @override
  State<_CopyAddress> createState() => _CopyAddressState();
}

class _CopyAddressState extends State<_CopyAddress> {
  bool _copied = false;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Tooltip(
      message: l.copyMyAddress,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: _copied ? l.addressCopied(widget.ip) : '${l.copyMyAddress}, ${widget.ip}',
        excludeSemantics: true,
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: widget.ip));
              if (!mounted) return;
              setState(() => _copied = true);
              _reset?.cancel();
              _reset = Timer(const Duration(seconds: 2), () {
                if (mounted) setState(() => _copied = false);
              });
            },
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _copied ? l.copied : widget.ip,
                    style: _copied ? null : const TextStyle(fontFamily: fontMono, fontWeight: FontWeight.w500, fontSize: 16),
                  ),
                ),
                Icon(_copied ? Symbols.check_rounded : Symbols.content_copy_rounded, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Only when something is wrong (no data from the server, ZTNET unreachable):
/// one line saying what. Nothing when all is well.
class _Problem extends ConsumerWidget {
  const _Problem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(verdictProvider);
    if (v.tone != Tone.danger) return const SizedBox.shrink();
    final now = ref.watch(clockProvider);
    final c = context.colors;
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Row(
          children: [
            Icon(Symbols.error_rounded, size: 18, color: c.error, fill: 1),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                L.of(context).verdictText(v, now),
                style: context.type.bodySmall?.copyWith(color: c.error, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
