import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/synthesis/synthesis_service.dart';
import 'package:neiroha/data/storage/session_audio_urls.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';
import 'package:neiroha/domain/synthesis/tts_request.dart';

final sessionAudioProvider =
    NotifierProvider<SessionAudioHistory, List<db.QuickTtsHistory>>(
      SessionAudioHistory.new,
    );

/// The SQLite history is reserved for desktop files. Web entries own Blob URLs
/// and remain available while navigating within the current browser tab.
class SessionAudioHistory extends Notifier<List<db.QuickTtsHistory>> {
  static const _maxEntries = 30;
  final _clips = <String, ({String url, String extension, int bytes})>{};
  int _retainedBytes = 0;

  @override
  List<db.QuickTtsHistory> build() {
    ref.onDispose(() {
      for (final clip in _clips.values) {
        revokeSessionAudioUrl(clip.url);
      }
      _clips.clear();
      _retainedBytes = 0;
    });
    return const [];
  }

  String add(String id, db.VoiceAsset voice, String text, TtsResult audio) {
    final format = TtsAudioFormat.fromFileBytes(
      audio.audioBytes,
      audio.contentType,
    );
    final size = audio.audioBytes.length;
    final url = createSessionAudioUrl(audio.audioBytes, format.contentType);
    _clips[id] = (url: url, extension: format.extension, bytes: size);
    _retainedBytes += size;
    final history = [
      db.QuickTtsHistory(
        id: id,
        voiceAssetId: voice.id,
        voiceName: voice.name,
        inputText: text,
        audioPath: url,
        createdAt: DateTime.now(),
        missing: false,
      ),
      ...state,
    ];
    while (history.length > _maxEntries ||
        _retainedBytes > SynthesisService.sessionAudioLimit) {
      _release(history.removeLast().id);
    }
    state = history;
    return url;
  }

  void delete(String id) {
    _release(id);
    state = state.where((entry) => entry.id != id).toList();
  }

  void clearVoice(String assetId) {
    for (final entry in state.where((entry) => entry.voiceAssetId == assetId)) {
      _release(entry.id);
    }
    state = state.where((entry) => entry.voiceAssetId != assetId).toList();
  }

  void download(String id) {
    final clip = _clips[id];
    if (clip != null) {
      downloadSessionAudio(clip.url, 'neiroha-$id${clip.extension}');
    }
  }

  void _release(String id) {
    final clip = _clips.remove(id);
    if (clip == null) return;
    _retainedBytes -= clip.bytes;
    revokeSessionAudioUrl(clip.url);
  }
}
