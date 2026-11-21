// What changed and when, by day. Devices that dropped in the same poll are
// one incident ("3 devices dropped together"), with who below. Access
// requests waiting for authorization come first, as one more group.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../app/theme.dart';
import '../data/api.dart';
import '../data/live.dart';
import '../data/model.dart';
import '../l10n/app_localizations.dart';
import '../l10n/words.dart';
import '../widgets/common.dart';
import 'device_detail.dart';

class ActivityPage extends ConsumerStatefulWidget {
  const ActivityPage({super.key, this.filter});
  final EventFilter? filter;

  @override
  ConsumerState<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends ConsumerState<ActivityPage> {
  late EventFilter? _filter = widget.filter;

  @override
  Widget build(BuildContext context) {
    final net = ref.watch(networkProvider);
    final now = ref.watch(clockProvider);
    final l = L.of(context);
    final c = context.colors;
    final pending = net?.snap.pending ?? const <Pending>[];
    final waiting = {for (final p in pending) p.id};
    final events = (net?.snap.events ?? const <NetEvent>[]).where(
      (e) => (_filter == null || filterOf(e.kind) == _filter) && !(e.kind == EventKind.pending && waiting.contains(e.id)),
    );
    final days = eventsByDay(events);
    final today = DateTime.fromMillisecondsSinceEpoch(now);
    final showPending = pending.isNotEmpty && (_filter == null || _filter == EventFilter.join);

    final filters = [
      (null, l.actAll),
      (EventFilter.off, l.actOff),
      (EventFilter.on, l.actOn),
      (EventFilter.path, l.actPath),
      (EventFilter.spike, l.actSpike),
      (EventFilter.join, l.actJoin),
    ];

    Widget header(String text) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Semantics(
        header: true,
        child: Text(text, style: context.type.titleSmall?.copyWith(color: c.onSurfaceVariant)),
      ),
    );

    return PageFrame(
      title: l.navActivity,
      readingWidth: 760,
      slivers: [
        SliverToBoxAdapter(
          child: Semantics(
            label: l.actFilter,
            container: true,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (f, label) in filters)
                  ChoiceChip(label: Text(label), selected: _filter == f, onSelected: (_) => setState(() => _filter = f)),
              ],
            ),
          ),
        ),
        if (showPending) ...[
          SliverToBoxAdapter(child: header('${l.actWaiting} · ${pending.length}')),
          SliverList.builder(
            itemCount: pending.length,
            itemBuilder: (context, i) {
              final p = pending[i];
              final sub = [if (p.waitingSec != null) l.actWaitingFor(l.duration(p.waitingSec!)), if (p.deauthorized) l.revoked].join(' · ');
              return ActivityRow(
                icon: Symbols.person_add_rounded,
                color: c.tertiary,
                title: p.name ?? p.id,
                sub: sub.isEmpty ? null : sub,
                end: p.id,
                endMono: true,
              );
            },
          ),
        ],
        if (days.isEmpty && !showPending)
          SliverToBoxAdapter(child: EmptyNote(title: _filter == null ? l.noEvents : l.actEmptyFilter))
        else
          for (final (day, es) in days) ...[
            SliverToBoxAdapter(child: header(l.day(day, today))),
            SliverList.builder(
              itemCount: es.length,
              itemBuilder: (context, i) {
                final e = es[i];
                return InsetInk(
                  onTap: e.id != null && net?.byId(e.id!) != null ? () => context.go('/devices/${e.id}') : null,
                  child: EventRow(event: e, now: now),
                );
              },
            ),
          ],
      ],
    );
  }
}
