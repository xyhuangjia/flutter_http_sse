import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import '../model/sse_request.dart';
import '../model/sse_response.dart';
import 'i_sse_client.dart';

class SSEClient extends ISSEClient {
  final Map<String, _SSEConnection> _connections = {};

  @override
  void close({String? connectionId}) {
    if (connectionId != null) {
      _connections[connectionId]?.close();
      _connections.remove(connectionId);
    } else {
      for (var connection in _connections.values) {
        connection.close();
      }
      _connections.clear();
    }
  }

  @override
  Stream<SSEResponse> connect(
    String connectionId,
    SSERequest request, {
    Function(dynamic)? fromJson,
  }) {
    return subscribeToSSE(connectionId, request, fromJson: fromJson);
  }

  Stream<SSEResponse> subscribeToSSE(
    String connectionId,
    SSERequest request, {
    Function(dynamic)? fromJson,
  }) {
    if (_connections.containsKey(connectionId)) {
      return _connections[connectionId]!.stream;
    }

    final connection = _SSEConnection(request, fromJson);
    _connections[connectionId] = connection;
    return connection.stream;
  }
}

class _SSEConnection {
  final SSERequest request;
  final Function(dynamic p1)? fromJson;
  final StreamController<SSEResponse> _controller =
      StreamController.broadcast();
  http.Client? _client;
  int _retryCount = 0;
  static const int _maxRetries = 5;
  static const Duration _initialDelay = Duration(seconds: 2);

  final Queue<SSEResponse> _responseQueue = Queue();
  Timer? _rateLimitTimer;

  _SSEConnection(this.request, this.fromJson) {
    _connect();
  }

  void _connect() {
    _client = http.Client();
    var httpRequest = http.Request(
      request.requestType.value,
      request.getRequestUri,
    );

    if (request.headers != null) {
      httpRequest.headers.addAll(request.headers!);
    }
    if (request.body != null) {
      httpRequest.body = json.encode(request.body);
    }

    _client!
        .send(httpRequest)
        .then((response) {
          if (response.statusCode >= 500) {
            _handleError(
              "Failed to connect to server. Status code: ${response.statusCode}",
            );
            return;
          }

          _retryCount = 0;

          final StringBuffer buffer = StringBuffer();

          response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .listen(
                (String line) {
                  if (_controller.isClosed) return;

                  if (line.isEmpty) {
                    // Parse accumulated event when an empty line is encountered
                    if (buffer.isNotEmpty) {
                      final sseRes = SSEResponse.parse(buffer.toString());
                      _controller.add(sseRes);
                      _enqueueResponse(sseRes);
                      buffer.clear();
                    }
                  } else {
                    buffer.writeln(line);
                  }
                },
                onDone: () {
                  request.onDone?.call();
                },
                onError: (error) {
                  _handleError(error);
                },
                cancelOnError: true,
              );
        })
        .catchError((error) {
          _handleError(error);
        });
  }

  void _handleError(dynamic error) {
    log("Error connecting to server via SSE: $error");
    if (_controller.isClosed) return;
    _controller.addError(error);
    request.onError?.call(error.toString());

    if (request.retry) {
      _handleRetry();
    } else {
      close();
    }
  }

  void _handleRetry() {
    if (_retryCount >= _maxRetries) {
      close();
      return;
    }

    _retryCount++;
    Duration retryDelay = _initialDelay * _retryCount; // Exponential backoff

    Future.delayed(retryDelay, () {
      if (!_controller.isClosed) {
        _connect();
      }
    });
  }

  void _enqueueResponse(SSEResponse response) {
    _responseQueue.add(response);

    if (!request.enableRateLimit) {
      request.onData(response);
      return;
    }

    if (_rateLimitTimer == null) {
      _startRateLimitTimer();
    }
  }

  void _startRateLimitTimer() {
    _rateLimitTimer = Timer.periodic(
      Duration(milliseconds: request.rateLimitMs),
      (_) => _flushResponse(),
    );
  }

  void _flushResponse() {
    if (_responseQueue.isEmpty) {
      _rateLimitTimer?.cancel();
      _rateLimitTimer = null;
      return;
    }

    final response = _responseQueue.removeFirst();
    request.onData(response);
  }

  Stream<SSEResponse> get stream => _controller.stream;

  void close() {
    _rateLimitTimer?.cancel();
    _rateLimitTimer = null;
    _responseQueue.clear();
    if (_controller.isClosed) return;
    _controller.close();
    _client?.close();
  }
}
