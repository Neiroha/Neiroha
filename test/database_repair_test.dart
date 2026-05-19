import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/storage/storage_service.dart';

void main() {
  test(
    'repairs current-version databases that are missing late columns',
    () async {
      final database = db.AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: (sqlite) {
            sqlite
              ..execute('''
              CREATE TABLE "tts_providers" (
                "id" TEXT NOT NULL,
                "name" TEXT NOT NULL,
                "adapter_type" TEXT NOT NULL,
                "base_url" TEXT NOT NULL,
                "api_key" TEXT NOT NULL DEFAULT '',
                "default_model_name" TEXT NOT NULL DEFAULT 'tts-1',
                "enabled" INTEGER NOT NULL DEFAULT 0,
                "position" INTEGER NOT NULL DEFAULT 0,
                PRIMARY KEY ("id")
              );
            ''')
              ..execute('''
              CREATE TABLE "voice_assets" (
                "id" TEXT NOT NULL,
                "name" TEXT NOT NULL,
                "description" TEXT NULL,
                "provider_id" TEXT NOT NULL REFERENCES tts_providers (id),
                "model_binding_id" TEXT NULL,
                "model_name" TEXT NULL,
                "task_mode" TEXT NOT NULL,
                "ref_audio_path" TEXT NULL,
                "ref_audio_trim_start" REAL NULL,
                "ref_audio_trim_end" REAL NULL,
                "prompt_text" TEXT NULL,
                "prompt_lang" TEXT NULL,
                "voice_instruction" TEXT NULL,
                "preset_voice_name" TEXT NULL,
                "avatar_path" TEXT NULL,
                "speed" REAL NOT NULL DEFAULT 1.0,
                "enabled" INTEGER NOT NULL DEFAULT 1,
                PRIMARY KEY ("id")
              );
            ''')
              ..execute('''
              CREATE TABLE "quick_tts_histories" (
                "id" TEXT NOT NULL,
                "voice_asset_id" TEXT NOT NULL REFERENCES voice_assets (id),
                "voice_name" TEXT NOT NULL,
                "input_text" TEXT NOT NULL,
                "audio_path" TEXT NULL,
                "audio_duration" REAL NULL,
                "error" TEXT NULL,
                "created_at" INTEGER NOT NULL,
                PRIMARY KEY ("id")
              );
            ''')
              ..execute('''
              CREATE TABLE "phase_tts_projects" (
                "id" TEXT NOT NULL,
                "name" TEXT NOT NULL,
                "bank_id" TEXT NOT NULL,
                "script_text" TEXT NOT NULL DEFAULT '',
                "created_at" INTEGER NOT NULL,
                "updated_at" INTEGER NOT NULL,
                PRIMARY KEY ("id")
              );
            ''')
              ..execute('''
              CREATE TABLE "phase_tts_segments" (
                "id" TEXT NOT NULL,
                "project_id" TEXT NOT NULL REFERENCES phase_tts_projects (id),
                "order_index" INTEGER NOT NULL,
                "segment_text" TEXT NOT NULL,
                "voice_asset_id" TEXT NULL,
                "audio_path" TEXT NULL,
                "audio_duration" REAL NULL,
                "error" TEXT NULL,
                "speaker_label" TEXT NULL,
                PRIMARY KEY ("id")
              );
            ''')
              ..execute('''
              CREATE TABLE "dialog_tts_projects" (
                "id" TEXT NOT NULL,
                "name" TEXT NOT NULL,
                "bank_id" TEXT NOT NULL,
                "created_at" INTEGER NOT NULL,
                "updated_at" INTEGER NOT NULL,
                PRIMARY KEY ("id")
              );
            ''')
              ..execute('''
              CREATE TABLE "dialog_tts_lines" (
                "id" TEXT NOT NULL,
                "project_id" TEXT NOT NULL REFERENCES dialog_tts_projects (id),
                "order_index" INTEGER NOT NULL,
                "line_text" TEXT NOT NULL,
                "voice_asset_id" TEXT NULL,
                "audio_path" TEXT NULL,
                "audio_duration" REAL NULL,
                "error" TEXT NULL,
                PRIMARY KEY ("id")
              );
            ''')
              ..execute('''
              CREATE TABLE "audio_tracks" (
                "id" TEXT NOT NULL,
                "name" TEXT NOT NULL,
                "description" TEXT NULL,
                "audio_path" TEXT NOT NULL,
                "avatar_path" TEXT NULL,
                "ref_text" TEXT NULL,
                "ref_lang" TEXT NULL,
                "duration_sec" REAL NULL,
                "source_type" TEXT NOT NULL DEFAULT 'upload',
                "created_at" INTEGER NOT NULL,
                PRIMARY KEY ("id")
              );
            ''')
              ..execute('''
              CREATE TABLE "timeline_clips" (
                "id" TEXT NOT NULL,
                "project_id" TEXT NOT NULL,
                "project_type" TEXT NOT NULL,
                "lane_index" INTEGER NOT NULL DEFAULT 0,
                "start_time_ms" INTEGER NOT NULL DEFAULT 0,
                "duration_sec" REAL NULL,
                "audio_path" TEXT NOT NULL,
                "source_type" TEXT NOT NULL DEFAULT 'generated',
                "source_line_id" TEXT NULL,
                "label" TEXT NOT NULL DEFAULT '',
                PRIMARY KEY ("id")
              );
            ''')
              ..execute('''
              INSERT INTO "tts_providers"
                (id, name, adapter_type, base_url, default_model_name, enabled, position)
              VALUES
                ('default-system-tts', 'Windows System TTS', 'systemTts', '', '', 1, 0);
            ''')
              ..execute('''
              INSERT INTO "voice_assets"
                (id, name, provider_id, task_mode, preset_voice_name, prompt_lang, enabled)
              VALUES
                (
                  'voice-1',
                  'Windows System TTS_Microsoft Huihui Desktop',
                  'default-system-tts',
                  'presetVoice',
                  'Microsoft Huihui Desktop',
                  'zh',
                  1
                );
            ''');
            sqlite.userVersion = 26;
          },
        ),
      );
      addTearDown(database.close);

      await database.customSelect('SELECT 1').get();

      Future<Set<String>> columns(String table) async {
        final rows = await database
            .customSelect('PRAGMA table_info($table)')
            .get();
        return rows.map((row) => row.data['name'] as String).toSet();
      }

      expect(await columns('tts_providers'), contains('max_concurrency'));
      expect(await columns('voice_assets'), contains('folder_slug'));
      expect(await columns('quick_tts_histories'), contains('missing'));
      expect(await columns('phase_tts_projects'), contains('folder_slug'));
      expect(await columns('phase_tts_segments'), contains('missing'));
      expect(await columns('dialog_tts_projects'), contains('folder_slug'));
      expect(await columns('dialog_tts_lines'), contains('missing'));
      expect(await columns('audio_tracks'), contains('missing'));
      expect(
        await columns('timeline_clips'),
        containsAll(['missing', 'link_group_id']),
      );

      final slug = await StorageService(
        database,
      ).ensureVoiceAssetSlug('voice-1');
      final asset = await database.getVoiceAssetById('voice-1');

      expect(slug, isNotEmpty);
      expect(asset?.folderSlug, slug);
    },
  );
}
