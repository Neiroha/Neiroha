/// A protocol path can be customized without forwarding credentials to another
/// origin. The connection owns the origin and credentials, the binding the path.
class ServiceEndpoint {
  static String validatePath(String path) {
    final uri = Uri.parse(path.trim());
    if (uri.hasScheme ||
        uri.hasAuthority ||
        uri.hasFragment ||
        uri.path.isEmpty ||
        uri.path.startsWith('/') ||
        uri.pathSegments.any((p) => p == '..' || p == '.') ||
        path.contains('\\') ||
        path.contains('\r') ||
        path.contains('\n')) {
      throw ArgumentError(
        'Endpoint must be a relative path within the connection.',
      );
    }
    return uri.toString();
  }

  static String validateHeader(String name) {
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9-]*$').hasMatch(name) ||
        {
          'host',
          'content-type',
          'content-length',
          'cookie',
        }.contains(name.toLowerCase())) {
      throw ArgumentError('Invalid API key header.');
    }
    return name;
  }
}
