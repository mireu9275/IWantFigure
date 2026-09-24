/// HTTP client for the IWantFigure analysis server.
///
/// Contract (implemented here, server built separately):
/// `POST {baseUrl}/api/v1/analyze` with `Content-Type: application/json` and
/// an optional `X-App-Key` header. Body:
/// `{"image_base64", "mime", "locale", "hints": {machine_family, claw_count,
/// prize_size_mm, notes}}`. A 200 response is the JSON that
/// `AnalysisResult.fromJson` expects; 400/401/502/503 carry
/// `{"error": "...", "provider_message": "..."?}`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/analysis.dart';

/// Optional hints the client can send along with the photo.
class AnalyzeHints {
  const AnalyzeHints({
    this.machineFamily,
    this.clawCount,
    this.prizeSizeMm,
    this.notes,
  });

  final String? machineFamily;

  /// 2 or 3; null when unknown.
  final int? clawCount;

  /// `[width, depth, height]` in millimetres.
  final List<double>? prizeSizeMm;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'machine_family': machineFamily,
        'claw_count': clawCount,
        'prize_size_mm': prizeSizeMm,
        'notes': notes,
      };
}

/// Common interface of the real and the mock analysis providers.
abstract class AnalysisService {
  Future<AnalysisResult> analyze(
    Uint8List jpegBytes, {
    required String locale,
    AnalyzeHints? hints,
  });
}

/// Base class of every error the analysis services throw.
sealed class AnalysisException implements Exception {
  const AnalysisException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The server answered with a non-200 status (400/401/502/503 …) or an
/// unparseable body.
class ApiException extends AnalysisException {
  const ApiException(this.statusCode, super.message, {this.providerMessage});

  /// HTTP status; 0 when the body could not be parsed.
  final int statusCode;

  /// The upstream provider's message when the server relays one.
  final String? providerMessage;

  @override
  String toString() =>
      'ApiException($statusCode): $message${providerMessage == null ? '' : ' [$providerMessage]'}';
}

/// The server could not be reached (DNS, refused connection, TLS …).
class NetworkException extends AnalysisException {
  const NetworkException(super.message, [this.cause]);

  final Object? cause;
}

/// No response within the configured timeout.
class ApiTimeoutException extends AnalysisException {
  const ApiTimeoutException(this.timeout)
      : super('No response within $timeout');

  final Duration timeout;
}

/// Real HTTP implementation of [AnalysisService].
class AnalyzeApi implements AnalysisService {
  AnalyzeApi({
    required String baseUrl,
    this.appKey = '',
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
  })  : baseUrl = _trimSlash(baseUrl),
        _client = client ?? http.Client();

  static const path = '/api/v1/analyze';

  final String baseUrl;
  final String appKey;
  final Duration timeout;
  final http.Client _client;

  Uri get endpoint => Uri.parse('$baseUrl$path');

  @override
  Future<AnalysisResult> analyze(
    Uint8List jpegBytes, {
    required String locale,
    AnalyzeHints? hints,
  }) async {
    final body = jsonEncode({
      'image_base64': base64Encode(jpegBytes),
      'mime': 'image/jpeg',
      'locale': locale,
      'hints': (hints ?? const AnalyzeHints()).toJson(),
    });
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (appKey.isNotEmpty) 'X-App-Key': appKey,
    };

    final http.Response res;
    try {
      res = await _client
          .post(endpoint, headers: headers, body: body)
          .timeout(timeout);
    } on TimeoutException {
      throw ApiTimeoutException(timeout);
    } on SocketException catch (e) {
      throw NetworkException(e.message, e);
    } on http.ClientException catch (e) {
      throw NetworkException(e.message, e);
    } on HandshakeException catch (e) {
      throw NetworkException(e.message, e);
    }

    if (res.statusCode != 200) {
      throw _errorFrom(res);
    }
    final dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(res.bodyBytes));
    } on FormatException catch (e) {
      throw ApiException(0, 'Invalid JSON in response: ${e.message}');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException(0, 'Response is not a JSON object');
    }
    try {
      return AnalysisResult.fromJson(decoded);
    } on FormatException catch (e) {
      throw ApiException(0, 'Malformed analysis: ${e.message}');
    } on TypeError catch (e) {
      throw ApiException(0, 'Malformed analysis: $e');
    }
  }

  static ApiException _errorFrom(http.Response res) {
    String message = 'HTTP ${res.statusCode}';
    String? provider;
    try {
      final j = jsonDecode(utf8.decode(res.bodyBytes));
      if (j is Map<String, dynamic>) {
        final e = j['error'];
        if (e is String && e.isNotEmpty) message = e;
        final p = j['provider_message'];
        if (p is String && p.isNotEmpty) provider = p;
      }
    } on FormatException {
      // Non-JSON error body; keep the status message.
    }
    return ApiException(res.statusCode, message, providerMessage: provider);
  }

  static String _trimSlash(String s) {
    var v = s.trim();
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    return v;
  }

  void close() => _client.close();
}
