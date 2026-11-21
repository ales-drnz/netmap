// The home panel's services: what you can reach inside the network.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../app/theme.dart';
import '../data/api.dart';
import '../data/live.dart';
import '../l10n/app_localizations.dart';
import '../l10n/words.dart';
import '../platform/open_url.dart';
import 'common.dart';

class ServicesSection extends ConsumerWidget {
  const ServicesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final links = ref.watch(networkProvider.select((n) => n?.snap.links)) ?? const <QuickLink>[];
    if (links.isEmpty) return const SizedBox.shrink();
    final now = ref.watch(clockProvider);
    final l = L.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(l.services, style: context.em.titleMedium)),
        const SizedBox(height: 8),
        for (final s in links) _ServiceRow(service: s, now: now),
      ],
    );
  }
}

/// One service: the whole row opens it. A status line only when it is not
/// answering (or not checked yet): when it works there is nothing to say.
class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.service, required this.now});
  final QuickLink service;
  final int now;

  Color? _color() {
    final h = service.color?.replaceFirst('#', '');
    if (h == null || h.length != 6) return null;
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : Color(0xFF000000 | v);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final c = context.colors;
    final s = service;
    final down = switch (s.up) {
      false => s.downSince == null ? l.svcDown : l.svcDownFor(l.duration((now - s.downSince!) / 1000)),
      _ => null,
    };
    final tint = _color() ?? c.primary;
    final onTint = ThemeData.estimateBrightnessForColor(tint) == Brightness.dark ? Colors.white : Colors.black;
    return Tooltip(
      excludeFromSemantics: true,
      message: [s.url, if (s.app != null) l.svcApp(s.app!)].join('\n'),
      child: Semantics(
        button: true,
        link: true,
        // "Open Jellyfin", not just the name, when read aloud
        label: [l.open, s.name, ?s.description, ?down].join(', '),
        excludeSemantics: true,
        child: InsetInk(
          inset: 12,
          onTap: () => openUrl(s.url),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Row(
              children: [
                _ServiceIcon(service: s, tint: tint, onTint: onTint),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name, style: context.type.titleSmall),
                      if (s.description != null)
                        Text(
                          s.description!,
                          style: context.type.bodySmall?.copyWith(color: c.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (down != null)
                        Text(
                          down,
                          style: context.type.bodySmall?.copyWith(color: c.error, fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Symbols.open_in_new_rounded, size: 20, color: c.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The service's own icon (fetched by the server, served same-origin), or a
/// circle with its initial while there is none or it does not load.
class _ServiceIcon extends StatelessWidget {
  const _ServiceIcon({required this.service, required this.tint, required this.onTint});
  final QuickLink service;
  final Color tint;
  final Color onTint;

  @override
  Widget build(BuildContext context) {
    final letter = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(service.name.isEmpty ? '?' : service.name[0].toUpperCase(), style: context.em.titleMedium.copyWith(color: onTint)),
    );
    final icon = service.icon;
    if (icon == null) return letter;
    return SizedBox.square(
      dimension: 40,
      child: ClipOval(
        child: ColoredBox(
          color: context.colors.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Image.network(
              Uri.base.resolve(icon).toString(),
              width: 28,
              height: 28,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              // the letter circle covers the whole 40 px circle, not just the padded inside
              errorBuilder: (_, _, _) => OverflowBox(maxWidth: 40, maxHeight: 40, child: letter),
            ),
          ),
        ),
      ),
    );
  }
}
