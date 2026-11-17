import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:neiroha/data/services/capabilities/catalog_normalizer.dart';

/// Downloads public facts only. Does not use provider credentials or probe models.
Future<void> main() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
  try {
    final request = await client.getUrl(
      Uri.parse(
        'https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json',
      ),
    );
    final response = await request.close().timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw HttpException('Catalog HTTP ${response.statusCode}');
    }
    final bytes = await response.fold<List<int>>([], (all, chunk) {
      if (all.length + chunk.length > 16 * 1024 * 1024) {
        throw const FormatException('Catalog too large.');
      }
      return all..addAll(chunk);
    });
    final snapshot = normalizeLiteLlmCatalog(
      jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
      digest: sha256.convert(bytes).toString(),
    );
    final output = File(
      'assets/model_catalog/model_capabilities.snapshot.json',
    );
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
      '${models.length} models; +$added -$removed ~$changed. Review the diff before publishing.',
    );
  } finally {
    client.close(force: true);
  }
}
