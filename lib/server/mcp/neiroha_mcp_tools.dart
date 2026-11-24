import 'package:neiroha/data/ai/registry/tts_adapter_factory.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:neiroha/data/database/app_database.dart';
import 'package:neiroha/data/services/auto_loudness_service.dart';
import 'package:neiroha/data/services/loudness_normalizer.dart';
import 'package:neiroha/data/services/tts_queue_service.dart';
import 'package:neiroha/data/services/video_dub_mix.dart';
import 'package:neiroha/data/storage/export_prefs.dart';
import 'package:neiroha/data/storage/ffmpeg_service.dart';
import 'package:neiroha/data/storage/path_service.dart';
import 'package:neiroha/data/storage/storage_service.dart';
import 'package:neiroha/data/storage/subtitle_parser.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/domain/enums/task_mode.dart';
import 'package:neiroha/domain/platform/platform_capabilities.dart';
import 'package:neiroha/presentation/widgets/video_dub/tracks.dart';
import 'package:neiroha/server/mcp/mcp_server.dart';
import 'package:neiroha/server/mcp/mcp_synthesis.dart';

part 'mcp_handlers_dub.dart';
part 'mcp_handlers_voices.dart';
part 'mcp_tool_args.dart';
part 'mcp_tools_dub.dart';
part 'mcp_tools_internals.dart';
part 'mcp_tools_views.dart';
part 'mcp_tools_voices.dart';
part 'mcp_tools_workspace.dart';

const _uuid = Uuid();

/// The Neiroha tool surface for AI agents: providers, voice banks, the
/// reference-audio library, voice characters, speech synthesis and
/// end-to-end video dubbing. Everything goes through the same database and
/// [TtsQueueService] as the desktop UI, so changes appear live in the app
/// and provider rate limits are respected.
class NeirohaMcpTools {
  NeirohaMcpTools(this.db)
    : _ffmpeg = FFmpegService(db),
      _storage = StorageService(db),
      _exportPrefs = ExportPrefsService(db);

  final AppDatabase db;
  final FFmpegService _ffmpeg;
  final StorageService _storage;
  final ExportPrefsService _exportPrefs;
  late final AutoLoudnessService _autoLoudness = AutoLoudnessService(
    db: db,
    ffmpeg: _ffmpeg,
  );
  late final LoudnessNormalizer _loudness = LoudnessNormalizer(
    resolveFfmpeg: _ffmpeg.resolvePath,
  );

  static const String serverInstructions =
      'Neiroha is a local dubbing workstation. Typical flow: '
      'get_overview → list_providers / create_provider → import_audio_track '
      '(reference clips) → create_voice_character → create_voice_bank / '
      'add_characters_to_bank → synthesize_speech to audition → '
      'create_video_dub_project → import_subtitles → update_subtitle_cues '
      '(assign characters) → generate_video_dub_audio → '
      'normalize_video_dub_loudness (optional, evens out cue volume) → '
      'export_video_dub. '
      'All paths are absolute paths on the machine running Neiroha. Call '
      'list_adapter_types to learn how each engine expects model / voice / '
      'reference audio to be configured.';

  List<McpTool> build() => [
    ..._workspaceTools(),
    ..._voiceTools(),
    ..._dubTools(),
  ];
}
