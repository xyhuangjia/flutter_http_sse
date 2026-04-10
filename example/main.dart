import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_http_sse/client/sse_client.dart';
import 'package:flutter_http_sse/model/sse_request.dart';

// Import the adapter implementations from example/
// In your own project, copy these adapters and import from your local path.
import 'lib/adapters/dio_adapter.dart';
// import 'lib/adapters/http_package_adapter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  SSEClient? _sseClient;
  Stream? _stream;
  final List<String> _messages = [];

  @override
  void initState() {
    super.initState();
    _initSSE();
  }

  void _initSSE() {
    // Example 1: Using the http package adapter
    // Uncomment to use http package instead of Dio:
    // final httpRequest = SSERequest(
    //   url: 'https://your-sse-server.com/events-http',
    //   httpAdapter: HttpPackageAdapter(),
    //   onData: (response) {
    //     log("http package adapter - New SSE Event: ${response.data}");
    //   },
    //   onError: (error) {
    //     log("http package adapter - SSE Error: $error");
    //   },
    //   onDone: () {
    //     log("http package adapter - SSE Connection Closed");
    //   },
    //   retry: true,
    // );

    // Example 2: Using the Dio adapter
    final dioRequest = SSERequest(
      url: 'https://your-sse-server.com/events-dio',
      httpAdapter: DioAdapter(),
      onData: (response) {
        log("Dio adapter - New SSE Event: ${response.data}");
      },
      onError: (error) {
        log("Dio adapter - SSE Error: $error");
      },
      onDone: () {
        log("Dio adapter - SSE Connection Closed");
      },
      retry: true,
    );

    // Create the client
    _sseClient = SSEClient();

    // Connect using the Dio adapter
    _stream = _sseClient!.connect('sse_connection1', dioRequest);
    _stream!.listen(
      (event) {
        setState(() {
          _messages.add(event.data.toString());
        });
      },
      onError: (error) => log("Stream Error: $error"),
      onDone: () => log("Stream Closed"),
    );
  }

  @override
  void dispose() {
    _sseClient?.close(connectionId: 'sse_connection1');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Flutter HTTP SSE Example')),
        body: ListView.builder(
          itemCount: _messages.length,
          itemBuilder: (context, index) {
            return ListTile(title: Text(_messages[index]));
          },
        ),
      ),
    );
  }
}
