// The map, the hub and a lane per state: pan, zoom, select. It fits the whole network into
// the part of the screen that panels leave free, and keeps the viewer's own
// pan and zoom once they move it.
//
// Keyboard: when the map has focus, arrows move between devices, Enter opens
// the selected one, + and - zoom, 0 fits everything again.
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../data/live.dart';
import '../l10n/app_localizations.dart';
import '../l10n/words.dart';
import 'layout.dart';
import 'map_painter.dart';

/// The device selected on the map (null = none).
class SelectedDevice extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? id) => state = id;
}

final selectedDeviceProvider = NotifierProvider<SelectedDevice, String?>(SelectedDevice.new);

/// The map's layout for the shape of its free area: taller than wide
/// (phones: the lanes go below the hub) and how wide for how tall.
final mapLayoutProvider = Provider.family<MapLayout, ({bool narrow, double aspect})>((ref, area) {
  final people = ref.watch(networkProvider.select((n) => n?.people));
  if (people == null) return MapLayout.empty;
  final me = ref.watch(networkProvider.select((n) => n?.me?.id));
  return layoutMap(people, meId: me, narrow: area.narrow, aspect: area.aspect);
});

/// Lets the zoom buttons drive the map from outside it.
class MapController extends ChangeNotifier {
  _MapViewState? _state;
  void zoomBy(double f) => _state?._zoomBy(f);
  void fit() => _state?._fit();
}

class MapView extends ConsumerStatefulWidget {
  const MapView({super.key, required this.controller, this.obstruction = EdgeInsets.zero, this.narrow, this.onOpen});
  final MapController controller;

  /// parts of the view covered by panels: the fit keeps the map out of them
  final EdgeInsets obstruction;

  /// a phone-sized window: the lanes go below the hub and the map fits the
  /// width (null: when the free area is taller than wide)
  final bool? narrow;

  /// a device was opened (tap, Enter)
  final void Function(String id)? onOpen;

  @override
  ConsumerState<MapView> createState() => _MapViewState();
}

class _MapViewState extends ConsumerState<MapView> {
  final _transform = TransformationController();
  final _focus = FocusNode(debugLabel: 'map');
  Size _viewport = Size.zero;
  Rect? _fittedBounds;
  bool _userMoved = false;
  bool _focusVisible = false;

