import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

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
  final double compactBreakpoint;
  final IconData compactRightIcon;
  final String? compactRightLabel;
  final double compactHandleBottomInset;

  const ResizableSplitPane({
    super.key,
    required this.left,
    required this.rightBuilder,
    this.initialLeftFraction = 0.35,
    this.collapseThreshold = 80,
    this.minPaneWidth = 320,
    this.startCollapsedLeft = false,
    this.startCollapsedRight = false,
    this.onCollapseChanged,
    this.compactBreakpoint = 840,
    this.compactRightIcon = Icons.tune_rounded,
    this.compactRightLabel,
    this.compactHandleBottomInset = 16,
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
  bool _isCompactLayout = false;
  bool _collapsedByCompactNavigation = false;
  Offset? _compactHandleOffset;
  Offset? _compactBackOffset;
  Size? _lastCompactSize;
  Size? _lastCompactBackSize;
  String? _lastCompactHandleLabel;

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
    _collapsedByCompactNavigation = false;
    setState(() => _collapsed = true);
    widget.onCollapseChanged?.call(true);
  }

  void collapseRight() {
    _savedFraction = _leftFraction;
    _collapsedByCompactNavigation = false;
    setState(() => _collapsed = false);
    widget.onCollapseChanged?.call(false);
  }

  void expand() {
    setState(() {
      _leftFraction = _savedFraction;
      _collapsed = null;
      _collapsedByCompactNavigation = false;
    });
    widget.onCollapseChanged?.call(null);
  }

  void showLeftPane({bool onlyWhenCompact = false}) {
    if (onlyWhenCompact && !_isCompactLayout) return;
    _savedFraction = _leftFraction;
    _collapsedByCompactNavigation = onlyWhenCompact;
    setState(() => _collapsed = false);
    widget.onCollapseChanged?.call(false);
  }

  void showRightPane({bool onlyWhenCompact = false}) {
    if (onlyWhenCompact && !_isCompactLayout) return;
    _savedFraction = _leftFraction;
    _collapsedByCompactNavigation = onlyWhenCompact;
    setState(() => _collapsed = true);
    widget.onCollapseChanged?.call(true);
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
          final compact = totalWidth < widget.compactBreakpoint;
          _isCompactLayout = compact;

          if (!compact &&
              _collapsedByCompactNavigation &&
              _collapsed != null &&
              !_draggingFromCollapsed) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted ||
                  _isCompactLayout ||
                  !_collapsedByCompactNavigation) {
                return;
              }
              expand();
            });
            return _buildSplit(totalWidth);
          }

          if (compact && !_draggingFromCollapsed) {
            return _buildCompact(constraints);
          }

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
    final effectiveMinPaneWidth = math.min(
      widget.minPaneWidth,
      math.max(0, (totalWidth - dividerWidth) / 2),
    );
    final minFraction = effectiveMinPaneWidth / totalWidth;
    final maxFraction =
        1.0 - (effectiveMinPaneWidth + dividerWidth) / totalWidth;
    final clampedFraction = _leftFraction.clamp(minFraction, maxFraction);
    final leftWidth = (totalWidth * clampedFraction).clamp(0.0, totalWidth);
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
              _leftFraction = ((_leftFraction * totalWidth + dx) / totalWidth)
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

  Widget _buildCompact(BoxConstraints constraints) {
    if (_collapsed == true) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _goBackFromRight();
        },
        child: Stack(
          children: [
            widget.rightBuilder(_goBackFromRight),
            _buildCompactBackButton(constraints),
          ],
        ),
      );
    }

    final label =
        widget.compactRightLabel ?? AppLocalizations.of(context).uiDetails;
    final totalWidth = constraints.maxWidth;
    final totalHeight =
        constraints.maxHeight.isFinite && constraints.maxHeight > 120
        ? constraints.maxHeight
        : MediaQuery.sizeOf(context).height;
    final compactSize = Size(totalWidth, totalHeight);
    final previousSize = _lastCompactSize;
    if (previousSize == null ||
        (previousSize.width - compactSize.width).abs() > 1 ||
        (previousSize.height - compactSize.height).abs() > 1 ||
        _lastCompactHandleLabel != label) {
      _compactHandleOffset = null;
      _lastCompactSize = compactSize;
      _lastCompactHandleLabel = label;
    }
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final handleWidth = _compactHandleWidth(label, totalWidth);
    const handleHeight = 44.0;
    final defaultOffset = Offset(
      math.max(12, totalWidth - handleWidth - 12),
      math.max(
        12,
        totalHeight -
            handleHeight -
            widget.compactHandleBottomInset -
            bottomPadding,
      ),
    );
    if ((_compactHandleOffset?.dy ?? 0) <= 12 && defaultOffset.dy > 120) {
      _compactHandleOffset = null;
    }
    final offset = _clampCompactHandleOffset(
      _compactHandleOffset ?? defaultOffset,
      totalWidth,
      totalHeight,
      handleWidth,
      handleHeight,
    );
    _compactHandleOffset = offset;

    return Stack(
      children: [
        widget.left,
        Positioned(
          left: offset.dx,
          top: offset.dy,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _compactHandleOffset = _clampCompactHandleOffset(
                  (_compactHandleOffset ?? offset) + details.delta,
                  totalWidth,
                  totalHeight,
                  handleWidth,
                  handleHeight,
                );
              });
            },
            onPanEnd: (_) {
              final current = _compactHandleOffset ?? offset;
              final snappedX = current.dx + handleWidth / 2 < totalWidth / 2
                  ? 12.0
                  : math.max(12.0, totalWidth - handleWidth - 12);
              setState(() {
                _compactHandleOffset = _clampCompactHandleOffset(
                  Offset(snappedX, current.dy),
                  totalWidth,
                  totalHeight,
                  handleWidth,
                  handleHeight,
                );
              });
            },
            child: _CompactPaneHandle(
              width: handleWidth,
              icon: widget.compactRightIcon,
              label: label,
              onTap: showRightPane,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactBackButton(BoxConstraints constraints) {
    final totalWidth = constraints.maxWidth;
    final totalHeight =
        constraints.maxHeight.isFinite && constraints.maxHeight > 120
        ? constraints.maxHeight
        : MediaQuery.sizeOf(context).height;
    final compactSize = Size(totalWidth, totalHeight);
    final previousSize = _lastCompactBackSize;
    if (previousSize == null ||
        (previousSize.width - compactSize.width).abs() > 1 ||
        (previousSize.height - compactSize.height).abs() > 1) {
      _compactBackOffset = null;
      _lastCompactBackSize = compactSize;
    }

    const buttonSize = 44.0;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final defaultOffset = Offset(
      12,
      math.max(12, totalHeight - buttonSize - 12 - bottomPadding),
    );
    final offset = _clampCompactHandleOffset(
      _compactBackOffset ?? defaultOffset,
      totalWidth,
      totalHeight,
      buttonSize,
      buttonSize,
    );
    _compactBackOffset = offset;

    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _compactBackOffset = _clampCompactHandleOffset(
              (_compactBackOffset ?? offset) + details.delta,
              totalWidth,
              totalHeight,
              buttonSize,
              buttonSize,
            );
          });
        },
        child: _BackButton(onTap: _goBackFromRight),
      ),
    );
  }

  void _goBackFromRight() {
    showLeftPane();
  }

  double _compactHandleWidth(String label, double totalWidth) {
    if (totalWidth < 340) return 48;
    final labelWidth = label.length * 7.5 + 58;
    return labelWidth
        .clamp(86.0, math.min(136.0, math.max(86.0, totalWidth - 24)))
        .toDouble();
  }

  Offset _clampCompactHandleOffset(
    Offset offset,
    double totalWidth,
    double totalHeight,
    double handleWidth,
    double handleHeight,
  ) {
    final maxX = math.max(12.0, totalWidth - handleWidth - 12);
    final maxY = math.max(12.0, totalHeight - handleHeight - 12);
    return Offset(
      offset.dx.clamp(12.0, maxX).toDouble(),
      offset.dy.clamp(12.0, maxY).toDouble(),
    );
  }
}

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
    return Tooltip(
      message: AppLocalizations.of(context).uiBack,
      child: Material(
        color: AppTheme.surfaceBright.withValues(alpha: 0.9),
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
