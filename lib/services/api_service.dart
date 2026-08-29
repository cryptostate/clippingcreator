import 'dart:convert';
import 'package:http/http.dart' as http;

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// HTTP client for all backend API calls.
///
/// Handles JSON serialization, error responses, and base URL configuration.
class ApiService {
  static String activeBaseUrl = _getDefaultBaseUrl();
  String get baseUrl => activeBaseUrl;
  
  final http.Client _client;
  final Map<String, String> _defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  ApiService({http.Client? client})
      : _client = client ?? http.Client();

  static String _getDefaultBaseUrl() {
    // Allows overriding via --dart-define=API_BASE_URL=https://...
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;

    if (kIsWeb) {
      return 'https://clippingcreator.onrender.com';
    }
    try {
      if (Platform.isAndroid) {
        return 'https://clippingcreator.onrender.com';
      }
    } catch (_) {
      // Platform not supported or web
    }
    return 'https://clippingcreator.onrender.com';
  }

  // ── Jobs ──────────────────────────────────────────────────────────────

  /// Create a new processing job.
  Future<Map<String, dynamic>> createJob(String youtubeUrl) async {
    return _post('/api/jobs', body: {'youtube_url': youtubeUrl});
  }

  /// Get the current state of a job.
  Future<Map<String, dynamic>> getJob(String jobId) async {
    return _get('/api/jobs/$jobId');
  }

  /// Delete / cancel a job.
  Future<Map<String, dynamic>> deleteJob(String jobId) async {
    return _delete('/api/jobs/$jobId');
  }

  // ── Rendering ─────────────────────────────────────────────────────────

  /// Request a clip render.
  Future<Map<String, dynamic>> renderClip(
    String jobId,
    Map<String, dynamic> renderConfig,
  ) async {
    return _post('/api/jobs/$jobId/render', body: renderConfig);
  }

  /// List rendered clips for a job.
  Future<Map<String, dynamic>> getClips(String jobId) async {
    return _get('/api/jobs/$jobId/clips');
  }

  // ── HTTP helpers ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _get(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await _client.get(uri, headers: _defaultHeaders);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> _post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await _client.post(
      uri,
      headers: _defaultHeaders,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> _delete(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await _client.delete(uri, headers: _defaultHeaders);
    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    // Try to extract error message from JSON response
    String errorMessage = 'Request failed with status ${response.statusCode}';
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body.containsKey('detail')) {
        errorMessage = body['detail'].toString();
      }
    } catch (_) {
      // Use default error message
    }

    throw ApiException(response.statusCode, errorMessage);
  }

  void dispose() {
    _client.close();
  }
}

/// Exception thrown when an API request fails.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
