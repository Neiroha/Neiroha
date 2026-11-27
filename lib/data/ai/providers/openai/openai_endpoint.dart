/// Base URL, key and auth header shared by every OpenAI-protocol model of a
/// connection. Vendors with a raw key header (MiMo `api-key`) set
/// [apiKeyHeader]; everything else sends `Authorization: Bearer`.
class OpenAiEndpoint {
  const OpenAiEndpoint(
    this.baseUrl,
    this.apiKey, {
    this.apiKeyHeader = 'Authorization',
  });
  final String baseUrl;
  final String apiKey;
  final String apiKeyHeader;
}
