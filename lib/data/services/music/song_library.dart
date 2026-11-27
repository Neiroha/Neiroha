import 'dart:convert';
import 'dart:io';

import 'package:neiroha/data/ai/providers/gemini/music/lyria_lyrics.dart';
import 'package:neiroha/data/storage/path_service.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:path/path.dart' as p;

/// One generated song on disk: audio, optional `.lrc`, and a `.json`
/// sidecar holding the request and the lyrics the model returned.
class SongRecord {
  const SongRecord({
    required this.audioPath,
    required this.title,
    required this.prompt,
    required this.lyrics,
    required this.model,
    required this.provider,
    required this.created,
    this.instrumental = false,
    this.lrcPath,
  });

  final String audioPath;
  final String title;
  final String prompt;
  final List<LyricLine> lyrics;
  final String model;
  final String provider;
  final DateTime created;
  final bool instrumental;
  final String? lrcPath;

  String get metaPath => p.setExtension(audioPath, '.json');
}

/// `{voiceAssetRoot}/songs/` — songs from the music capability.
class SongLibrary {
  SongLibrary(this.dir);
  final Directory dir;

  static Future<SongLibrary> open() async =>
      SongLibrary(await PathService.instance.songsDir());

  Future<SongRecord> save(
    GeneratedSong song, {
    required String title,
    required MusicRequest request,
    required String model,
    required String provider,
  }) async {
    final created = DateTime.now();
    final base = '${PathService.formatTimestamp(created)}_$title';
    final audioPath = PathService.dedupeFilename(dir, base, song.extension);
    await File(audioPath).writeAsBytes(song.audio, flush: true);
    final lrc = lyricsToLrc(song.lyrics, title: title);
    String? lrcPath;
    if (lrc != null) {
      lrcPath = p.setExtension(audioPath, '.lrc');
      await File(lrcPath).writeAsString(lrc);
    }
    final record = SongRecord(
      audioPath: audioPath,
      title: title,
      prompt: request.prompt,
      lyrics: song.lyrics,
      model: model,
      provider: provider,
      created: created,
      instrumental: request.instrumental,
      lrcPath: lrcPath,
    );
    await File(record.metaPath).writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'title': title,
        'prompt': request.prompt,
        'requestedLyrics': request.lyrics,
        'instrumental': request.instrumental,
        'model': model,
        'provider': provider,
        'created': created.toIso8601String(),
        'rawLyrics': song.rawLyrics,
        'usage': song.usage,
      }),
    );
    return record;
  }

  /// Newest first; songs whose audio file is gone are skipped.
  Future<List<SongRecord>> list() async {
    if (!await dir.exists()) return const [];
    final out = <SongRecord>[];
    await for (final f in dir.list()) {
      if (f is! File || p.extension(f.path) != '.json') continue;
      try {
        final meta = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        final audio = await _audioFor(f.path);
        if (audio == null) continue;
        final lrc = p.setExtension(audio, '.lrc');
        out.add(
          SongRecord(
            audioPath: audio,
            title: '${meta['title'] ?? p.basenameWithoutExtension(audio)}',
            prompt: '${meta['prompt'] ?? ''}',
            lyrics: parseLyriaLyrics('${meta['rawLyrics'] ?? ''}'),
            model: '${meta['model'] ?? ''}',
            provider: '${meta['provider'] ?? ''}',
            created:
                DateTime.tryParse('${meta['created']}') ??
                (await f.lastModified()),
            instrumental: meta['instrumental'] == true,
            lrcPath: File(lrc).existsSync() ? lrc : null,
          ),
        );
      } catch (_) {
        // A damaged sidecar hides that song, not the library.
      }
    }
    out.sort((a, b) => b.created.compareTo(a.created));
    return out;
  }

  static Future<String?> _audioFor(String metaPath) async {
    for (final ext in const ['.wav', '.mp3', '.flac', '.ogg']) {
      final path = p.setExtension(metaPath, ext);
      if (await File(path).exists()) return path;
    }
    return null;
  }

  Future<void> delete(SongRecord song) async {
    for (final path in [song.audioPath, song.metaPath, ?song.lrcPath]) {
      final f = File(path);
      if (await f.exists()) await f.delete();
    }
  }
}
