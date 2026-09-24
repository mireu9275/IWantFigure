import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwantfigure/models/analysis.dart';
import 'package:iwantfigure/services/mock_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('MockAnalyzeApi loads the bundled sample and stamps provider=mock', () async {
    const api = MockAnalyzeApi(delay: Duration.zero);
    final r = await api.analyze(Uint8List(0), locale: 'ko');
    expect(r.provider, 'mock');
    expect(r.analysisId, startsWith('mock-'));
    expect(r.layoutType, LayoutType.bridgeParallel);
    expect(r.targetPrize?.id, 'box1');
    expect(r.machine.clawCount, 2);
    // Round-trips through JSON unchanged.
    final again = AnalysisResult.fromJson(r.toJson());
    expect(again.provider, 'mock');
    expect(again.objects.length, r.objects.length);
  });

  test('MockAnalyzeApi honours the delay', () async {
    const api = MockAnalyzeApi(delay: Duration(milliseconds: 30));
    final sw = Stopwatch()..start();
    await api.analyze(Uint8List(0), locale: 'en');
    expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(25));
  });
}
