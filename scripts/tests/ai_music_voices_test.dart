import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/providers/azure_speech/tts/azure_tts_adapter.dart';
import 'package:neiroha/data/ai/providers/gemini/gemini_endpoint.dart';
import 'package:neiroha/data/ai/providers/gemini/music/gemini_music_generator.dart';
import 'package:neiroha/data/ai/providers/gemini/music/lyria_lyrics.dart';
import 'package:neiroha/data/ai/providers/gemini/tts/gemini_tts_adapter.dart';
import 'package:neiroha/data/ai/registry/built_in_voices.dart';
import 'package:neiroha/data/ai/registry/plugin_registry.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/widgets/voice_chip_list.dart';

void main() {
  group('Lyria lyrics', () {
    test('clip format: timed lines → LRC', () {
      final lines = parseLyriaLyrics('[1.5:6.0] 晨光洒在港口\n[6.0:12.0] 长门守护着你');
      expect(lines.map((l) => l.text), ['晨光洒在港口', '长门守护着你']);
      expect(lines.first.start, const Duration(milliseconds: 1500));
      expect(lines.last.end, const Duration(seconds: 12));
      expect(
        lyricsToLrc(lines, title: 'Port'),
        '[ti:Port]\n[00:01.50]晨光洒在港口\n[00:06.00]长门守护着你',
      );
    });

    test('3.5 format: sections, untimed lines, no LRC', () {
      final lines = parseLyriaLyrics(
        '[[A0]]\n[[B1]]\n[:] 夜色温柔\n[:] 星光如眸\n[[C2]]\n[:] 吾在此守候',
      );
      expect(lines.map((l) => (l.text, l.section)), [
        ('夜色温柔', 'B1'),
        ('星光如眸', 'B1'),
        ('吾在此守候', 'C2'),
      ]);
      expect(lines.every((l) => l.start == null), isTrue);
      expect(lyricsToLrc(lines), isNull);
      expect(parseLyriaLyrics('[[A0]]\n[[B1]]'), isEmpty); // instrumental
    });
  });

  group('Gemini music', () {
    final connection = connectionForProvider(
      db.TtsProvider(
        id: 'g',
        name: 'Gemini',
        adapterType: AdapterType.geminiTts.name,
        baseUrl: '',
        apiKey: 'k',
        defaultModelName: AdapterType.geminiTts.defaultModel,
        enabled: true,
        position: 0,
        maxConcurrency: 1,
      ),
    );

    test('catalog mounts Lyria with 3.5 as default', () {
      expect(connection.capabilities, contains(AiCapability.music));
      expect(connection.musicGenerator()!.descriptor.id, 'lyria-3.5');
      expect(connection.models(AiCapability.music).map((m) => m.id), [
        'lyria-3.5',
        'lyria-3-pro-preview',
        'lyria-3-clip-preview',
      ]);
    });

    test(
      'request: lyrics, instrumental, images and WAV only where offered',
      () {
        final full = connection.musicGenerator()! as GeminiMusicGenerator;
        final image = (Uint8List.fromList([1, 2]), 'image/png');
        final body = full.body(
          MusicRequest(
            prompt: 'Ballad.',
            lyrics: '[Verse]\nhi',
            images: [image],
          ),
        );
        final input = body['input'] as List;
        expect(input.first['text'], 'Ballad.\n\nLyrics:\n[Verse]\nhi');
        expect(input.last, {
          'type': 'image',
          'mime_type': 'image/png',
          'data': 'AQI=',
        });
        expect(body['response_format'], {
          'type': 'audio',
          'mime_type': 'audio/wav',
        });
        final clip = GeminiMusicGenerator(
          connection.describe(AiCapability.music, 'lyria-3-clip-preview')!,
          GeminiEndpoint('', 'k'),
        );
        final plain = clip.body(
          const MusicRequest(
            prompt: 'Rock.',
            lyrics: 'ignored',
            instrumental: true,
          ),
        );
        expect(plain['input'], 'Rock.\n\nInstrumental only, no vocals.');
        expect(plain.containsKey('response_format'), isFalse);
      },
    );

    test('response: lyrics step + audio step', () {
      final song = GeminiMusicGenerator.parse({
        'status': 'completed',
        'steps': [
          {
            'type': 'model_output',
            'content': [
              {'type': 'text', 'text': '[0.0:2.0] la'},
            ],
          },
          {
            'type': 'model_output',
            'content': [
              {
                'type': 'audio',
                'mime_type': 'audio/wav',
                'data': base64Encode([7, 8]),
              },
            ],
          },
        ],
      });
      expect(song.audio, [7, 8]);
      expect(song.extension, '.wav');
      expect(song.timed, isTrue);
      expect(
        () => GeminiMusicGenerator.parse({'status': 'failed', 'steps': []}),
        throwsA(isA<AiProviderException>()),
      );
    });
  });

  test('built-in voices follow the TTS model', () {
    expect(
      builtInVoicesFor(AdapterType.geminiTts, 'gemini-3.8-flash-tts'),
      GeminiTtsAdapter.kPrebuiltVoices,
    );
    expect(
      builtInVoicesFor(AdapterType.geminiTts, 'gemini-3.8-flash'),
      isEmpty,
    );
    expect(
      builtInVoicesFor(AdapterType.openaiTts, 'tts-1'),
      isNot(contains('marin')),
    );
    expect(
      builtInVoicesFor(AdapterType.openaiTts, 'gpt-4o-mini-tts'),
      contains('marin'),
    );
    expect(
      builtInVoicesFor(AdapterType.chatCompletionsTts, 'mimo-v2.5-tts'),
      contains('冰糖'),
    );
    expect(
      builtInVoicesFor(
        AdapterType.chatCompletionsTts,
        'mimo-v2.5-tts-voiceclone',
      ),
      isEmpty,
    );
    expect(builtInVoicesFor(AdapterType.azureTts, ''), isEmpty);
  });

  test('Azure SSML language follows the voice', () {
    expect(AzureTtsAdapter.localeOf('zh-CN-XiaoxiaoNeural'), 'zh-CN');
    expect(AzureTtsAdapter.localeOf('en-US-AvaMultilingualNeural'), 'en-US');
    expect(AzureTtsAdapter.localeOf('yue-CN-XiaoMinNeural'), 'yue-CN');
    expect(AzureTtsAdapter.localeOf('custom'), 'en-US');
  });

  testWidgets('voice group collapses, filters and caps long lists', (t) async {
    final removed = <String>[];
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: VoiceGroupRow(
              title: 'Azure Speech voices',
              voices: [
                for (var i = 0; i < 300; i++)
                  (
                    label: i == 7 ? 'zh-CN-XiaoxiaoNeural' : 'en-US-V$i',
                    id: '$i',
                  ),
              ],
              onDelete: removed.add,
            ),
          ),
        ),
      ),
    );
    expect(find.text('zh-CN-XiaoxiaoNeural'), findsNothing); // collapsed
    await t.tap(find.text('Azure Speech voices'));
    await t.pumpAndSettle();
    expect(find.text('en-US-V150'), findsNothing); // capped at 120
    await t.enterText(find.byType(TextField), 'xiaoxiao');
    await t.pumpAndSettle();
    expect(find.text('zh-CN-XiaoxiaoNeural'), findsOneWidget);
    expect(find.text('en-US-V8'), findsNothing);
    await t.tap(find.byIcon(Icons.close_rounded));
    expect(removed, ['7']);
  });
}
