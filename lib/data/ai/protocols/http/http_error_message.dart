import 'dart:convert';

import 'package:dio/dio.dart';

/// A provider rejected the request and explained why in its response body.
class TtsHttpException implements Exception {
  const TtsHttpException(this.statusCode, this.message);

  final int? statusCode;
  final String message;

  @override
  String toString() => 'HTTP ${statusCode ?? '?'}: $message';
}

/// Reads the reason from a structured JSON error body.
///
/// Recognises `{"error": {"message": ...}}`, `{"error": "..."}`,
/// `{"message": "..."}` and FastAPI's `{"detail": "..."}`. Returns null for
/// connection errors and empty or non-JSON bodies, so callers can keep their
/// generic handling for those.
String? structuredHttpErrorMessage(DioException error) {
  final response = error.response;
  if (response == null) return null;
  Object? data = response.data;
  if (data is List<int>) {
    if (data.isEmpty) return null;
    data = utf8.decode(data, allowMalformed: true);
  }
  if (data is String) {
    final text = data.trim();
    if (text.isEmpty) return null;
    try {
      data = jsonDecode(text);
    } on FormatException {
      return null;
    }
  }
  if (data is! Map) return null;
  final nested = data['error'];
  final candidates = [
    if (nested is Map) nested['message'],
    nested,
    data['message'],
    data['detail'],
  ];
  for (final value in candidates) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

/// Rethrows [error] as a [TtsHttpException] when the body explains the
/// failure; otherwise rethrows the original Dio exception unchanged.
Never throwWithHttpErrorReason(DioException error, StackTrace stackTrace) {
  final message = structuredHttpErrorMessage(error);
  if (message == null) Error.throwWithStackTrace(error, stackTrace);
  Error.throwWithStackTrace(
    TtsHttpException(error.response?.statusCode, message),
    stackTrace,
  );
}
