// Realtime replies with voice conversion: the reply audio is cut at pauses
// and each phrase is converted while the next one is still arriving.
// The live case runs against a real RVC server when RVC_URL answers:
//
//   set -a; source .env; set +a   # RVC_URL=http://hedt:19001
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/providers/local/rvc/rvc_client.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/registry/plugin_registry.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/ai/core/tts_adapter.dart';
import 'package:neiroha/data/ai/protocols/audio/wav_utils.dart';
import 'package:neiroha/data/services/conversation/reply_player.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/synthesis/pcm_segmenter.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';

import 'support/fake_conversation_audio.dart';

const _rate = 24000;
const _format = TtsAudioFormat(
  AudioEncoding.pcmS16le,
  sampleRate: _rate,
  channels: 1,
);

/// (ms, amplitude) parts of a tone or silence at 24 kHz.
Uint8List _pcm(List<(int, double)> parts) {
  final out = BytesBuilder();
  for (final (ms, a) in parts) {
    final data = ByteData(_rate * ms ~/ 1000 * 2);
    for (var i = 0; i < data.lengthInBytes ~/ 2; i++) {
      data.setInt16(
        i * 2,
        (a * 20000 * math.sin(2 * math.pi * 220 * i / _rate)).round(),
        Endian.little,
      );
    }
    out.add(data.buffer.asUint8List());
  }
  return out.takeBytes();
}

int _ms(int bytes) => bytes * 1000 ~/ (_rate * 2);

class _Vc implements StreamingVoiceConverter {
  final clips = <int>[];
  Completer<void>? gate;
  @override
  ModelDescriptor get descriptor => const ModelDescriptor(
    id: 'vc',
    capability: AiCapability.vc,
    protocol: AiProtocol.native,
  );
  @override
  Future<TtsResult> convert(
    AudioInput audio, {
    required String targetVoice,
    TtsCancelToken? cancellation,
  }) => throw UnimplementedError();
  @override
  Stream<TtsEvent> convertStream(
    AudioInput audio, {
    required String targetVoice,
    required TtsCancelToken cancellation,
  }) async* {
    final wav = parsePcmWav(audio.bytes);
    clips.add(_ms(wav.pcm.length));
    await gate?.future;
    yield TtsAudioStarted(_format);
    yield TtsAudioChunk(wav.pcm);
    yield const TtsSynthesisCompleted();
  }
}

Future<String?> _rvcSkip(String? url) async {
  if (url == null || url.trim().isEmpty) return 'RVC_URL not set';
  try {
    return await RvcClient(baseUrl: url).health() ? null : 'RVC unhealthy';
  } catch (_) {
    return 'RVC unreachable';
  }
}

