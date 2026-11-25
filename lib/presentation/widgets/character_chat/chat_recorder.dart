import 'dart:io';
import 'dart:typed_data';

import 'package:neiroha/data/ai/protocols/audio/wav_utils.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/storage/path_service.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';
import 'package:path/path.dart' as p;

/// Saves a chat's lines as they happen, in order, and each reply's audio
/// as a file whose path goes into that reply's metadata (`audio`).
///
/// A reply's audio can arrive just before its text is final (a streamed
/// reply) or after it (a structured reply, a Realtime call); either way it
/// is matched to that reply, never to an older one.
class ChatRecorder {
  ChatRecorder(
    this.database,
    this.sessionId, {
    Future<Directory> Function()? audioDir,
  }) : _audioDir =
           audioDir ?? (() => PathService.instance.chatAudioDir(sessionId));

  final db.AppDatabase database;
  final String sessionId;
  final Future<Directory> Function() _audioDir;

  Future<void> _writes = Future.value();

  /// The last reply, still waiting for its audio.
  String? _awaitingAudio;

  /// Audio heard before its reply was saved.
  String? _orphanAudio;

  /// Completes once everything queued is written.
  Future<void> get idle => _writes;

  void _queue(Future<void> Function() write) =>
      _writes = _writes.then((_) => write()).catchError((_) {});

  void user(String text) => _queue(() async {
    // A new turn: audio from before it belongs to nothing.
    _awaitingAudio = null;
    _orphanAudio = null;
    await _add('user', text);
  });

  void reply(String text, {String? emotion, String? style}) => _queue(() async {
    final audio = _orphanAudio;
    _orphanAudio = null;
    final id = await _add('character', text, {
      'emotion': ?emotion,
      if (style != null && style.trim().isNotEmpty) 'style': style.trim(),
      'audio': ?audio,
    });
    if (audio == null) _awaitingAudio = id;
  });

  void tool(String name, String arguments, String result) => _queue(
    () => _add('tool', result, {'name': name, 'arguments': arguments}),
  );

  void audio(TtsAudioFormat format, Uint8List bytes) => _queue(() async {
    final path = await _writeAudio(format, bytes);
    final id = _awaitingAudio;
    if (id == null) {
      _orphanAudio = path;
      return;
    }
    _awaitingAudio = null;
    await database.mergeChatMessageMeta(id, {'audio': path});
  });

  Future<String?> _add(
    String role,
    String content, [
    Map<String, Object?>? meta,
  ]) async {
    if (content.trim().isEmpty) return null;
    return database.addChatMessage(
      sessionId,
      role: role,
      content: content.trim(),
      meta: meta == null || meta.isEmpty ? null : meta,
    );
  }

  Future<String> _writeAudio(TtsAudioFormat format, Uint8List bytes) async {
    final dir = await _audioDir();
    final pcm = format.encoding == AudioEncoding.pcmS16le;
    final file = File(
      p.join(
        dir.path,
        'reply_${DateTime.now().microsecondsSinceEpoch}'
        '${pcm ? '.wav' : format.extension}',
      ),
    );
    await file.writeAsBytes(
      pcm
          ? wrapPcmAsWav(
              bytes,
              sampleRate: format.sampleRate ?? 24000,
              channels: format.channels ?? 1,
            )
          : bytes,
    );
    return file.path;
  }
}
