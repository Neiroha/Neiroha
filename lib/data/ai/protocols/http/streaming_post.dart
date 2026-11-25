import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:neiroha/data/ai/protocols/openai/openai_dio.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';

/// POSTs [data] and yields the response body as it arrives. Cancelling
/// [cancellation] drops the connection, also mid-body. An HTTP error reads
/// the (small) error body first, so the server's reason reaches the user as
/// an `AiProviderException`.
Stream<Uint8List> streamingPost(
  Dio dio,
  String path, {
  required TtsCancelToken cancellation,
  required String apiKey,
  Object? data,
  Map<String, dynamic>? queryParameters,
  void Function(Headers headers)? onHeaders,
}) async* {
  cancellation.throwIfCancelled();
  final token = CancelToken();
  final unbind = cancellation.onCancel(() => token.cancel());
  try {
    final Response<ResponseBody> response;
    try {
      response = await dio.post<ResponseBody>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(responseType: ResponseType.stream),
        cancelToken: token,
      );
    } on DioException catch (error) {
      throwAiHttpError(await _withReadableBody(error), apiKey);
    }
    onHeaders?.call(response.headers);
    try {
      await for (final chunk in response.data!.stream) {
        cancellation.throwIfCancelled();
        if (chunk.isNotEmpty) yield chunk;
      }
    } on DioException catch (error) {
      throwAiHttpError(error, apiKey);
    }
    cancellation.throwIfCancelled();
  } finally {
    unbind();
  }
}

/// Stream responses carry their error body as a byte stream; buffer it so
/// `structuredHttpErrorMessage` can read the JSON reason.
Future<DioException> _withReadableBody(DioException error) async {
  final response = error.response;
  final body = response?.data;
  if (response == null || body is! ResponseBody) return error;
  try {
    final bytes = await body.stream
        .fold<BytesBuilder>(BytesBuilder(copy: false), (b, c) => b..add(c))
        .timeout(const Duration(seconds: 5));
    return error.copyWith(
      response: Response<List<int>>(
        requestOptions: response.requestOptions,
        statusCode: response.statusCode,
        statusMessage: response.statusMessage,
        headers: response.headers,
        data: bytes.takeBytes(),
      ),
    );
  } catch (_) {
    return error;
  }
}

/// Server-sent events: the joined `data:` payload of each event, ending at
/// the stream's end or an OpenAI-style `[DONE]`.
Stream<String> sseData(Stream<Uint8List> body) async* {
  final fields = <String>[];
  await for (final line
      in utf8.decoder.bind(body).transform(const LineSplitter())) {
    if (line.startsWith('data:')) {
      final value = line.substring(5);
      fields.add(value.startsWith(' ') ? value.substring(1) : value);
    } else if (line.isEmpty && fields.isNotEmpty) {
      final data = fields.join('\n');
      fields.clear();
      if (data == '[DONE]') return;
      yield data;
    }
  }
  if (fields.isNotEmpty && fields.join('\n') != '[DONE]') {
    yield fields.join('\n');
  }
}