Future<void> main() async {
  final rvcUrl = Platform.environment['RVC_URL'];
  final rvcSkip = await _rvcSkip(rvcUrl);

  group('PcmSegmenter', () {
    test('cuts in the first pause after the minimum length', () {
      final s = PcmSegmenter(sampleRate: _rate);
      final clips = s.add(_pcm([(1500, 0.5), (200, 0), (900, 0.5)]));
      expect(clips, hasLength(1));
      // 1.5 s of speech plus about half the pause.
      expect(_ms(clips.single.length), inInclusiveRange(1550, 1650));
      expect(_ms(s.flush()!.length), inInclusiveRange(950, 1050));
      expect(s.flush(), isNull);
    });

    test('pauses before the minimum do not cut; long speech cuts hard', () {
      final s = PcmSegmenter(sampleRate: _rate);
      expect(s.add(_pcm([(500, 0.5), (200, 0), (400, 0.5)])), isEmpty);
      final clips = s.add(_pcm([(4000, 0.5)]));
      expect(clips.map((c) => _ms(c.length)), [4000]);
    });

    test('audio arriving in small deltas is cut the same way', () {
      final s = PcmSegmenter(sampleRate: _rate);
      final all = _pcm([(1500, 0.5), (200, 0), (900, 0.5)]);
      final clips = <Uint8List>[];
      for (var at = 0; at < all.length; at += 960) {
        clips.addAll(
          s.add(Uint8List.sublistView(all, at, math.min(at + 960, all.length))),
        );
      }
      expect(clips, hasLength(1));
      expect(_ms(clips.single.length), inInclusiveRange(1550, 1650));
    });
  });

  group('ReplyPlayer with VC', () {
    test('the first phrase plays before the reply is complete', () async {
      final io = FakeConversationAudio();
      final vc = _Vc();
      final player = ReplyPlayer(
        io,
        conversion: VoiceConversionStage(vc, 'kikiV1'),
      );
      await player.begin(_format);
      expect(player.convertsWholeReply, isFalse);
      await player.add(_pcm([(1500, 0.5), (200, 0)]));
      await pumpEventQueue();
      expect(vc.clips, hasLength(1));
      expect(io.sinks.single.bytes.length, greaterThan(0));
      await player.add(_pcm([(900, 0.5)]));
      await player.end();
      expect(vc.clips, hasLength(2));
      expect(_ms(io.sinks.single.bytes.length), inInclusiveRange(2550, 2650));
    });

    test('barge-in stops conversion without stray errors', () async {
      final io = FakeConversationAudio();
      final vc = _Vc()..gate = Completer<void>();
      final player = ReplyPlayer(
        io,
        conversion: VoiceConversionStage(vc, 'kikiV1'),
      );
      await player.begin(_format);
      await player.add(_pcm([(1500, 0.5), (200, 0), (500, 0.5)]));
      await pumpEventQueue();
      await player.stop();
      vc.gate!.complete();
      await pumpEventQueue();
      expect(player.active, isFalse);
      // A fresh reply after the barge-in works.
      await player.begin(_format);
      await player.add(_pcm([(300, 0.5)]));
      await player.end();
      expect(vc.clips.last, 300);
    });

    test('encoded replies are still converted whole', () async {
      final io = FakeConversationAudio();
      final player = ReplyPlayer(
        io,
        conversion: VoiceConversionStage(_Vc(), 'kikiV1'),
      );
      await player.begin(const TtsAudioFormat(AudioEncoding.mp3));
      expect(player.convertsWholeReply, isTrue);
      await player.stop();
    });
  });

  test(
    'live RVC: converted speech plays before the reply ends',
    () async {
      final io = FakeConversationAudio();
      final vc = connectionForProvider(
        db.TtsProvider(
          id: 'rvc',
          name: 'RVC',
          adapterType: 'rvc',
          baseUrl: rvcUrl!,
          apiKey: '',
          defaultModelName: 'auto',
          enabled: true,
          position: 0,
          maxConcurrency: 1,
        ),
      ).voiceConverter()!;
      final player = ReplyPlayer(
        io,
        conversion: VoiceConversionStage(vc, 'kikiV1'),
      );
      final clock = Stopwatch()..start();
      await player.begin(_format);
      // Three phrases arriving at real time, 100 ms per delta.
      final reply = _pcm([
        (1500, 0.5),
        (250, 0),
        (1500, 0.5),
        (250, 0),
        (1500, 0.5),
      ]);
      Duration? firstAudio;
      const delta = _rate * 2 ~/ 10;
      for (var at = 0; at < reply.length; at += delta) {
        await player.add(
          Uint8List.sublistView(reply, at, math.min(at + delta, reply.length)),
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (io.sinks.isNotEmpty && io.sinks.first.bytes.length > 0) {
          firstAudio ??= clock.elapsed;
        }
      }
      final replyDone = clock.elapsed;
      await player.end();
      // ignore: avoid_print
      print(
        'RVC phrases: first audio ${firstAudio?.inMilliseconds} ms, reply '
        'ended ${replyDone.inMilliseconds} ms, done '
        '${clock.elapsed.inMilliseconds} ms',
      );
      expect(firstAudio, isNotNull);
      expect(firstAudio!, lessThan(replyDone));
      expect(io.sinks.single.bytes.length, greaterThan(_rate * 2 * 4));
    },
    timeout: const Timeout(Duration(minutes: 2)),
    skip: rvcSkip,
  );
}
