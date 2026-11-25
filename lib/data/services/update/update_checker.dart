import 'package:dio/dio.dart';
import 'package:neiroha/app_version.dart';

/// A published release of the app.
class AppRelease {
  const AppRelease({
    required this.version,
    required this.name,
    required this.url,
    this.notes = '',
    this.publishedAt,
  });

  /// The version without its leading `v`, e.g. `0.6.0`.
  final String version;
  final String name;

  /// The release page to download it from.
  final String url;
  final String notes;
  final DateTime? publishedAt;
}

/// Settings for update checks.
class UpdateSettings {
  /// Check for a newer release when the app starts. On by default.
  static const autoCheckKey = 'app.update.autoCheck';

  /// A version the user chose to skip; its reminder is not shown again.
  static const skippedKey = 'app.update.skipped';

  const UpdateSettings._();

  static bool parseAutoCheck(String? value) =>
      value?.trim().toLowerCase() != 'false';
}

/// Asks GitHub for the latest release. Public data only: nothing about the
/// user or this install is sent.
///
/// The API allows 60 unauthenticated requests an hour per IP address, which
/// a shared proxy or VPN exit can use up; then the release page's redirect
/// (`/releases/latest` → `/releases/tag/<tag>`), which has no such limit,
/// still gives the version, without notes.
class UpdateChecker {
  UpdateChecker({
    Dio? http,
    this.repository = 'Neiroha/Neiroha',
    this.apiBase = 'https://api.github.com',
    this.webBase = 'https://github.com',
    this.current = appVersion,
  }) : _http = http ?? Dio();

  final Dio _http;
  final String repository;
  final String apiBase;
  final String webBase;
  final String current;

  String get releasesPage => '$webBase/$repository/releases';

  static final _headers = {'User-Agent': 'Neiroha'};
  static const _timeout = Duration(seconds: 15);

  /// The latest stable release (GitHub leaves out drafts and pre-releases).
  /// Throws only when neither the API nor the release page answers.
  Future<AppRelease> latest() async {
    try {
      return await _fromApi();
    } catch (_) {
      return _fromRedirect();
    }
  }

  Future<AppRelease> _fromRedirect() async {
    final response = await _http.get<void>(
      '$webBase/$repository/releases/latest',
      options: Options(
        headers: _headers,
        followRedirects: false,
        validateStatus: (status) => status != null && status < 400,
        sendTimeout: _timeout,
        receiveTimeout: _timeout,
      ),
    );
    final location = response.headers.value('location') ?? '';
    final tag = RegExp(r'/releases/tag/([^/?#]+)').firstMatch(location);
    if (tag == null) throw const FormatException('No latest release found.');
    final name = Uri.decodeComponent(tag.group(1)!);
    return AppRelease(
      version: name.replaceFirst(RegExp('^[vV]'), ''),
      name: name,
      url: Uri.parse(webBase).resolve(location).toString(),
    );
  }

  Future<AppRelease> _fromApi() async {
    final response = await _http.get<Map<String, dynamic>>(
      '$apiBase/repos/$repository/releases/latest',
      options: Options(
        headers: {..._headers, 'Accept': 'application/vnd.github+json'},
        sendTimeout: _timeout,
        receiveTimeout: _timeout,
      ),
    );
    final body = response.data ?? const {};
    final tag = '${body['tag_name'] ?? ''}'.trim();
    if (tag.isEmpty) throw const FormatException('The release has no tag.');
    final name = '${body['name'] ?? ''}'.trim();
    return AppRelease(
      version: tag.replaceFirst(RegExp('^[vV]'), ''),
      name: name.isEmpty ? tag : name,
      url: '${body['html_url'] ?? releasesPage}',
      notes: '${body['body'] ?? ''}'.trim(),
      publishedAt: DateTime.tryParse('${body['published_at'] ?? ''}'),
    );
  }

  /// The latest release when it is newer than this build, otherwise null.
  Future<AppRelease?> newerRelease() async {
    final release = await latest();
    return compareVersions(release.version, current) > 0 ? release : null;
  }
}

/// Compares semantic versions (`1.2.3`, `v1.2.3-beta.1`, `1.2.3+4`): build
/// metadata is ignored and a pre-release sorts before its release.
int compareVersions(String a, String b) {
  (List<int>, List<String>) parse(String v) {
    final plain = v.trim().replaceFirst(RegExp('^[vV]'), '').split('+').first;
    final dash = plain.indexOf('-');
    final core = dash < 0 ? plain : plain.substring(0, dash);
    final pre = dash < 0 ? '' : plain.substring(dash + 1);
    return (
      [for (final part in core.split('.')) int.tryParse(part) ?? 0],
      pre.isEmpty ? const [] : pre.split('.'),
    );
  }

  final (coreA, preA) = parse(a);
  final (coreB, preB) = parse(b);
  for (var i = 0; i < 3 || i < coreA.length || i < coreB.length; i++) {
    final x = i < coreA.length ? coreA[i] : 0;
    final y = i < coreB.length ? coreB[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  if (preA.isEmpty || preB.isEmpty) {
    return preA.isEmpty == preB.isEmpty ? 0 : (preA.isEmpty ? 1 : -1);
  }
  for (var i = 0; i < preA.length && i < preB.length; i++) {
    final x = int.tryParse(preA[i]), y = int.tryParse(preB[i]);
    final c = x != null && y != null
        ? x.compareTo(y)
        : x != null
        ? -1
        : y != null
        ? 1
        : preA[i].compareTo(preB[i]);
    if (c != 0) return c;
  }
  return preA.length.compareTo(preB.length);
}
