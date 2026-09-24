/// HTTP client for the IWantFigure analysis server.
///
/// Contract (implemented here, server built separately):
/// `POST {baseUrl}/api/v1/analyze` with `Content-Type: application/json` and
/// an optional `X-App-Key` header. Body:
/// `{"image_base64", "mime", "locale", "hints": {machine_family, claw_count,
/// prize_size_mm, notes}}`. A 200 response is the JSON that
/// `AnalysisResult.fromJson` expects. Errors carry
/// `{"error": <code>, "message": <human detail>?}` for 4xx and
/// `{"error": "provider_error", "provider_message": "..."}` for 502.
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
  const ApiException(this.statusCode, super.message, {this.code, this.providerMessage});

  /// Error codes the server uses in its `error` field.
  static const codeUnauthorized = 'unauthorized';
  static const codeRateLimited = 'rate_limited';
  static const codeProviderNotConfigured = 'provider_not_configured';
  static const codeProviderError = 'provider_error';

  /// HTTP status; 0 when the body could not be parsed.
  final int statusCode;

  /// The server's machine-readable `error` code, when the body had one.
  final String? code;

  /// The upstream provider's message when the server relays one.
  final String? providerMessage;

  bool get isUnauthorized => code == codeUnauthorized || statusCode == 401;
  bool get isRateLimited => code == codeRateLimited || statusCode == 429;
  bool get isProviderNotConfigured => code == codeProviderNotConfigured;
  bool get isProviderError => code == codeProviderError || statusCode == 502;

  @override
  String toString() =>
      'ApiException($statusCode${code == null ? '' : ' $code'}): $message'
      '${providerMessage == null ? '' : ' [$providerMessage]'}';
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
///
/// Instances created without a [client] share one process-wide
/// [http.Client] (keep-alive connections are reused and nothing leaks when a
/// session ends). A caller-supplied client stays owned by the caller.
class AnalyzeApi implements AnalysisService {
  AnalyzeApi({
    required String baseUrl,
    this.appKey = '',
    http.Client? client,
    this.timeout = defaultTimeout,
  })  : baseUrl = _trimSlash(baseUrl),
        _client = client ?? sharedClient;

  static const path = '/api/v1/analyze';

  /// The server allows 30 s per provider call plus one retry; leave headroom.
  static const defaultTimeout = Duration(seconds: 75);

  /// Client used by every [AnalyzeApi] that was not given its own.
  static final http.Client sharedClient = http.Client();

  final String baseUrl;
  final String appKey;
  final Duration timeout;
  final http.Client _client;

  /// The underlying HTTP client (shared unless one was injected).
  http.Client get client => _client;

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

  /// Builds the exception for a non-200 response: `message` is the server's
  /// human-readable `message` when present, else its `error` code, else the
  /// HTTP status; `code` and `provider_message` are kept separately.
  static ApiException _errorFrom(http.Response res) {
    String message = 'HTTP ${res.statusCode}';
    String? code;
    String? provider;
    try {
      final j = jsonDecode(utf8.decode(res.bodyBytes));
      if (j is Map<String, dynamic>) {
        final e = j['error'];
        if (e is String && e.isNotEmpty) {
          code = e;
          message = e;
        }
        final m = j['message'];
        if (m is String && m.isNotEmpty) message = m;
        final p = j['provider_message'];
        if (p is String && p.isNotEmpty) provider = p;
      }
    } on FormatException {
      // Non-JSON error body; keep the status message.
    }
    return ApiException(res.statusCode, message, code: code, providerMessage: provider);
  }

  static String _trimSlash(String s) {
    var v = s.trim();
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    return v;
  }

  /// Closes the client only when this instance was given a private one; the
  /// shared client lives for the whole process.
  void close() {
    if (!identical(_client, sharedClient)) _client.close();
  }
}
