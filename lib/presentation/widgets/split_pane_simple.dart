part of 'resizable_split_pane.dart';

// ─────────────────── Vertical Resizable Split Pane ─────────────────────────

/// Two panes stacked vertically with a draggable horizontal divider between
/// them. Simpler than [ResizableSplitPane] — no collapse/edge-drag support,
/// just a resize handle. Used when a column needs to host two related widgets
/// (e.g. Quick TTS on top + voice inspector below) with user-adjustable ratio.
class VerticalResizableSplitPane extends StatefulWidget {
  final Widget top;
  final Widget bottom;

  /// Initial fraction [0..1] for the top pane. Default 0.5.
  final double initialTopFraction;

  /// Minimum height in logical pixels each pane must keep when dragging.
  final double minPaneHeight;

  const VerticalResizableSplitPane({
    super.key,
    required this.top,
    required this.bottom,
    this.initialTopFraction = 0.5,
    this.minPaneHeight = 100,
  });

  @override
  State<VerticalResizableSplitPane> createState() =>
      _VerticalResizableSplitPaneState();
}

class _VerticalResizableSplitPaneState
    extends State<VerticalResizableSplitPane> {
  late double _topFraction;

  @override
  void initState() {
    super.initState();
    _topFraction = widget.initialTopFraction;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = constraints.maxHeight;
        const dividerHeight = 6.0;
        final minFraction = widget.minPaneHeight / totalHeight;
        final maxFraction =
            1.0 - (widget.minPaneHeight + dividerHeight) / totalHeight;
        final clamped = _topFraction.clamp(minFraction, maxFraction);
        final topHeight = (totalHeight * clamped).clamp(0.0, totalHeight);
        final bottomHeight = (totalHeight - topHeight - dividerHeight).clamp(
          0.0,
          totalHeight,
        );

        return Column(
          children: [
            SizedBox(height: topHeight, child: widget.top),
            _HorizontalDragDivider(
              onDrag: (dy) {
                setState(() {
                  _topFraction =
                      ((_topFraction * totalHeight + dy) / totalHeight).clamp(
                        minFraction,
                        maxFraction,
                      );
                });
              },
            ),
            SizedBox(height: bottomHeight, child: widget.bottom),
          ],
        );
      },
    );
  }
}

/// Two panes side by side with a draggable vertical divider. Mirror of
/// [VerticalResizableSplitPane] for horizontal layouts. No collapse
/// semantics — just a width-resize handle.
class HorizontalResizableSplitPane extends StatefulWidget {
  final Widget left;
  final Widget right;

  /// Initial fraction [0..1] for the left pane. Default 0.7.
  final double initialLeftFraction;

  /// Minimum width in logical pixels each pane must keep when dragging.
  final double minPaneWidth;

  const HorizontalResizableSplitPane({
    super.key,
    required this.left,
    required this.right,
    this.initialLeftFraction = 0.7,
    this.minPaneWidth = 320,
  });

  @override
  State<HorizontalResizableSplitPane> createState() =>
      _HorizontalResizableSplitPaneState();
}

class _HorizontalResizableSplitPaneState
    extends State<HorizontalResizableSplitPane> {
  late double _leftFraction;

  @override
  void initState() {
    super.initState();
    _leftFraction = widget.initialLeftFraction;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        const dividerWidth = 6.0;
        final effectiveMinPaneWidth = math.min(
          widget.minPaneWidth,
          math.max(0, (totalWidth - dividerWidth) / 2),
        );
        final minFraction = effectiveMinPaneWidth / totalWidth;
        final maxFraction =
            1.0 - (effectiveMinPaneWidth + dividerWidth) / totalWidth;
        final clamped = _leftFraction.clamp(minFraction, maxFraction);
        final leftWidth = (totalWidth * clamped).clamp(0.0, totalWidth);
        final rightWidth = (totalWidth - leftWidth - dividerWidth).clamp(
          0.0,
          totalWidth,
        );

        return Row(
          children: [
            SizedBox(width: leftWidth, child: widget.left),
            _DragDivider(
              onDrag: (dx) {
                setState(() {
                  _leftFraction =
                      ((_leftFraction * totalWidth + dx) / totalWidth).clamp(
                        minFraction,
                        maxFraction,
                      );
                });
              },
              onDragEnd: () {},
            ),
            SizedBox(width: rightWidth, child: widget.right),
          ],
        );
      },
    );
  }
}

class _HorizontalDragDivider extends StatefulWidget {
  final ValueChanged<double> onDrag;
  const _HorizontalDragDivider({required this.onDrag});

  @override
  State<_HorizontalDragDivider> createState() => _HorizontalDragDividerState();
}

class _HorizontalDragDividerState extends State<_HorizontalDragDivider> {
  bool _hovering = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final active = _hovering || _dragging;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeRow,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: (_) => setState(() => _dragging = true),
        onVerticalDragUpdate: (d) => widget.onDrag(d.delta.dy),
        onVerticalDragEnd: (_) => setState(() => _dragging = false),
        child: SizedBox(
          height: 6,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              height: active ? 4 : 1,
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

// ──────────────────────────── Back Button ──────────────────────────────────

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: AppLocalizations.of(context).uiBack,
      child: Material(
        color: context.colors.raised.withValues(alpha: 0.9),
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: Colors.black54,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox.square(
            dimension: 44,
            child: Icon(Icons.arrow_back_rounded, size: 23),
          ),
        ),
      ),
    );
  }
}
