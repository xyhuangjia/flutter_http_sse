import 'dart:async';

/// Abstract adapter interface for HTTP clients used in SSE connections.
///
/// Implement this interface to plug in any HTTP library (http, Dio, etc.)
/// into the SSE client. The only requirement is the ability to send a
/// streaming request and return the response as a [Future<SseHttpResponse>].
abstract class IHttpAdapter {
  /// Sends an HTTP request and returns a streaming response.
  ///
  /// [method] is the HTTP method (GET, POST, etc.).
  /// [url] is the request URL.
  /// [headers] are the HTTP headers to include.
  /// [body] is the optional request body (already serialized).
  ///
  /// Returns a [Future<SseHttpResponse>] containing the response stream
  /// and metadata like status code.
  Future<SseHttpResponse> sendStream({
    required String method,
    required String url,
    required Map<String, String> headers,
    dynamic body,
  });

  /// Closes the underlying HTTP client and releases resources.
  void close();
}

/// Represents a streaming HTTP response from an adapter.
class SseHttpResponse {
  final Stream<List<int>> stream;
  final int statusCode;
  final Map<String, String> headers;

  SseHttpResponse({
    required this.stream,
    required this.statusCode,
    this.headers = const {},
  });
}
