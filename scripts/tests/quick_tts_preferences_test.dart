import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/app_database.dart';

void main() {
  test(
    'preview preference defaults to streaming and is scoped to the role',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await database.insertProvider(
        TtsProvidersCompanion.insert(
          id: 'provider',
          name: 'Provider',
          adapterType: 'openaiTts',
          baseUrl: '',
        ),
      );
      for (final id in ['narrator', 'dialogue']) {
        await database.insertVoiceAsset(
          VoiceAssetsCompanion.insert(
            id: id,
            name: id,
            providerId: 'provider',
            taskMode: 'presetVoice',
          ),
        );
      }
      expect(await database.watchQuickTtsStreaming('narrator').first, isTrue);
      await database.setQuickTtsStreaming('narrator', false);
      expect(await database.watchQuickTtsStreaming('narrator').first, isFalse);
      expect(await database.watchQuickTtsStreaming('dialogue').first, isTrue);
      await database.setQuickTtsStreaming('narrator', true);
      expect(await database.watchQuickTtsStreaming('narrator').first, isTrue);
      await database.setQuickTtsStreaming('narrator', false);
      await database.deleteVoiceAsset('narrator');
      await database.setQuickTtsStreaming('narrator', false);
      expect(await database.watchQuickTtsStreaming('narrator').first, isTrue);
    },
  );
}
