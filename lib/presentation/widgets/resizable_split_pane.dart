import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neiroha/presentation/navigation/app_navigation.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

part 'split_pane_handles.dart';
part 'split_pane_simple.dart';

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
          if (!didPop) {
            AppBackIntent.markChildHandled();
            _goBackFromRight();
          }
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
              onTap: () => showRightPane(onlyWhenCompact: true),
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
    showLeftPane(onlyWhenCompact: _isCompactLayout);
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
