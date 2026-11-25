import 'package:flutter/material.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';

class RecordingIndicator extends StatelessWidget {
  const RecordingIndicator({
    super.key,
    required this.active,
    required this.level,
    required this.pulse,
    required this.status,
  });
  final bool active;
  final double level;
  final Animation<double> pulse;
  final String status;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: context.colors.raised,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: pulse,
            builder: (context, child) {
              final t = active ? pulse.value : 0.0;
              return Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.colors.danger.withValues(
                    alpha: 0.10 + t * 0.18,
                  ),
                ),
                child: Center(
                  child: Transform.scale(
                    scale: active ? 0.75 + t * 0.25 : 0.75,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: active
                            ? context.colors.danger
                            : context.fg.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 13,
                    color: active
                        ? context.colors.danger
                        : context.fg.withValues(alpha: 0.58),
                  ),
                ),
                SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 5,
                    child: Stack(
                      children: [
                        Container(color: context.fg.withValues(alpha: 0.08)),
                        FractionallySizedBox(
                          widthFactor: level,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.accentColor,
                                  level > 0.85
                                      ? context.colors.danger
                                      : AppTheme.accentColor.withValues(
                                          alpha: 0.72,
                                        ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RecordingTimerRow extends StatelessWidget {
  const RecordingTimerRow({
    super.key,
    required this.status,
    required this.time,
    required this.recording,
  });
  final String status;
  final String time;
  final bool recording;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        status,
        style: TextStyle(
          fontSize: 12,
          color: recording
              ? context.colors.danger
              : context.fg.withValues(alpha: 0.54),
        ),
      ),
      Text(
        time,
        style: const TextStyle(
          fontSize: 13,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    ],
  );
}
