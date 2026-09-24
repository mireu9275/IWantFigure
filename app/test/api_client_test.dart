import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iwantfigure/models/analysis.dart';
import 'package:iwantfigure/services/api_client.dart';

import 'helpers.dart';

void main() {
  final bytes = Uint8List.fromList(List<int>.generate(32, (i) => i));

  test('posts the contract body and parses a 200 response', () async {
    http.Request? seen;
    final client = MockClient((req) async {
      seen = req;
      return http.Response(sampleJsonText(), 200, headers: {'content-type': 'application/json'});
    });
    final api = AnalyzeApi(baseUrl: 'http://example.test/', appKey: 'k-123', client: client);
    final result = await api.analyze(
      bytes,
      locale: 'ja',
      hints: const AnalyzeHints(clawCount: 2, prizeSizeMm: [150, 200, 100], notes: 'n'),
    );

    expect(api.endpoint.toString(), 'http://example.test/api/v1/analyze');
    expect(seen!.method, 'POST');
    expect(seen!.url.toString(), 'http://example.test/api/v1/analyze');
    expect(seen!.headers['Content-Type'], startsWith('application/json'));
    expect(seen!.headers['X-App-Key'], 'k-123');
    final body = jsonDecode(seen!.body) as Map<String, dynamic>;
    expect(body['image_base64'], base64Encode(bytes));
    expect(body['mime'], 'image/jpeg');
    expect(body['locale'], 'ja');
    expect(body['hints'], {
      'machine_family': null,
      'claw_count': 2,
      'prize_size_mm': [150, 200, 100],
      'notes': 'n',
    });

    expect(result.layoutType, LayoutType.bridgeParallel);
    expect(result.objects.length, 5);
    expect(result.strategy.technique, Technique.tateHame);
  });

  test('omits X-App-Key when empty and sends null hints by default', () async {
    http.Request? seen;
    final client = MockClient((req) async {
      seen = req;
      return http.Response(sampleJsonText(), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });
    final api = AnalyzeApi(baseUrl: 'http://h', client: client);
    await api.analyze(bytes, locale: 'ko');
    expect(seen!.headers.containsKey('X-App-Key'), isFalse);
    final body = jsonDecode(seen!.body) as Map<String, dynamic>;
    expect(body['hints'], {
      'machine_family': null,
      'claw_count': null,
      'prize_size_mm': null,
      'notes': null,
    });
  });

  test('non-200 becomes ApiException with status, message and provider message', () async {
    final client = MockClient((req) async => http.Response(
          jsonEncode({'error': 'upstream down', 'provider_message': 'rate limited'}),
          503,
        ));
    final api = AnalyzeApi(baseUrl: 'http://h', client: client);
    await expectLater(
      api.analyze(bytes, locale: 'en'),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'statusCode', 503)
          .having((e) => e.message, 'message', 'upstream down')
          .having((e) => e.providerMessage, 'providerMessage', 'rate limited')),
    );
  });

  test('401 with a non-JSON body still yields an ApiException', () async {
    final client = MockClient((req) async => http.Response('nope', 401));
    final api = AnalyzeApi(baseUrl: 'http://h', client: client);
    await expectLater(
      api.analyze(bytes, locale: 'en'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
    );
  });

  test('malformed 200 body yields ApiException(0)', () async {
    final client = MockClient((req) async => http.Response('{not json', 200));
    final api = AnalyzeApi(baseUrl: 'http://h', client: client);
    await expectLater(
      api.analyze(bytes, locale: 'en'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 0)),
    );
  });

  test('connection failures become NetworkException', () async {
    final client = MockClient((req) async => throw http.ClientException('refused'));
    final api = AnalyzeApi(baseUrl: 'http://h', client: client);
    await expectLater(api.analyze(bytes, locale: 'en'), throwsA(isA<NetworkException>()));
  });

  test('slow servers become ApiTimeoutException', () async {
    final client = MockClient((req) async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return http.Response(sampleJsonText(), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });
    final api = AnalyzeApi(baseUrl: 'http://h', client: client, timeout: const Duration(milliseconds: 20));
    await expectLater(api.analyze(bytes, locale: 'en'), throwsA(isA<ApiTimeoutException>()));
  });
}