  /// current zoom (x axis: the map is never rotated; z stays 1, so
  /// getMaxScaleOnAxis would never go below 1)
  double get _zoom => _transform.value.storage[0];

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
    _focus.addListener(
      () => setState(() => _focusVisible = _focus.hasFocus && FocusManager.instance.highlightMode == FocusHighlightMode.traditional),
    );
  }

  @override
  void didUpdateWidget(MapView old) {
    super.didUpdateWidget(old);
    widget.controller._state = this;
    if (old.obstruction != widget.obstruction && !_userMoved) _fittedBounds = null;
  }

  @override
  void dispose() {
    _transform.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ---------- view ----------

  Rect get _free => widget.obstruction.deflateRect(Offset.zero & _viewport);

  /// the free area's shape, from the last build
  ({bool narrow, double aspect}) _area = (narrow: false, aspect: 1.6);

  MapLayout get _layout => ref.read(mapLayoutProvider(_area));

  Matrix4 _fitMatrix(MapLayout layout) {
    final free = _free;
    final b = layout.bounds;
    var s = math.min(free.width / b.width, free.height / b.height).clamp(.18, 1.15);
    // taller than wide (phones): if the whole map would be too small to read
    // the names, fit its width instead, from the top; the rest is a pan away
    final byWidth = _area.narrow && s < namesMinScale;
    if (byWidth) s = (free.width / b.width).clamp(.18, 1.15);
    // child coordinates are world - bounds.topLeft
    final tx = free.center.dx - (b.width / 2) * s;
    final ty = byWidth ? free.top : free.center.dy - (b.height / 2) * s;
    return Matrix4.identity()
      ..translateByDouble(tx, ty, 0, 1)
      ..scaleByDouble(s, s, 1, 1);
  }

  void _fit() {
    final layout = _layout;
    _userMoved = false;
    _fittedBounds = layout.bounds;
    _transform.value = _fitMatrix(layout);
  }

  void _zoomBy(double f) {
    _userMoved = true;
    final c = _free.center;
    final s = _zoom;
    final target = (s * f).clamp(.15, 3.0) / s;
    final m = Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(target, target, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1)
      ..multiply(_transform.value);
    _transform.value = m;
  }

  void _centerOn(Offset world) {
    final layout = _layout;
    final s = _zoom;
    final child = world - layout.bounds.topLeft;
    final now = MatrixUtils.transformPoint(_transform.value, child);
    final free = _free.deflate(40);
    if (free.contains(now)) return;
    final d = free.center - now;
    _transform.value = Matrix4.identity()
      ..translateByDouble(d.dx, d.dy, 0, 1)
      ..multiply(_transform.value);
    _userMoved = true;
    assert(s > 0);
  }

  // ---------- input ----------

  MapNode? _hit(MapLayout layout, Offset child) {
    final world = child + layout.bounds.topLeft;
    MapNode? best;
    // a finger-sized area: at least 24 dp around each device on screen
    var bestD = math.max(34.0, 26 / _zoom);
    for (final n in layout.nodes) {
      final d = (n.pos - world).distance;
      if (d < bestD) {
        bestD = d;
        best = n;
      }
    }
    return best;
  }

  void _open(MapNode n) {
    ref.read(selectedDeviceProvider.notifier).select(n.device.id);
    widget.onOpen?.call(n.device.id);
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final layout = _layout;
    if (layout.nodes.isEmpty) return KeyEventResult.ignored;
    final sel = ref.read(selectedDeviceProvider);
    final cur = sel == null ? null : layout.byId(sel);
    final k = e.logicalKey;
    Offset? dir;
    if (k == LogicalKeyboardKey.arrowRight) dir = const Offset(1, 0);
    if (k == LogicalKeyboardKey.arrowLeft) dir = const Offset(-1, 0);
    if (k == LogicalKeyboardKey.arrowDown) dir = const Offset(0, 1);
    if (k == LogicalKeyboardKey.arrowUp) dir = const Offset(0, -1);
    if (dir != null) {
      final next = cur == null ? layout.nodes.first : _nearestIn(layout, cur, dir) ?? cur;
      ref.read(selectedDeviceProvider.notifier).select(next.device.id);
      _centerOn(next.pos);
      setState(() => _focusVisible = true);
      return KeyEventResult.handled;
    }
    if ((k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.space) && cur != null) {
      _open(cur);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.equal || k == LogicalKeyboardKey.add || k == LogicalKeyboardKey.numpadAdd) {
      _zoomBy(1.25);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.minus || k == LogicalKeyboardKey.numpadSubtract) {
      _zoomBy(.8);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.digit0 || k == LogicalKeyboardKey.numpad0) {
      _fit();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape && cur != null) {
      ref.read(selectedDeviceProvider.notifier).select(null);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// the closest device in direction [dir] (within ±60°)
  MapNode? _nearestIn(MapLayout layout, MapNode from, Offset dir) {
    MapNode? best;
    var bestScore = double.infinity;
    for (final n in layout.nodes) {
      if (n == from) continue;
      final v = n.pos - from.pos;
      final along = v.dx * dir.dx + v.dy * dir.dy;
      if (along <= 0) continue;
      final across = (v.dx * dir.dy - v.dy * dir.dx).abs();
      if (across > along * 1.8) continue;
      final score = along + across * 2;
      if (score < bestScore) {
        bestScore = score;
        best = n;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    // the map fills the window: its free area is the window's less the panels
    // (not counting the right side, where a device's panel comes and goes:
    // opening one must not re-flow the map)
    final free = widget.obstruction.copyWith(right: 0).deflateRect(Offset.zero & MediaQuery.sizeOf(context));
    // (the aspect in steps of 0.1: a small resize does not move the devices)
    final aspect = free.height <= 0 ? 1.6 : ((free.width / free.height) * 10).round() / 10;
    _area = (narrow: widget.narrow ?? free.width < free.height, aspect: aspect.clamp(.5, 4.0).toDouble());
    final layout = ref.watch(mapLayoutProvider(_area));
    final net = ref.watch(networkProvider);
    final selected = ref.watch(selectedDeviceProvider);
    final l = L.of(context);
    final style = MapStyle(context);

    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        if (size != _viewport) {
          _viewport = size;
          if (!_userMoved) _fittedBounds = null;
        }
        // refit while the viewer hasn't moved the map and the network changed shape
        if (!_userMoved && _fittedBounds != layout.bounds && size.width > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _fit();
          });
          _fittedBounds = layout.bounds;
          _transform.value = _fitMatrix(layout);
        }
        return Focus(
          focusNode: _focus,
          onKeyEvent: _onKey,
          child: Semantics(
            label: l.mapLabel,
            hint: l.mapHint,
            child: InteractiveViewer(
              transformationController: _transform,
              constrained: false,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              minScale: .15,
              maxScale: 3,
              onInteractionStart: (_) => _userMoved = true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) {
                  _focus.requestFocus();
                  final n = _hit(layout, d.localPosition);
                  if (n != null) {
                    _open(n);
                  } else {
                    ref.read(selectedDeviceProvider.notifier).select(null);
                  }
                },
                child: AnimatedBuilder(
                  // the zoom decides the level of detail: labels and icons
                  animation: _transform,
                  builder: (context, _) => CustomPaint(
                    size: layout.bounds.size,
                    painter: MapPainter(
                      layout: layout,
                      style: style,
                      origin: layout.bounds.topLeft,
                      scale: _zoom,
                      hubName: net?.hub?.name,
                      youWord: l.you,
                      hubWord: l.hub,
                      rankWords: [l.stateDirect, l.stateOnline, l.stateRelay, l.stateOneWay, l.stateOffline, l.stateInactive],
                      meId: net?.me?.id,
                      selectedId: selected,
                      focusVisible: _focusVisible,
                      semanticLabel: (n) => [
                        n.device.name,
                        if (n.device.id == net?.me?.id) l.you,
                        n.device.ownerLabel,
                        l.state(n.device.state),
                        if (!n.device.active) l.stateInactive,
                      ].join(', '),
                      onTapNode: _open,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
