import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_http_sse/adapter/i_http_adapter.dart';

/// Adapter that wraps the `http` package to implement [IHttpAdapter].
///
/// Copy this file into your project and add `http: ^1.6.0` to your pubspec.yaml
/// if you want to use the `http` package as the underlying HTTP client.
class HttpPackageAdapter implements IHttpAdapter {
  http.Client? _client;

  http.Client get client => _client ??= http.Client();

  @override
  Future<SseHttpResponse> sendStream({
    required String method,
    required String url,
    required Map<String, String> headers,
    dynamic body,
  }) async {
    final httpRequest = http.Request(method, Uri.parse(url));

    if (headers.isNotEmpty) {
      httpRequest.headers.addAll(headers);
    }

    if (body != null) {
      httpRequest.body = body;
    }

    final response = await client.send(httpRequest);

    return SseHttpResponse(
      stream: response.stream,
      statusCode: response.statusCode,
      headers: response.headers,
    );
  }

  @override
  void close() {
    _client?.close();
    _client = null;
  }
}
