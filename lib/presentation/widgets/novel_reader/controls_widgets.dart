part of '../../screens/novel_reader_screen.dart';

// Slider, time text and buttons of the reader's bottom bar.

class _ReaderPlaybackSlider extends ConsumerWidget {
  final bool enabled;

  const _ReaderPlaybackSlider({required this.enabled});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timing = ref.watch(
      playbackNotifierProvider.select(
        (state) => (position: state.position, duration: state.duration),
      ),
    );
    final durMs = timing.duration.inMilliseconds;
    final posMs = timing.position.inMilliseconds.clamp(
      0,
      durMs == 0 ? 1 : durMs,
    );
    final notifier = ref.read(playbackNotifierProvider.notifier);

    return ExcludeSemantics(
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 3,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 11),
        ),
        child: Slider(
          min: 0,
          max: durMs == 0 ? 1 : durMs.toDouble(),
          value: posMs.toDouble(),
          onChanged: !enabled || durMs == 0
              ? null
              : (v) => notifier.seek(Duration(milliseconds: v.toInt())),
        ),
      ),
    );
  }
}

class _ReaderPlaybackTimeText extends ConsumerWidget {
  final _ReaderColors colors;

  const _ReaderPlaybackTimeText({required this.colors});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timing = ref.watch(
      playbackNotifierProvider.select(
        (state) => (position: state.position, duration: state.duration),
      ),
    );
    return ExcludeSemantics(
      child: Text(
        '${_fmt(timing.position)} / ${_fmt(timing.duration)}',
        textAlign: TextAlign.end,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          color: colors.muted,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _ReaderIdleStatusText extends StatelessWidget {
  final String text;
  final _ReaderColors colors;
  final TextAlign? textAlign;

  const _ReaderIdleStatusText({
    required this.text,
    required this.colors,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11,
        color: colors.muted,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

class _ReaderControlButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool compact;
  final bool ultraCompact;

  const _ReaderControlButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.compact = false,
    this.ultraCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final dimension = ultraCompact
        ? 32.0
        : compact
        ? 36.0
        : 48.0;
    final iconSize = ultraCompact
        ? 19.0
        : compact
        ? 21.0
        : 24.0;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: ultraCompact
            ? 0
            : compact
            ? 1
            : 3,
      ),
      child: SizedBox.square(
        dimension: dimension,
        child: IconButton.filledTonal(
          tooltip: tooltip,
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          iconSize: iconSize,
          style: IconButton.styleFrom(
            minimumSize: Size.square(dimension),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: Icon(icon),
        ),
      ),
    );
  }
}

class _ReaderToggleButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback? onPressed;
  final bool compact;
  final bool ultraCompact;

  const _ReaderToggleButton({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.onPressed,
    this.compact = false,
    this.ultraCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final dimension = ultraCompact
        ? 32.0
        : compact
        ? 36.0
        : 48.0;
    final iconSize = ultraCompact
        ? 19.0
        : compact
        ? 21.0
        : 24.0;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: ultraCompact
            ? 0
            : compact
            ? 1
            : 3,
      ),
      child: SizedBox.square(
        dimension: dimension,
        child: IconButton(
          tooltip: tooltip,
          isSelected: selected,
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          iconSize: iconSize,
          icon: Icon(icon),
          selectedIcon: Icon(icon),
          style: IconButton.styleFrom(
            backgroundColor: selected
                ? AppTheme.accentColor.withValues(alpha: 0.22)
                : null,
            foregroundColor: selected ? AppTheme.accentColor : null,
            minimumSize: Size.square(dimension),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
    );
  }
}
