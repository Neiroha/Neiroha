import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';

/// A two-pane layout with a draggable divider.
///
/// The divider can be dragged freely, or the panes can be collapsed entirely
/// to one side.  When collapsed, a thin edge-drag zone lets the user drag
/// back to restore the split.  A prominent back button (or Escape key) also
/// restores the previous ratio.
///
/// Designed for mobile/tablet adaptation: on narrow screens the caller can
/// start with one pane collapsed.
class ResizableSplitPane extends StatefulWidget {
  final Widget left;
  final Widget Function(VoidCallback goBack) rightBuilder;

  /// Initial fraction [0..1] for the left pane. Default 0.35.
  final double initialLeftFraction;

  /// Minimum width in logical pixels before a pane auto-collapses.
  final double collapseThreshold;

  /// Minimum width in logical pixels that each pane must keep when dragging.
  /// Prevents the divider from being dragged so far that a pane disappears.
  final double minPaneWidth;

  final bool startCollapsedLeft;
  final bool startCollapsedRight;
  final ValueChanged<bool?>? onCollapseChanged;

  const ResizableSplitPane({
    super.key,
    required this.left,
    required this.rightBuilder,
    this.initialLeftFraction = 0.35,
    this.collapseThreshold = 80,
    this.minPaneWidth = 120,
    this.startCollapsedLeft = false,
    this.startCollapsedRight = false,
    this.onCollapseChanged,
  });

  @override
  State<ResizableSplitPane> createState() => ResizableSplitPaneState();
}

class ResizableSplitPaneState extends State<ResizableSplitPane> {
  late double _leftFraction;

  /// Saved fraction before collapsing — used to restore.
  late double _savedFraction;

  /// null = split, true = collapsed-left (right fills), false = collapsed-right (left fills)
  bool? _collapsed;

  /// Tracks whether the user is actively dragging out of a collapsed state.
  /// While true we show the split layout with the live fraction.
  bool _draggingFromCollapsed = false;

  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _leftFraction = widget.initialLeftFraction;
    _savedFraction = _leftFraction;
    if (widget.startCollapsedLeft) {
      _collapsed = true;
    } else if (widget.startCollapsedRight) {
      _collapsed = false;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void collapseLeft() {
    _savedFraction = _leftFraction;
    setState(() => _collapsed = true);
    widget.onCollapseChanged?.call(true);
  }

  void collapseRight() {
    _savedFraction = _leftFraction;
    setState(() => _collapsed = false);
    widget.onCollapseChanged?.call(false);
  }

  void expand() {
    setState(() {
      _leftFraction = _savedFraction;
      _collapsed = null;
    });
    widget.onCollapseChanged?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: false,
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape &&
            _collapsed != null) {
          expand();
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;

          // ── While dragging out of collapsed, show normal split ──
          if (_draggingFromCollapsed) {
            return _buildSplit(totalWidth);
          }

          // ── Fully collapsed left: only right pane + edge drag zone ──
          if (_collapsed == true) {
            return Stack(
              children: [
                widget.rightBuilder(_goBackFromRight),
                // Edge drag zone on the left side to drag back
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: _EdgeDragZone(
                    side: _CollapsedSide.left,
                    onDragStart: () {
                      setState(() {
                        _draggingFromCollapsed = true;
                        _leftFraction = 0.0;
                        _collapsed = null;
                      });
                    },
                  ),
                ),
                // Back button
                Positioned(
                  left: 12,
                  top: 12,
                  child: _BackButton(onTap: expand),
                ),
              ],
            );
          }

          // ── Fully collapsed right: only left pane + edge drag zone ──
          if (_collapsed == false) {
            return Stack(
              children: [
                widget.left,
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: _EdgeDragZone(
                    side: _CollapsedSide.right,
                    onDragStart: () {
                      setState(() {
                        _draggingFromCollapsed = true;
                        _leftFraction = 1.0;
                        _collapsed = null;
                      });
                    },
                  ),
                ),
              ],
            );
          }

          // ── Normal split mode ──
          return _buildSplit(totalWidth);
        },
      ),
    );
  }

  Widget _buildSplit(double totalWidth) {
    const dividerWidth = 6.0;
    // Clamp fraction so both panes keep at least minPaneWidth.
    final minFraction = widget.minPaneWidth / totalWidth;
    final maxFraction =
        1.0 - (widget.minPaneWidth + dividerWidth) / totalWidth;
    final clampedFraction = _leftFraction.clamp(minFraction, maxFraction);
    final leftWidth = (totalWidth * clampedFraction).clamp(0.0, totalWidth);
    final rightWidth =
        (totalWidth - leftWidth - dividerWidth).clamp(0.0, totalWidth);

    return Row(
      children: [
        SizedBox(width: leftWidth, child: widget.left),
        _DragDivider(
          onDrag: (dx) {
            setState(() {
              _leftFraction =
                  ((_leftFraction * totalWidth + dx) / totalWidth)
                      .clamp(minFraction, maxFraction);
            });
          },
          onDragEnd: () {
            _draggingFromCollapsed = false;
            // Always save the current split ratio.
            _savedFraction = _leftFraction;
          },
        ),
        SizedBox(
          width: rightWidth,
          child: widget.rightBuilder(_goBackFromRight),
        ),
      ],
    );
  }

  void _goBackFromRight() {
    _savedFraction = _leftFraction;
    setState(() => _collapsed = false);
    widget.onCollapseChanged?.call(false);
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
                    : const Color(0xFF2A2A36),
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
    return Material(
      color: AppTheme.surfaceBright.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(10),
      elevation: 4,
      shadowColor: Colors.black54,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.arrow_back_rounded,
                  size: 20, color: Colors.white),
              const SizedBox(width: 8),
              Text('Back',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.85))),
            ],
          ),
        ),
      ),
    );
  }
}
