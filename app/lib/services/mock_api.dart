/// Offline analysis provider that returns the bundled sample.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import '../models/analysis.dart';
import 'api_client.dart';

/// Loads `assets/samples/bridge_parallel.json` after a short delay so the
/// app can be exercised without a server. The result is stamped with
/// provider `mock`.
class MockAnalyzeApi implements AnalysisService {
  const MockAnalyzeApi({
    this.delay = const Duration(milliseconds: 1200),
    this.asset = defaultAsset,
  });

  static const defaultAsset = 'assets/samples/bridge_parallel.json';

  final Duration delay;
  final String asset;

  @override
  Future<AnalysisResult> analyze(
    Uint8List jpegBytes, {
    required String locale,
    AnalyzeHints? hints,
  }) async {
    final text = await rootBundle.loadString(asset);
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    final json = jsonDecode(text) as Map<String, dynamic>;
    json['analysis_id'] = 'mock-${DateTime.now().millisecondsSinceEpoch}';
    json['provider'] = 'mock';
    json['model'] = 'sample:${asset.split('/').last}';
    json['latency_ms'] = delay.inMilliseconds;
    return AnalysisResult.fromJson(json);
  }
}
