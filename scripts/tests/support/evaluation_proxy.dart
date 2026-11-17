import 'dart:io';
import 'package:dio/io.dart';

/// Explicit test-process routing; never changes system or application settings.
IOHttpClientAdapter? evaluationProxy() {
  final address = Platform.environment['NEIROHA_EVAL_PROXY'];
  if (address == null || address.isEmpty) return null;
  final uri = Uri.parse(address);
  if (uri.scheme != 'http' ||
      !['127.0.0.1', 'localhost'].contains(uri.host) ||
      !uri.hasPort ||
      uri.userInfo.isNotEmpty) {
    throw ArgumentError(
      'Evaluation proxy must be an explicit local HTTP proxy.',
    );
  }
  return IOHttpClientAdapter(
    createHttpClient: () =>
        HttpClient()..findProxy = (_) => 'PROXY ${uri.host}:${uri.port}',
  );
}
