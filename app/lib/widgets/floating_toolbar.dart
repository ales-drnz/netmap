// Floating toolbar used as the main navigation.
//
// Material 3 Expressive specifies floating toolbars, but Flutter's material_ui
// has no widget for them yet (checked on material_ui 1.11.1): this is a small
// implementation on top of Material and InkWell. The vibrant colour pair is
// primaryContainer / onPrimaryContainer; the selected item is the same pair
// inverted, so it stands out in both themes.
import 'package:material_ui/material_ui.dart';

import '../app/theme.dart';

/// Which toolbar items show their name: all of them where there is room,
/// only the selected one where width is short, none on narrow phones.
enum ToolbarLabels { all, selected, none }

class ToolbarDestination {
  const ToolbarDestination({required this.icon, required this.label, this.badge});
  final IconData icon;
  final String label;

  /// small count on the icon, null = none
  final int? badge;
}

class FloatingNavToolbar extends StatelessWidget {
  const FloatingNavToolbar({
    super.key,
    required this.destinations,
    required this.selected,
    required this.onSelected,
    this.leading,
    this.trailing = const [],
    required this.semanticLabel,
    this.labels = ToolbarLabels.selected,
  });

  /// which items show their name next to the icon
  final ToolbarLabels labels;

  final List<ToolbarDestination> destinations;

  /// -1 = none (a page that is not in the toolbar)
  final int selected;
  final ValueChanged<int> onSelected;
  final Widget? leading;
  final List<Widget> trailing;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: semanticLabel,
      child: Material(
        color: c.primaryContainer,
        shape: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 4)],
              for (var i = 0; i < destinations.length; i++)
                _Item(dest: destinations[i], labels: labels, selected: i == selected, onTap: () => onSelected(i)),
              if (trailing.isNotEmpty) ...[const SizedBox(width: 8), ...trailing],
            ],
          ),
        ),
      ),
    );
  }
}

class _Item extends StatefulWidget {
  const _Item({required this.dest, required this.selected, required this.onTap, this.labels = ToolbarLabels.selected});
  final ToolbarDestination dest;
  final bool selected;
  final ToolbarLabels labels;
  final VoidCallback onTap;

  @override
  State<_Item> createState() => _ItemState();
}

/// Keeps track of keyboard focus, to draw a clear ring around the item.
class _ItemState extends State<_Item> {
  bool _focused = false;

  ToolbarDestination get dest => widget.dest;
  bool get selected => widget.selected;

  /// this item shows its name
  bool get label => widget.labels == ToolbarLabels.all || (selected && widget.labels == ToolbarLabels.selected);
  VoidCallback get onTap => widget.onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = selected ? c.primaryContainer : c.onPrimaryContainer;
    Widget icon = Icon(dest.icon, size: 24, color: fg, fill: selected ? 1 : 0);
    if (dest.badge != null && dest.badge! > 0) {
      icon = Badge(label: Text('${dest.badge}'), child: icon);
    }
    return Tooltip(
      // the item already says its name to screen readers
      excludeFromSemantics: true,
      message: label ? '' : dest.label,
      child: Semantics(
        button: true,
        selected: selected,
        label: dest.badge != null && dest.badge! > 0 ? '${dest.label}, ${dest.badge}' : dest.label,
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              onFocusChange: (f) => setState(() => _focused = f),
              customBorder: const StadiumBorder(),
              child: Container(
                height: 48,
                constraints: const BoxConstraints(minWidth: 48),
                padding: EdgeInsets.symmetric(horizontal: label ? 16 : 12),
                decoration: ShapeDecoration(
                  color: selected ? c.onPrimaryContainer : Colors.transparent,
                  shape: StadiumBorder(
                    side: _focused
                        ? BorderSide(color: c.onPrimaryContainer, width: 3, strokeAlign: BorderSide.strokeAlignOutside)
                        : BorderSide.none,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    icon,
                    if (label) ...[const SizedBox(width: 8), Text(dest.label, style: context.em.labelLarge.copyWith(color: fg))],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
