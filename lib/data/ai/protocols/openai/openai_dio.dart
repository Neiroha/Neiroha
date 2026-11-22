import 'dart:async';

import 'package:dio/dio.dart';
import 'package:neiroha/data/ai/protocols/http/http_error_message.dart';
import 'package:neiroha/domain/ai/ai_exception.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';

/// HTTP client for OpenAI-shaped APIs (OpenAI, Speaches, vLLM, gateways).
Dio openAiDio(
  String baseUrl,
  String apiKey, {
  Duration timeout = const Duration(minutes: 3),
}) {
  final base = baseUrl.trim().endsWith('/') ? baseUrl.trim() : '$baseUrl/';
  return Dio(
    BaseOptions(
      baseUrl: base,
      followRedirects: false,
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: timeout,
      receiveTimeout: timeout,
      headers: {if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey'},
    ),
  );
}

/// Converts Dio failures into a readable [AiProviderException] without
/// leaking the key.
Never throwAiHttpError(DioException error, String apiKey) {
  if (error.type == DioExceptionType.cancel) {
    throw const TtsCancelledException();
  }
  final reason =
      structuredHttpErrorMessage(error) ??
      error.message ??
      error.error?.toString() ??
      error.type.name;
  final safe = apiKey.isEmpty ? reason : reason.replaceAll(apiKey, '[key]');
  throw AiProviderException(safe, statusCode: error.response?.statusCode);
}

/// Runs [call] with a Dio cancel token bound to [cancellation].
Future<T> withCancel<T>(
  TtsCancelToken? cancellation,
  String apiKey,
  Future<T> Function(CancelToken token) call,
) async {
  cancellation?.throwIfCancelled();
  final token = CancelToken();
  final remove = cancellation?.onCancel(() => token.cancel()) ?? () {};
  try {
    return await call(token);
  } on DioException catch (error) {
    throwAiHttpError(error, apiKey);
  } finally {
    remove();
  }
}
