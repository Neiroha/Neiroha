import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Central resolver for on-disk paths used by the app.
///
/// Layout:
/// - `{root}/data/neiroha.db` — SQLite file, non-configurable
/// - `{root}/data/avatars/` — character & track avatar images
/// - `{voiceAssetRoot}/quick_tts/{char}/`
/// - `{voiceAssetRoot}/phase_tts/{project}/`
/// - `{voiceAssetRoot}/dialog_tts/{project}/`
/// - `{voiceAssetRoot}/voice_character_ref/`
///
/// `{root}` is the executable directory when writable (portable mode),
/// otherwise falls back to the OS app-support dir. `{voiceAssetRoot}`
/// defaults to `{root}/voice_asset` but can be overridden by the user.
class PathService {
  PathService._();
  static final PathService instance = PathService._();

  late final Directory _appRoot;
  late final Directory _dataRoot;
  late final Directory _defaultVoiceAssetRoot;
  late final Directory _legacyAppSupportDir;
  Directory? _overrideVoiceAssetRoot;
  bool _portable = false;
  Future<void>? _initFuture;

  bool get isPortable => _portable;
  Directory get appRoot => _appRoot;
  Directory get dataRoot => _dataRoot;
  Directory get legacyAppSupportDir => _legacyAppSupportDir;
  Directory get defaultVoiceAssetRoot => _defaultVoiceAssetRoot;
  Directory get voiceAssetRoot =>
      _overrideVoiceAssetRoot ?? _defaultVoiceAssetRoot;

  /// Resolve app root and create managed directories. Safe to call
  /// concurrently (e.g. from `main()` and the DB LazyDatabase opener);
  /// all callers await the same future so the `late final` fields are
  /// only assigned once.
  Future<void> init() => _initFuture ??= _init();

  Future<void> _init() async {
    _legacyAppSupportDir = await getApplicationSupportDirectory();

    final exeDir = File(Platform.resolvedExecutable).parent;
    _portable = await _isWritable(exeDir);
    _appRoot = _portable ? exeDir : _legacyAppSupportDir;

    _dataRoot = Directory(p.join(_appRoot.path, 'data'));
    if (!await _dataRoot.exists()) {
      await _dataRoot.create(recursive: true);
    }

    _defaultVoiceAssetRoot = Directory(p.join(_appRoot.path, 'voice_asset'));
    if (!await _defaultVoiceAssetRoot.exists()) {
      await _defaultVoiceAssetRoot.create(recursive: true);
    }
  }

  /// Apply a user-chosen voice-asset root. Pass null to revert to default.
  /// The caller is responsible for persisting the choice.
  void applyVoiceAssetRootOverride(String? path) {
    if (path == null || path.trim().isEmpty) {
      _overrideVoiceAssetRoot = null;
      return;
    }
    _overrideVoiceAssetRoot = Directory(path);
  }

  /// Windows reserved device names — creating a folder with any of these
  /// names (with or without extension) silently fails on Windows.
  static const _reservedWindowsNames = {
    'CON',
    'PRN',
    'AUX',
    'NUL',
    'COM1',
    'COM2',
    'COM3',
    'COM4',
    'COM5',
    'COM6',
    'COM7',
    'COM8',
    'COM9',
    'LPT1',
    'LPT2',
    'LPT3',
    'LPT4',
    'LPT5',
    'LPT6',
    'LPT7',
    'LPT8',
    'LPT9',
  };

  /// Make `input` a safe filesystem segment across Windows/macOS/Linux.
  ///
  /// Steps: replace reserved chars & control chars with `_`, collapse
  /// whitespace, strip trailing dots/spaces (both break on Windows), cap
  /// at 48 chars (leaves headroom under MAX_PATH=260), append `_` to
  /// Windows reserved device names.
  static String sanitizeSegment(String input, {String fallback = 'untitled'}) {
    var s = input.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Windows ignores trailing dots and spaces → DB-vs-disk name drift.
    while (s.isNotEmpty && (s.endsWith('.') || s.endsWith(' '))) {
      s = s.substring(0, s.length - 1);
    }
    if (s.isEmpty) return fallback;
    if (s.length > 48) s = s.substring(0, 48).trimRight();
    if (_reservedWindowsNames.contains(s.toUpperCase())) {
      s = '${s}_';
    }
    return s;
  }

  /// Filename-safe, locally-sortable timestamp: `2026-04-21_14-30-22`.
  static String formatTimestamp([DateTime? dt]) {
    final d = dt ?? DateTime.now();
    String z(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${z(d.month)}-${z(d.day)}_'
        '${z(d.hour)}-${z(d.minute)}-${z(d.second)}';
  }

  /// Resolve `{dir}/{base}{ext}`, appending `-1`, `-2`, … on collision so
  /// two files with the same display name never overwrite each other.
  /// `ext` should include the leading dot, e.g. `.wav`.
  static String dedupeFilename(Directory dir, String base, String ext) {
    final safeBase = sanitizeSegment(base, fallback: 'file');
    var candidate = p.join(dir.path, '$safeBase$ext');
    var n = 1;
    while (File(candidate).existsSync()) {
      candidate = p.join(dir.path, '$safeBase-$n$ext');
      n++;
    }
    return candidate;
  }

  Future<Directory> _ensure(Directory dir) async {
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> avatarsDir() =>
      _ensure(Directory(p.join(_dataRoot.path, 'avatars')));

  Future<Directory> quickTtsDir(String voiceCharName) => _ensure(
    Directory(
      p.join(
        voiceAssetRoot.path,
        'quick_tts',
        sanitizeSegment(voiceCharName, fallback: 'unnamed_voice'),
      ),
    ),
  );

  Future<Directory> phaseTtsDir(String projectName) => _ensure(
    Directory(
      p.join(
        voiceAssetRoot.path,
        'phase_tts',
        sanitizeSegment(projectName, fallback: 'unnamed_project'),
      ),
    ),
  );

  /// Resolve `{phaseTtsDir(slug)}/phase_segment_settings.json`. This stores
  /// per-sentence generation overrides such as a temporary emotion /
  /// instruction prompt for one segment.
  Future<File> phaseTtsSegmentSettingsFile(String projectSlug) async {
    final dir = await phaseTtsDir(projectSlug);
    return File(p.join(dir.path, 'phase_segment_settings.json'));
  }

  Future<Directory> dialogTtsDir(String projectName) => _ensure(
    Directory(
      p.join(
        voiceAssetRoot.path,
        'dialog_tts',
        sanitizeSegment(projectName, fallback: 'unnamed_project'),
      ),
    ),
  );

  Future<Directory> videoDubDir(String projectName) => _ensure(
    Directory(
      p.join(
        voiceAssetRoot.path,
        'video_dub',
        sanitizeSegment(projectName, fallback: 'unnamed_project'),
      ),
    ),
  );

  Future<Directory> voiceCharacterRefDir() =>
      _ensure(Directory(p.join(voiceAssetRoot.path, 'voice_character_ref')));

  /// SFX imports live under the owning project dir so they stay grouped
  /// with the generated takes they accompany.
  Future<Directory> timelineSfxDir({
    required String projectType,
    required String projectName,
  }) async {
    final base = projectType == 'phase'
        ? await phaseTtsDir(projectName)
        : await dialogTtsDir(projectName);
    return _ensure(Directory(p.join(base.path, 'sfx')));
  }

  Future<bool> _isWritable(Directory dir) async {
    try {
      final probe = File(
        p.join(
          dir.path,
          '.neiroha_write_probe_${DateTime.now().microsecondsSinceEpoch}',
        ),
      );
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
  }
}
