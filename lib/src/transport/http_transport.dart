/// HTTP transport layer for Polymarket REST API calls.
library;

import 'dart:convert';
import 'package:http/http.dart' as http;

/// Exception thrown when the Polymarket API returns an error.
class PolymarketApiException implements Exception {
  final int statusCode;
  final String message;
  final String? body;

  const PolymarketApiException({
    required this.statusCode,
    required this.message,
    this.body,
  });

  @override
  String toString() =>
      'PolymarketApiException($statusCode): $message${body != null ? '\n$body' : ''}';
}

/// HTTP transport for making REST API calls to Polymarket.
///
/// Supports GET and POST requests with optional auth headers.
class HttpTransport {
  final http.Client _client;

  HttpTransport({http.Client? client}) : _client = client ?? http.Client();

  /// GET request. Returns decoded JSON.
  Future<dynamic> get(
    String baseUrl,
    String path, {
    Map<String, String>? queryParams,
    Map<String, String>? headers,
  }) async {
    var uri = Uri.parse('$baseUrl$path');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    final response = await _client.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...?headers,
      },
    );

    return _handleResponse(response);
  }

  /// POST request with JSON body. Returns decoded JSON.
  Future<dynamic> post(
    String baseUrl,
    String path, {
    dynamic body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final encodedBody = body != null ? jsonEncode(body) : null;

    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...?headers,
      },
      body: encodedBody,
    );

    return _handleResponse(response);
  }

  /// DELETE request. Returns decoded JSON.
  Future<dynamic> delete(
    String baseUrl,
    String path, {
    dynamic body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final encodedBody = body != null ? jsonEncode(body) : null;

    final request = http.Request('DELETE', uri);
    request.headers['Content-Type'] = 'application/json';
    if (headers != null) request.headers.addAll(headers);
    if (encodedBody != null) request.body = encodedBody;

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PolymarketApiException(
        statusCode: response.statusCode,
        message: '${response.statusCode} ${response.reasonPhrase}',
        body: response.body,
      );
    }

    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  /// Close the underlying HTTP client.
  void close() => _client.close();
}
