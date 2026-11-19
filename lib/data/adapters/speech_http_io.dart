import 'package:dio/dio.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';

import 'speech_http_response.dart';

Future<SpeechHttpResponse> postSpeech(
  Uri uri,
  Map<String, String> headers,
  Object body,
  TtsCancelToken cancellation,
  Duration timeout,
) async {
  final dio = Dio(
    BaseOptions(
      followRedirects: false,
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: timeout,
      receiveTimeout: timeout,
      headers: headers,
    ),
  );
  final cancel = CancelToken();
  final remove = cancellation.onCancel(() => cancel.cancel());
  void close() {
    remove();
    dio.close(force: true);
  }

  try {
    cancellation.throwIfCancelled();
    final response = await dio.postUri<ResponseBody>(
      uri,
      data: body,
      cancelToken: cancel,
      options: Options(responseType: ResponseType.stream),
    );
    return (
      header: response.headers.value,
      chunks: response.data!.stream,
      close: close,
    );
  } catch (_) {
    close();
    rethrow;
  }
}
