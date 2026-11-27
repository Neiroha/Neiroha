part of 'resizable_split_pane.dart';

class _CompactPaneHandle extends StatelessWidget {
  final double width;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CompactPaneHandle({
    required this.width,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final compact = width < 72;
    return Material(
      color: AppTheme.accentColor.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(14),
      elevation: 8,
      shadowColor: Colors.black54,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: width,
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: Colors.white),
              if (!compact) ...[
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────── Edge Drag Zone (collapsed state) ─────────────────────

enum _CollapsedSide { left, right }

/// A thin, invisible drag handle that sits at the edge of a collapsed pane.
/// Dragging it fires [onDragStart], which transitions the split pane into
/// split-mode so the normal _DragDivider takes over.
class _EdgeDragZone extends StatefulWidget {
  final _CollapsedSide side;
  final VoidCallback onDragStart;

  const _EdgeDragZone({required this.side, required this.onDragStart});

  @override
  State<_EdgeDragZone> createState() => _EdgeDragZoneState();
}

class _EdgeDragZoneState extends State<_EdgeDragZone> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => widget.onDragStart(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: _hovering ? 8 : 5,
          color: _hovering
              ? AppTheme.accentColor.withValues(alpha: 0.5)
              : Colors.transparent,
        ),
      ),
    );
  }
}

// ─────────────────────────── Drag Divider ─────────────────────────────────

class _DragDivider extends StatefulWidget {
  final ValueChanged<double> onDrag;
  final VoidCallback onDragEnd;

  const _DragDivider({required this.onDrag, required this.onDragEnd});

  @override
  State<_DragDivider> createState() => _DragDividerState();
}

class _DragDividerState extends State<_DragDivider> {
  bool _hovering = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final active = _hovering || _dragging;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => setState(() => _dragging = true),
        onHorizontalDragUpdate: (d) => widget.onDrag(d.delta.dx),
        onHorizontalDragEnd: (_) {
          setState(() => _dragging = false);
          widget.onDragEnd();
        },
        child: SizedBox(
          width: 6,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: active ? 4 : 1,
              decoration: BoxDecoration(
                color: active
                    ? AppTheme.accentColor.withValues(alpha: 0.7)
                    : context.colors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
