import 'schema_editor.dart';

// Repair tables and rate-limit columns against the frozen v26 schema (68b8d55, c1e70a8).
Future<void> upgradeToV26(SchemaEditor editor) async {
  await editor.ensureTable('app_settings', '''
  CREATE TABLE "app_settings" (
    "key" TEXT NOT NULL,
    "value" TEXT NOT NULL,
    PRIMARY KEY ("key")
  )
  ''');
  await editor.ensureTable('tts_providers', '''
  CREATE TABLE "tts_providers" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "adapter_type" TEXT NOT NULL,
    "base_url" TEXT NOT NULL,
    "api_key" TEXT NOT NULL DEFAULT '',
    "default_model_name" TEXT NOT NULL DEFAULT 'tts-1',
    "enabled" INTEGER NOT NULL DEFAULT 0 CHECK ("enabled" IN (0, 1)),
    "position" INTEGER NOT NULL DEFAULT 0,
    "max_concurrency" INTEGER NOT NULL DEFAULT 1,
    "requests_per_minute" INTEGER NULL,
    "requests_per_day" INTEGER NULL,
    "tokens_per_minute" INTEGER NULL,
    "tokens_per_day" INTEGER NULL,
    PRIMARY KEY ("id")
  )
  ''');
  await editor.ensureTable('model_bindings', '''
  CREATE TABLE "model_bindings" (
    "id" TEXT NOT NULL,
    "provider_id" TEXT NOT NULL REFERENCES tts_providers (id),
    "model_key" TEXT NOT NULL,
    "supported_task_modes" TEXT NOT NULL DEFAULT '',
    PRIMARY KEY ("id")
  )
  ''');
  await editor.ensureTable('voice_assets', '''
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
    "enabled" INTEGER NOT NULL DEFAULT 1 CHECK ("enabled" IN (0, 1)),
    "folder_slug" TEXT NULL,
    PRIMARY KEY ("id")
  )
  ''');
  await editor.ensureTable('voice_banks', '''
  CREATE TABLE "voice_banks" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT NULL,
    "is_active" INTEGER NOT NULL DEFAULT 0 CHECK ("is_active" IN (0, 1)),
    "created_at" INTEGER NOT NULL,
    PRIMARY KEY ("id")
  )
  ''');
  await editor.ensureTable('voice_bank_members', '''
  CREATE TABLE "voice_bank_members" (
    "id" TEXT NOT NULL,
    "bank_id" TEXT NOT NULL REFERENCES voice_banks (id),
    "voice_asset_id" TEXT NOT NULL REFERENCES voice_assets (id),
    PRIMARY KEY ("id")
  )
  ''');
  await editor.ensureTable('tts_jobs', '''
  CREATE TABLE "tts_jobs" (
    "id" TEXT NOT NULL,
    "voice_asset_id" TEXT NOT NULL REFERENCES voice_assets (id),
    "input_text" TEXT NOT NULL,
    "status" TEXT NOT NULL,
    "output_path" TEXT NULL,
    "error_message" TEXT NULL,
    "created_at" INTEGER NOT NULL,
    "completed_at" INTEGER NULL,
    PRIMARY KEY ("id")
  )
  ''');
  await editor.ensureTable('quick_tts_histories', '''
  CREATE TABLE "quick_tts_histories" (
    "id" TEXT NOT NULL,
    "voice_asset_id" TEXT NOT NULL REFERENCES voice_assets (id),
    "voice_name" TEXT NOT NULL,
    "input_text" TEXT NOT NULL,
    "audio_path" TEXT NULL,
    "audio_duration" REAL NULL,
    "error" TEXT NULL,
    "created_at" INTEGER NOT NULL,
    "missing" INTEGER NOT NULL DEFAULT 0 CHECK ("missing" IN (0, 1)),
    PRIMARY KEY ("id")
  )
  ''');
  await editor.ensureTable('phase_tts_projects', '''
  CREATE TABLE "phase_tts_projects" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "bank_id" TEXT NOT NULL REFERENCES voice_banks (id),
    "script_text" TEXT NOT NULL DEFAULT '',
    "created_at" INTEGER NOT NULL,
    "updated_at" INTEGER NOT NULL,
    "folder_slug" TEXT NULL,
    PRIMARY KEY ("id")
  )
  ''');
  await editor.ensureTable('phase_tts_segments', '''
  CREATE TABLE "phase_tts_segments" (
    "id" TEXT NOT NULL,
    "project_id" TEXT NOT NULL REFERENCES phase_tts_projects (id),
    "order_index" INTEGER NOT NULL,
    "segment_text" TEXT NOT NULL,
    "speaker_label" TEXT NULL,
    "voice_asset_id" TEXT NULL,
    "audio_path" TEXT NULL,
    "audio_duration" REAL NULL,
    "error" TEXT NULL,
    "missing" INTEGER NOT NULL DEFAULT 0 CHECK ("missing" IN (0, 1)),
    PRIMARY KEY ("id")
  )
  ''');
  await editor.ensureTable('novel_projects', '''
  CREATE TABLE "novel_projects" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "bank_id" TEXT NOT NULL REFERENCES voice_banks (id),
    "narrator_voice_asset_id" TEXT NULL,
    "dialogue_voice_asset_id" TEXT NULL,
    "reader_theme" TEXT NOT NULL DEFAULT 'dark',
    "font_size" REAL NOT NULL DEFAULT 20.0,
    "line_height" REAL NOT NULL DEFAULT 1.75,
    "auto_turn_page" INTEGER NOT NULL DEFAULT 1 CHECK ("auto_turn_page" IN (0, 1)),
    "auto_advance_chapters" INTEGER NOT NULL DEFAULT 1 CHECK ("auto_advance_chapters" IN (0, 1)),
    "auto_slice_long_segments" INTEGER NOT NULL DEFAULT 1 CHECK ("auto_slice_long_segments" IN (0, 1)),
    "slice_only_at_punctuation" INTEGER NOT NULL DEFAULT 1 CHECK ("slice_only_at_punctuation" IN (0, 1)),
    "max_slice_chars" INTEGER NOT NULL DEFAULT 50,
    "prefetch_segments" INTEGER NOT NULL DEFAULT 5,
    "overwrite_cache_while_playing" INTEGER NOT NULL DEFAULT 0 CHECK ("overwrite_cache_while_playing" IN (0, 1)),
    "skip_punctuation_only_segments" INTEGER NOT NULL DEFAULT 1 CHECK ("skip_punctuation_only_segments" IN (0, 1)),
    "cache_current_color" TEXT NOT NULL DEFAULT '#2F6B54',
    "cache_stale_color" TEXT NOT NULL DEFAULT '#7A5A2A',
    "cache_highlight_opacity" REAL NOT NULL DEFAULT 0.12,
    "current_global_index" INTEGER NOT NULL DEFAULT 0,
    "created_at" INTEGER NOT NULL,
    "updated_at" INTEGER NOT NULL,
    "folder_slug" TEXT NULL,
    PRIMARY KEY ("id")
  )
  ''');
  await editor.ensureTable('novel_chapters', '''
  CREATE TABLE "novel_chapters" (
    "id" TEXT NOT NULL,
    "project_id" TEXT NOT NULL REFERENCES novel_projects (id),
    "order_index" INTEGER NOT NULL,
    "title" TEXT NOT NULL,
    "source_path" TEXT NULL,
    "raw_text" TEXT NOT NULL DEFAULT '',
    PRIMARY KEY ("id")
  )
  ''');
  await editor.ensureTable('novel_segments', '''
  CREATE TABLE "novel_segments" (
    "id" TEXT NOT NULL,
    "project_id" TEXT NOT NULL REFERENCES novel_projects (id),
    "chapter_id" TEXT NOT NULL REFERENCES novel_chapters (id),
    "global_index" INTEGER NOT NULL,
    "order_index" INTEGER NOT NULL,
    "segment_text" TEXT NOT NULL,
    "segment_type" TEXT NOT NULL DEFAULT 'narrator',
    "audio_path" TEXT NULL,
    "audio_duration" REAL NULL,
    "audio_cache_key" TEXT NULL,
    "error" TEXT NULL,
    "missing" INTEGER NOT NULL DEFAULT 0 CHECK ("missing" IN (0, 1)),
    PRIMARY KEY ("id")
  )
  ''');
  await editor.ensureTable('dialog_tts_projects', '''
  CREATE TABLE "dialog_tts_projects" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "bank_id" TEXT NOT NULL REFERENCES voice_banks (id),
    "created_at" INTEGER NOT NULL,
    "updated_at" INTEGER NOT NULL,
    "folder_slug" TEXT NULL,
    PRIMARY KEY ("id")
  )
  ''');
  await editor.ensureTable('dialog_tts_lines', '''
  CREATE TABLE "dialog_tts_lines" (
    "id" TEXT NOT NULL,
    "project_id" TEXT NOT NULL REFERENCES dialog_tts_projects (id),
    "order_index" INTEGER NOT NULL,
    "line_text" TEXT NOT NULL,
    "voice_asset_id" TEXT NULL,
    "audio_path" TEXT NULL,
    "audio_duration" REAL NULL,
    "error" TEXT NULL,
    "missing" INTEGER NOT NULL DEFAULT 0 CHECK ("missing" IN (0, 1)),
    PRIMARY KEY ("id")
  )
  ''');
  await editor.ensureTable('video_dub_projects', '''
  CREATE TABLE "video_dub_projects" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "bank_id" TEXT NOT NULL REFERENCES voice_banks (id),
    "video_path" TEXT NULL,
    "video_duration_sec" REAL NULL,
    "created_at" INTEGER NOT NULL,
    "updated_at" INTEGER NOT NULL,
    "folder_slug" TEXT NULL,
    PRIMARY KEY ("id")
  )
  ''');
  await editor.ensureTable('subtitle_cues', '''
  CREATE TABLE "subtitle_cues" (
    "id" TEXT NOT NULL,
    "project_id" TEXT NOT NULL REFERENCES video_dub_projects (id),
    "order_index" INTEGER NOT NULL,
    "start_ms" INTEGER NOT NULL,
    "end_ms" INTEGER NOT NULL,
    "cue_text" TEXT NOT NULL,
    "voice_asset_id" TEXT NULL,
    "audio_path" TEXT NULL,
    "audio_duration" REAL NULL,
    "error" TEXT NULL,
    "missing" INTEGER NOT NULL DEFAULT 0 CHECK ("missing" IN (0, 1)),
    PRIMARY KEY ("id")
  )
  ''');
  await editor.ensureTable('audio_tracks', '''
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
    "missing" INTEGER NOT NULL DEFAULT 0 CHECK ("missing" IN (0, 1)),
    PRIMARY KEY ("id")
  )
  ''');
  await editor.ensureTable('timeline_clips', '''
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
    "missing" INTEGER NOT NULL DEFAULT 0 CHECK ("missing" IN (0, 1)),
    "link_group_id" TEXT NULL,
    PRIMARY KEY ("id")
  )
  ''');
  await editor.addColumns('tts_providers', {
    'max_concurrency': "INTEGER NOT NULL DEFAULT 1",
    'requests_per_minute': "INTEGER NULL",
    'requests_per_day': "INTEGER NULL",
    'tokens_per_minute': "INTEGER NULL",
    'tokens_per_day': "INTEGER NULL",
  });
}
