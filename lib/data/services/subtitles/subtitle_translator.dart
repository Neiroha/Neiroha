import 'package:neiroha/domain/ai/models/language_model.dart';
import 'package:neiroha/domain/llm/llm_contract.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';

/// Translates subtitle lines with an LLM in numbered batches, keeping one
/// output line per input line so timings stay aligned.
class SubtitleTranslator {
  const SubtitleTranslator(this.model, {this.batchSize = 40});
  final LanguageModel model;
  final int batchSize;

  static const _schema = {
    'type': 'object',
    'properties': {
      'lines': {
        'type': 'array',
        'items': {'type': 'string'},
      },
    },
    'required': ['lines'],
    'additionalProperties': false,
  };

  Future<List<String>> translate(
    List<String> lines, {
    required String targetLanguage,
    String context = '',
    TtsCancelToken? cancellation,
    void Function(int done, int total)? onProgress,
  }) async {
    final out = <String>[];
    for (var i = 0; i < lines.length; i += batchSize) {
      cancellation?.throwIfCancelled();
      final batch = lines.sublist(
        i,
        i + batchSize > lines.length ? lines.length : i + batchSize,
      );
      out.addAll(await _batch(batch, targetLanguage, context, cancellation));
      onProgress?.call(out.length, lines.length);
    }
    return out;
  }

  Future<List<String>> _batch(
    List<String> batch,
    String target,
    String context,
    TtsCancelToken? cancellation,
  ) async {
    final numbered = [
      for (var i = 0; i < batch.length; i++) '${i + 1}. ${batch[i]}',
    ].join('\n');
    for (var attempt = 0; attempt < 2; attempt++) {
      final result = await model.structured(
        [
          LlmChatMessage(
            role: 'system',
            content:
                'You translate subtitles into $target. Return exactly '
                '${batch.length} lines in "lines", one per numbered input, '
                'same order, without the numbers. Keep names, tone and '
                'line breaks natural for subtitles; never merge or split '
                'lines.${context.isEmpty ? '' : '\nContext: $context'}',
          ),
          LlmChatMessage(role: 'user', content: numbered),
        ],
        schemaName: 'subtitle_translation',
        schema: _schema,
        cancellation: cancellation,
      );
      final lines = (result.object['lines'] as List? ?? const [])
          .map((e) => '$e'.trim())
          .toList();
      if (lines.length == batch.length) return lines;
    }
    throw StateError(
      'The model did not return one translation per subtitle line.',
    );
  }
}
