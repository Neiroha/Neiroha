// Update checks: version order, the GitHub answer and its fallback, and the
// build's own version.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/app_version.dart';
import 'package:neiroha/data/services/update/update_checker.dart';

void main() {
  test('the app version is the one in pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*([^\s+]+)',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1);
    expect(appVersion, version);
  });

  test('versions compare in semantic order', () {
    expect(compareVersions('0.6.0', '0.5.1'), greaterThan(0));
    expect(compareVersions('v0.5.1', '0.5.1+10'), 0);
    expect(compareVersions('0.5.10', '0.5.9'), greaterThan(0));
    expect(compareVersions('1.0', '1.0.0'), 0);
    expect(compareVersions('1.0.0-beta.1', '1.0.0'), lessThan(0));
    expect(compareVersions('1.0.0-beta.2', '1.0.0-beta.10'), lessThan(0));
    expect(compareVersions('1.0.0-alpha', '1.0.0-beta'), lessThan(0));
    expect(compareVersions('0.4.2', '0.5.1'), lessThan(0));
  });

  group('GitHub latest release', () {
    late HttpServer server;
    var tag = 'v0.6.0';
    var apiStatus = 200;
    var pageRedirects = true;
    final agents = <String?>[];
    setUp(() async {
      agents.clear();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) {
        agents.add(req.headers.value('user-agent'));
        final res = req.response;
        if (req.uri.path == '/repos/Neiroha/Neiroha/releases/latest') {
          res
            ..statusCode = apiStatus
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                apiStatus != 200
                    ? {'message': 'API rate limit exceeded'}
                    : {
                        'tag_name': tag,
                        'name': 'Neiroha $tag',
                        'html_url':
                            'https://github.com/Neiroha/Neiroha/releases/tag/$tag',
                        'body': '- New things',
                        'published_at': '2026-12-01T08:00:00Z',
                      },
              ),
            );
        } else if (req.uri.path == '/Neiroha/Neiroha/releases/latest' &&
            pageRedirects) {
          res
            ..statusCode = 302
            ..headers.set('location', '/Neiroha/Neiroha/releases/tag/$tag');
        } else {
          res.statusCode = 404;
        }
        res.close();
      });
    });
    tearDown(() => server.close(force: true));

    UpdateChecker checker() => UpdateChecker(
      apiBase: 'http://127.0.0.1:${server.port}',
      webBase: 'http://127.0.0.1:${server.port}',
      current: '0.5.1',
    );

    test('a newer release is offered with its page and notes', () async {
      tag = 'v0.6.0';
      apiStatus = 200;
      final release = await checker().newerRelease();
      expect(release!.version, '0.6.0');
      expect(release.url, endsWith('/releases/tag/v0.6.0'));
      expect(release.notes, '- New things');
      expect(release.publishedAt, DateTime.utc(2026, 12, 1, 8));
      // A generic client name; nothing about the user.
      expect(agents.single, 'Neiroha');
    });

    test('the same or an older release is not offered', () async {
      apiStatus = 200;
      tag = 'v0.5.1';
      expect(await checker().newerRelease(), isNull);
      tag = 'v0.4.2';
      expect(await checker().newerRelease(), isNull);
    });

    test('a rate-limited API falls back to the release page', () async {
      apiStatus = 403;
      pageRedirects = true;
      tag = 'v0.6.0';
      final release = await checker().newerRelease();
      expect(release!.version, '0.6.0');
      expect(
        release.url,
        'http://127.0.0.1:${server.port}/Neiroha/Neiroha/releases/tag/v0.6.0',
      );
      expect(release.notes, isEmpty);
      expect(agents, everyElement('Neiroha'));
    });

    test('when neither answers it is an error, not "up to date"', () async {
      apiStatus = 403;
      pageRedirects = false;
      await expectLater(checker().newerRelease(), throwsA(anything));
      pageRedirects = true;
    });
  });

  test('automatic checks are on unless turned off', () {
    expect(UpdateSettings.parseAutoCheck(null), isTrue);
    expect(UpdateSettings.parseAutoCheck('true'), isTrue);
    expect(UpdateSettings.parseAutoCheck('false'), isFalse);
  });
}
