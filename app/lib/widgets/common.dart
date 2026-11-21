// Small building blocks shared by the pages.
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../app/shell.dart';
import '../app/theme.dart';
import '../data/model.dart';
import '../l10n/app_localizations.dart';
import '../l10n/words.dart';
import 'link_glyph.dart';

/// A page body: room for the floating toolbar, a readable width, a big
/// emphasized title and a line of intro, then the content as slivers.
///
/// Every page shares one frame ([frameWidth]) so the title sits in the same
/// place on every tab; [readingWidth] narrows the content (left-aligned in the
/// frame) for pages that read as a single column.
class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.title,
    this.intro,
    required this.slivers,
    this.readingWidth,
    this.actions = const [],
    this.scrollbar = true,
  });
  final String title;
  final String? intro;
  final List<Widget> slivers;
  final double? readingWidth;
  final List<Widget> actions;

  /// false when the page is only part of the screen (list beside a detail):
  /// a scrollbar there would stand in the middle of the window
  final bool scrollbar;

  static const double frameWidth = 1100;

  @override
  Widget build(BuildContext context) {
    final inset = toolbarInsets(context);
    final compact = windowSizeOf(context) == WindowSize.compact;
    final side = compact ? 16.0 : 24.0;
    Widget content(Widget s) => readingWidth == null ? s : SliverCrossAxisConstrained(maxWidth: readingWidth!, alignStart: true, child: s);
    // the browser tab says which page this is
    return Title(
      title: '$title · Netmap',
      color: context.colors.primary,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: scrollbar),
        child: CustomScrollView(
          slivers: [
            SliverSafeArea(
              bottom: false,
              sliver: SliverPadding(
                padding: EdgeInsets.fromLTRB(side, inset.top + (compact ? 24 : 0), side, 0),
                sliver: SliverCrossAxisConstrained(
                  maxWidth: frameWidth,
                  child: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Semantics(
                                header: true,
                                child: Text(title, style: compact ? context.em.headlineLarge : context.em.displaySmall),
                              ),
                            ),
                            ...actions,
                          ],
                        ),
                        if (intro != null) ...[
                          const SizedBox(height: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 680),
                            child: Text(intro!, style: context.type.bodyLarge?.copyWith(color: context.colors.onSurfaceVariant)),
                          ),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            for (final s in slivers)
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: side),
                sliver: SliverCrossAxisConstrained(maxWidth: frameWidth, child: content(s)),
              ),
            SliverToBoxAdapter(child: SizedBox(height: inset.bottom + 48)),
          ],
        ),
      ),
    );
  }
}

/// Caps a sliver's width (like ConstrainedBox, for slivers): centred, or at
/// the start with [alignStart].
class SliverCrossAxisConstrained extends StatelessWidget {
  const SliverCrossAxisConstrained({super.key, required this.maxWidth, required this.child, this.alignStart = false});
  final double maxWidth;
  final Widget child;
  final bool alignStart;

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, c) {
      final extra = (c.crossAxisExtent - maxWidth).clamp(0.0, double.infinity);
      return SliverPadding(
        padding: alignStart ? EdgeInsets.only(right: extra) : EdgeInsets.symmetric(horizontal: extra / 2),
        sliver: child,
      );
    },
  );
}

/// A titled group of content on a tonal surface.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    this.note,
    required this.child,
    this.trailing,
    this.color,
    this.onColor,
    this.padding,
    this.leading,
  });
  final String title;
  final String? note;
  final Widget child;
  final Widget? trailing;

  /// before the title, e.g. a step number
  final Widget? leading;
  final Color? color;

  /// text colour on [color]
  final Color? onColor;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final compact = windowSizeOf(context) == WindowSize.compact;
    return Material(
      color: color ?? c.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rCard)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding ?? EdgeInsets.all(compact ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 16)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(title, style: context.em.titleMedium.copyWith(color: onColor)),
                      ),
                      if (note != null) ...[
                        const SizedBox(height: 4),
                        Text(note!, style: context.type.bodySmall?.copyWith(color: onColor ?? c.onSurfaceVariant)),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

/// A label and its value on one 48 dp line, the copy button right after the value.
class Fact extends StatelessWidget {
  const Fact({super.key, required this.label, required this.value, this.mono = false, this.copy, this.valueColor, this.bold = false});
  final String label;
  final String value;
  final bool mono;

  /// the value in w600, e.g. the most used version
  final bool bold;

  /// text to copy, when the value can be copied
  final String? copy;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // the window, not the parent: a LayoutBuilder here would break the
    // intrinsic heights of paired cards
    final narrow = windowSizeOf(context) == WindowSize.compact;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: narrow ? 112 : 150,
            child: Text(label, style: context.type.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
          ),
          // plain text: the copy button copies it (a selectable text would be a
          // second, 20 px tall tap target)
          Flexible(
            child: Text(
              value,
              style: (mono ? context.type.bodyMedium?.copyWith(fontFamily: fontMono) : context.type.bodyMedium)?.copyWith(
                color: valueColor ?? c.onSurface,
                fontWeight: bold ? FontWeight.w600 : null,
              ),
            ),
          ),
          if (copy != null) CopyButton(text: copy!),
        ],
      ),
    );
  }
}

/// A number with its label above and, if any, a short line below.
class Stat extends StatelessWidget {
  const Stat({super.key, required this.label, required this.value, this.style, this.sub});
  final String label;
  final String value;

