import 'package:flutter/material.dart';
import 'package:neiroha/data/services/subtitles/subtitle_cue.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';

String formatCueTime(Duration d) {
  String two(int v) => v.toString().padLeft(2, '0');
  final ms = d.inMilliseconds;
  final head = ms >= 3600000 ? '${ms ~/ 3600000}:' : '';
  return '$head${two(ms ~/ 60000 % 60)}:${two(ms ~/ 1000 % 60)}'
      '.${(ms % 1000 ~/ 10).toString().padLeft(2, '0')}';
}

/// Read-only preview of generated cues: time range, original, translation.
class SubtitleCueList extends StatelessWidget {
  const SubtitleCueList({super.key, required this.cues, required this.empty});
  final List<SubtitleCue> cues;
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (cues.isEmpty) {
      return Center(
        child: Text(empty, style: TextStyle(color: context.fg.withAlpha(120))),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: cues.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final c = cues[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: context.colors.raised,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 132,
                child: Text(
                  '${formatCueTime(c.start)} → ${formatCueTime(c.end)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: context.fg.withAlpha(150),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(c.text),
                    if (c.translation?.isNotEmpty ?? false)
                      SelectableText(
                        c.translation!,
                        style: const TextStyle(color: AppTheme.accentColor),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
