// Every device: search, filter by link, grouped by person.
// Wide screens show the list and the selected device side by side (M3
// list-detail, never an empty pane); on a phone the device opens on its own
// page (/devices/<id>).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../app/shell.dart';
import '../app/theme.dart';
import '../data/live.dart';
import '../data/model.dart';
import '../l10n/app_localizations.dart';
import '../l10n/words.dart';
import '../widgets/common.dart';
import '../widgets/link_glyph.dart';
import 'device_detail.dart';

class DevicesPage extends ConsumerStatefulWidget {
  const DevicesPage({super.key, this.selected});
  final String? selected;

  @override
  ConsumerState<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends ConsumerState<DevicesPage> {
  final _query = TextEditingController();
  LinkState? _filter;

  /// at home and over the internet are one filter: direct
  static LinkState _same(LinkState s) => s == LinkState.atHome ? LinkState.internet : s;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool _match(Device d, String q) {
    if (_filter != null && _same(d.state) != _filter) return false;
    if (q.isEmpty) return true;
    return d.name.toLowerCase().contains(q) || d.ownerLabel.toLowerCase().contains(q) || d.node.ips.any((ip) => ip.contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final net = ref.watch(networkProvider);
    final now = ref.watch(clockProvider);
    final l = L.of(context);
    final size = windowSizeOf(context);
    final wide = size == WindowSize.expanded && MediaQuery.sizeOf(context).width >= 1000;

    // phone with a device chosen: the device is the page
    if (!wide && widget.selected != null) {
      return SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(left: 8, top: toolbarInsets(context).top + 8),
              child: TextButton.icon(
                onPressed: () => context.go('/devices'),
                icon: const Icon(Symbols.arrow_back_rounded),
                label: Text(l.back),
              ),
            ),
            Expanded(
              child: DeviceDetail(id: widget.selected!, padding: EdgeInsets.fromLTRB(16, 8, 16, toolbarInsets(context).bottom + 24)),
            ),
          ],
        ),
      );
    }

    final devices = net?.devices ?? const <Device>[];
    final q = _query.text.trim().toLowerCase();
    final shown = devices.where((d) => _match(d, q)).toList();
    final groups = <(String, List<Device>)>[
      for (final p in net?.people ?? const <Person>[])
        if (p.devices.where(shown.contains).toList() case final ds when ds.isNotEmpty) (p.label, ds),
    ];

    // wide, nothing chosen: show yourself (or the first device), so the pane is never empty
    if (wide && widget.selected == null && devices.isNotEmpty) {
      final first = net?.me?.id ?? devices.first.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/devices/$first');
      });
    }

    final list = PageFrame(
      title: l.navDevices,
      readingWidth: 640,
      scrollbar: !wide,
      slivers: [
        SliverToBoxAdapter(child: _controls(context, devices)),
        if (shown.isEmpty)
          SliverToBoxAdapter(child: EmptyNote(title: l.devNone))
        else
          for (final (title, ds) in groups) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Semantics(
                  header: true,
                  child: Text(
                    '$title · ${ds.where((d) => d.online).length}/${ds.length}',
                    style: context.type.titleSmall?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                ),
              ),
            ),
            SliverList.builder(
              itemCount: ds.length,
              itemBuilder: (context, i) => DeviceTile(
                device: ds[i],
                now: now,
                me: ds[i].id == net?.me?.id,
                showOwner: _filter != null,
                selected: ds[i].id == widget.selected,
                onTap: () => context.go('/devices/${ds[i].id}'),
              ),
            ),
          ],
      ],
    );

    if (!wide) return list;
    return Row(
      children: [
        Expanded(child: list),
        SizedBox(
          width: 480,
          child: Padding(
            // below the centred toolbar
            padding: EdgeInsets.fromLTRB(0, toolbarInsets(context).top, 24, 24),
            child: Material(
              color: context.colors.surfaceContainerLow,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rCard)),
              clipBehavior: Clip.antiAlias,
              child: widget.selected == null ? null : DeviceDetail(id: widget.selected!, key: ValueKey(widget.selected)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _controls(BuildContext context, List<Device> devices) {
    final l = L.of(context);
    // only the states some device is in (and the one picked, so it can be undone)
    final states = [
      for (final s in LinkState.values)
        if (s != LinkState.atHome && (s == _filter || devices.any((d) => _same(d.state) == s))) s,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SearchBar(
          controller: _query,
          hintText: l.devSearch,
          leading: const Icon(Symbols.search_rounded),
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStatePropertyAll(context.colors.surfaceContainerHigh),
          onChanged: (_) => setState(() {}),
          trailing: [
            if (_query.text.isNotEmpty)
              IconButton(tooltip: l.close, onPressed: () => setState(_query.clear), icon: const Icon(Symbols.close_rounded)),
          ],
        ),
        const SizedBox(height: 16),
        Semantics(
          label: l.actFilter,
          container: true,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                showCheckmark: false,
                label: Text(l.actAll),
                selected: _filter == null,
                onSelected: (_) => setState(() => _filter = null),
              ),
              for (final s in states)
                FilterChip(
                  avatar: LinkGlyph(state: s, size: 14),
                  showCheckmark: false,
                  label: Text(l.state(s)),
                  selected: _filter == s,
                  onSelected: (on) => setState(() => _filter = on ? s : null),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
