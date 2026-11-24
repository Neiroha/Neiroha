import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:neiroha/data/services/capabilities/catalog_normalizer.dart';

/// Downloads public facts only. Does not use provider credentials or probe
/// models. Refreshes both bundled snapshots:
///
///   dart run scripts/tools/refresh_model_catalog.dart [litellm|modelsdev]
Future<void> main(List<String> args) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
  try {
    if (args.isEmpty || args.contains('litellm')) {
      await _write(
        'assets/model_catalog/model_capabilities.snapshot.json',
        (bytes) => normalizeLiteLlmCatalog(
          jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
          digest: sha256.convert(bytes).toString(),
        ),
        await _download(
          client,
          'https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json',
        ),
      );
    }
    if (args.isEmpty || args.contains('modelsdev')) {
      await _write(
        'assets/model_catalog/models_dev.snapshot.json',
        (bytes) => normalizeModelsDevCatalog(
          jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
          digest: sha256.convert(bytes).toString(),
        ),
        await _download(client, 'https://models.dev/api.json'),
      );
    }
  } finally {
    client.close(force: true);
  }
}

Future<List<int>> _download(HttpClient client, String url) async {
  final request = await client.getUrl(Uri.parse(url));
  final response = await request.close().timeout(const Duration(seconds: 60));
  if (response.statusCode != 200) {
    throw HttpException('Catalog HTTP ${response.statusCode}: $url');
  }
  return response.fold<List<int>>([], (all, chunk) {
    if (all.length + chunk.length > 32 * 1024 * 1024) {
      throw const FormatException('Catalog too large.');
    }
    return all..addAll(chunk);
  });
}

Future<void> _write(
  String path,
  Map<String, Object?> Function(List<int>) normalize,
  List<int> bytes,
) async {
  {
    final snapshot = normalize(bytes);
    final output = File(path);
    final previous = output.existsSync()
        ? (jsonDecode(output.readAsStringSync()) as Map)['models'] as Map
        : const {};
    final models = snapshot['models'] as Map;
    final added = models.keys.where((key) => !previous.containsKey(key)).length;
    final removed = previous.keys
        .where((key) => !models.containsKey(key))
        .length;
    final changed = models.keys
        .where(
          (key) =>
              previous.containsKey(key) &&
              jsonEncode(previous[key]) != jsonEncode(models[key]),
        )
        .length;
    await output.writeAsString('${jsonEncode(snapshot)}\n');
    stdout.writeln(
      '$path: ${models.length} models; +$added -$removed ~$changed. '
      'Review the diff before publishing.',
    );
  }
}
