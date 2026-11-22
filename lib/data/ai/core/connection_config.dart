/// Account-level settings of one configured connection.
class ConnectionConfig {
  const ConnectionConfig({
    required this.id,
    required this.baseUrl,
    this.apiKey = '',
    this.name = '',
    this.options = const {},
  });
  final String id;
  final String baseUrl;
  final String apiKey;
  final String name;

  /// Plugin-specific settings (legacy adapter type, region, app id…).
  final Map<String, String> options;
}