  /// the value's style; titleLarge by default
  final TextStyle? style;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.type.labelMedium?.copyWith(color: c.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(value, style: style ?? context.em.titleLarge),
        if (sub != null) ...[const SizedBox(height: 4), Text(sub!, style: context.type.bodySmall?.copyWith(color: c.onSurfaceVariant))],
      ],
    );
  }
}

class CopyButton extends StatelessWidget {
  const CopyButton({super.key, required this.text, this.label});
  final String text;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return IconButton(
      tooltip: label ?? l.copy,
      icon: const Icon(Symbols.content_copy_rounded, size: 20),
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: text));
        if (context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text('${l.copied}: $text')));
        }
      },
    );
  }
}

/// A state as glyph + word (never colour alone).
class StateLabel extends StatelessWidget {
  const StateLabel({super.key, required this.state, this.size = 16, this.style});
  final LinkState state;
  final double size;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LinkGlyph(state: state, size: size),
        const SizedBox(width: 8),
        Text(
          l.state(state),
          style: (style ?? context.type.labelLarge)?.copyWith(color: linkColor(context, state), fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// "Nothing here": one plain line.
class EmptyNote extends StatelessWidget {
  const EmptyNote({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Text(title, style: context.type.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
  );
}

/// A device in a list: glyph with its type icon, name, owner and state.
class DeviceTile extends StatelessWidget {
  const DeviceTile({
    super.key,
    required this.device,
    required this.now,
    this.me = false,
    this.selected = false,
    this.onTap,
    this.showOwner = true,
  });
  final Device device;
  final int now;
  final bool me;
  final bool selected;
  final bool showOwner;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final c = context.colors;
    final d = device;
    final look = linkLook(context, d.state);
    final tail = d.state == LinkState.offline
        ? (d.node.lastSeen == null ? l.neverSeen : l.lastSeen(l.ago(d.node.lastSeen!, now)))
        : d.median != null
        ? l.latencyMs(d.median!.round())
        : null;
    return Opacity(
      // dimmed, but text stays readable (at least 4.5:1); the word "Inattivo" says it too
      opacity: d.active ? 1 : .8,
      child: ListTile(
        selected: selected,
        selectedTileColor: c.secondaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rItem)),
        minVerticalPadding: 12,
        onTap: onTap,
        leading: LinkGlyph(
          state: d.state,
          size: 40,
          child: Icon(deviceIcon(d.type), size: 20, fill: 1, color: look.on),
        ),
        title: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: d.name),
              if (me)
                TextSpan(
                  text: ' · ${l.you}',
                  style: TextStyle(color: c.primary, fontWeight: FontWeight.w800),
                ),
            ],
          ),
          overflow: TextOverflow.ellipsis,
          style: context.type.titleSmall,
        ),
        subtitle: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: l.state(d.state),
                style: TextStyle(color: linkColor(context, d.state), fontWeight: FontWeight.w600),
              ),
              if (tail != null) TextSpan(text: ' · $tail'),
              if (showOwner) TextSpan(text: ' · ${d.ownerLabel}'),
              if (!d.active) TextSpan(text: ' · ${l.stateInactive}'),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: d.ip == null
            ? null
            : Text(
                d.ip!,
                style: context.type.bodySmall?.copyWith(fontFamily: fontMono, color: c.onSurfaceVariant),
              ),
      ),
    );
  }
}

/// A tappable row whose hover and press highlight reaches [inset] beyond its
/// content on both sides: the content stays aligned with the headings above,
/// and the highlight never touches the icon or the text.
class InsetInk extends StatelessWidget {
  const InsetInk({super.key, required this.child, this.onTap, this.inset = 16});
  final Widget child;
  final VoidCallback? onTap;
  final double inset;

  @override
  Widget build(BuildContext context) => _Bleed(
    inset: inset,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(rItem),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: inset),
        child: child,
      ),
    ),
  );
}

/// Lays its child out [inset] wider on each side than itself, as tall as the
/// child, and draws it centred: the extra width spills over the sides.
class _Bleed extends SingleChildRenderObjectWidget {
  const _Bleed({required this.inset, super.child});
  final double inset;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderBleed(inset);

  @override
  void updateRenderObject(BuildContext context, _RenderBleed renderObject) => renderObject.inset = inset;
}

class _RenderBleed extends RenderProxyBox {
  _RenderBleed(this._inset);
  double _inset;
  set inset(double v) {
    if (v == _inset) return;
    _inset = v;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final w = constraints.maxWidth + 2 * _inset;
    child!.layout(constraints.copyWith(minWidth: w, maxWidth: w), parentUsesSize: true);
    size = constraints.constrain(Size(constraints.maxWidth, child!.size.height));
  }

  @override
  void paint(PaintingContext context, Offset offset) => context.paintChild(child!, offset - Offset(_inset, 0));

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (position.dx < -_inset || position.dx > size.width + _inset || position.dy < 0 || position.dy > size.height) return false;
    final hit = result.addWithPaintOffset(
      offset: Offset(-_inset, 0),
      position: position,
      hitTest: (result, p) => child!.hitTest(result, position: p),
    );
    if (hit) result.add(BoxHitTestEntry(this, position));
    return hit;
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) => transform.translateByDouble(-_inset, 0, 0, 1);
}
