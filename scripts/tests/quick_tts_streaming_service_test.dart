import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/synthesis/quick_tts_service.dart';
import 'package:neiroha/data/services/synthesis/synthesis_service.dart';
import 'package:neiroha/data/services/tts_queue_service.dart';
import 'package:neiroha/data/storage/path_service.dart';
import 'package:neiroha/data/storage/storage_service.dart';

void main() {
  test(
    'Quick TTS saves a single complete take under the managed directory and persists duration',
    () async {
      final directory = await Directory.systemTemp.createTemp('quick_tts_');
      PathService.instance.applyVoiceAssetRootOverride(directory.path);
      addTearDown(() async {
        PathService.instance.applyVoiceAssetRootOverride(null);
        await directory.delete(recursive: true);
      });
      final database = db.AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var requests = 0;
      server.listen((request) async {
        requests++;
        final socket = await WebSocketTransformer.upgrade(request);
        socket.listen((event) {
          if (jsonDecode(event as String)['type'] == 'response.create') {
            socket.add(
              jsonEncode({
                'type': 'response.output_audio.delta',
                'delta': base64Encode([1, 0, 2, 0]),
              }),
            );
            socket.add(
              jsonEncode({
                'type': 'response.done',
                'response': {'status': 'completed'},
              }),
            );
          }
        });
      });
      await database.insertProvider(
        db.TtsProvidersCompanion(
          id: const Value('local'),
          name: const Value('Local'),
          adapterType: const Value('openaiTts'),
          baseUrl: Value('http://127.0.0.1:${server.port}/v1'),
          defaultModelName: const Value('gpt-realtime-2.1-mini'),
        ),
      );
      await database.insertVoiceAsset(
        const db.VoiceAssetsCompanion(
          id: Value('voice'),
          name: Value('参考 声音'),
          providerId: Value('local'),
          taskMode: Value('presetVoice'),
          presetVoiceName: Value('marin'),
        ),
      );
      final provider = (await database.getAllProviders()).firstWhere(
        (p) => p.id == 'local',
      );
      final asset = (await database.getVoiceAssetById('voice'))!;
      final service = QuickTtsService(
        database,
        StorageService(database),
        SynthesisService(TtsQueueService.instance),
      );
      final result = await service.generate(
        entryId: 'take',
        asset: asset,
        provider: provider,
        text: '你好',
        cancellation: TtsCancelToken(),
      );
      expect(File(result.audioPath).existsSync(), isTrue);
      expect(
        File(
          result.audioPath,
        ).absolute.path.startsWith(directory.absolute.path),
        isTrue,
      );
      expect(requests, 1);
      final history = await database.watchQuickTtsHistory().first;
      expect(history.single.audioPath, result.audioPath);
      expect(history.single.audioDuration, closeTo(2 / 24000, 0.000001));
      expect(
        directory
            .listSync(recursive: true)
            .where((f) => f.path.endsWith('.partial')),
        isEmpty,
      );
    },
  );
}
