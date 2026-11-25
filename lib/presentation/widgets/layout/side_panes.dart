import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';

/// A main pane with optional side panes, each behind a divider that drags
/// to resize and double-clicks back to its default width.
///
/// A side pane's width lives in [leftWidth] / [rightWidth] (null = the
/// default), so it lasts while the app runs, across rebuilds and pages.
class SidePaneRow extends ConsumerWidget {
  const SidePaneRow({
    super.key,
    required this.center,
    this.left,
    this.leftWidth,
    this.leftDefault = 280,
    this.right,
    this.rightWidth,
    this.rightDefault = 400,
    this.minSide = 200,
    this.minCenter = 320,
  }) : assert(left == null || leftWidth != null),
       assert(right == null || rightWidth != null);

  final Widget center;
  final Widget? left;
  final StateProvider<double?>? leftWidth;
  final double leftDefault;
  final Widget? right;
  final StateProvider<double?>? rightWidth;
  final double rightDefault;
  final double minSide;

  /// The main pane keeps at least this much room.
  final double minCenter;

  static const double _divider = 9;

  @override
  Widget build(BuildContext context, WidgetRef ref) => LayoutBuilder(
    builder: (context, constraints) {
      final total = constraints.maxWidth;
      double read(StateProvider<double?>? p, double fallback) =>
          p == null ? 0 : ref.watch(p) ?? fallback;
      // Each side keeps at most half the row and leaves the main pane its
      // room beside the other side.
      double maxOf(double other) => (total - minCenter - other - 2 * _divider)
          .clamp(minSide, (total / 2).clamp(minSide, double.infinity))
          .toDouble();
      final rightWanted = right == null ? 0.0 : read(rightWidth, rightDefault);
      final leftNow = left == null
          ? 0.0
          : read(leftWidth, leftDefault).clamp(minSide, maxOf(rightWanted));
      final rightNow = right == null
          ? 0.0
          : rightWanted.clamp(minSide, maxOf(leftNow));

      void drag(StateProvider<double?> p, double base, double dx, double max) =>
          ref.read(p.notifier).state = ((ref.read(p) ?? base) + dx).clamp(
            minSide,
            max,
          );

      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (left case final pane?) ...[
            SizedBox(width: leftNow, child: pane),
            PaneDivider(
              onDrag: (dx) =>
                  drag(leftWidth!, leftDefault, dx, maxOf(rightNow)),
              onReset: () => ref.read(leftWidth!.notifier).state = null,
            ),
          ],
          Expanded(child: center),
          if (right case final pane?) ...[
            PaneDivider(
              onDrag: (dx) =>
                  drag(rightWidth!, rightDefault, -dx, maxOf(leftNow)),
              onReset: () => ref.read(rightWidth!.notifier).state = null,
            ),
            SizedBox(width: rightNow, child: pane),
          ],
        ],
      );
    },
  );
}

/// A thin vertical line that widens on hover; drag it to resize the pane
/// beside it, double-click to restore.
class PaneDivider extends StatefulWidget {
  const PaneDivider({super.key, required this.onDrag, required this.onReset});
  final ValueChanged<double> onDrag;
  final VoidCallback onReset;

  @override
  State<PaneDivider> createState() => _PaneDividerState();
}

class _PaneDividerState extends State<PaneDivider> {
  bool _hot = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final active = _hot || _dragging;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hot = true),
      onExit: (_) => setState(() => _hot = false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (_) => setState(() => _dragging = true),
        onHorizontalDragUpdate: (d) => widget.onDrag(d.delta.dx),
        onHorizontalDragEnd: (_) => setState(() => _dragging = false),
        onDoubleTap: widget.onReset,
        child: SizedBox(
          width: SidePaneRow._divider,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: active ? 3 : 1,
              color: active
                  ? AppTheme.accentColor.withValues(alpha: 0.7)
                  : Theme.of(context).dividerColor,
            ),
          ),
        ),
      ),
    );
  }
}
