import 'dart:async';
import 'package:dio/dio.dart' as dio_pkg;
import 'package:flutter_http_sse/adapter/i_http_adapter.dart';

/// Adapter that wraps the `Dio` package to implement [IHttpAdapter].
///
/// Copy this file into your project and add `dio: ^5.4.0` to your pubspec.yaml
/// if you want to use Dio as the underlying HTTP client.
class DioAdapter implements IHttpAdapter {
  final dio_pkg.Dio _dio;

  /// Creates a [DioAdapter] with an optional existing [Dio] instance.
  ///
  /// If [dio] is not provided, a new instance will be created.
  DioAdapter({dio_pkg.Dio? dio}) : _dio = dio ?? dio_pkg.Dio();

  @override
  Future<SseHttpResponse> sendStream({
    required String method,
    required String url,
    required Map<String, String> headers,
    dynamic body,
  }) async {
    final response = await _dio.fetch<dio_pkg.ResponseBody>(
      dio_pkg.RequestOptions(
        method: method,
        path: url,
        headers: headers,
        data: body,
        responseType: dio_pkg.ResponseType.stream,
      ),
    );

    final streamResponse = response.data!;

    return SseHttpResponse(
      stream: streamResponse.stream,
      statusCode: response.statusCode ?? 0,
      headers: response.headers.map.isEmpty
          ? {}
          : Map.fromEntries(
              response.headers.map.entries.map(
                (e) => MapEntry(e.key, e.value.join('; ')),
              ),
            ),
    );
  }

  @override
  void close() {
    _dio.close(force: true);
  }
}
