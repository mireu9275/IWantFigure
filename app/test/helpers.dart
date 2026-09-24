/// Shared helpers for the widget and service tests.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwantfigure/app/app.dart';
import 'package:iwantfigure/l10n/strings.dart';
import 'package:iwantfigure/models/analysis.dart';
import 'package:iwantfigure/services/api_client.dart';
import 'package:iwantfigure/services/history_store.dart';
import 'package:iwantfigure/services/image_prep.dart';
import 'package:iwantfigure/services/settings.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The bundled sample JSON as text.
String sampleJsonText() =>
    File('assets/samples/bridge_parallel.json').readAsStringSync();

/// The bundled sample parsed.
AnalysisResult sampleAnalysis() =>
    AnalysisResult.fromJson(jsonDecode(sampleJsonText()) as Map<String, dynamic>);

/// Renders a small PNG with `dart:ui` so widgets have a real image to decode.
Future<Uint8List> fakePngBytes({int width = 64, int height = 48}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFF334455),
  );
  canvas.drawCircle(
    Offset(width / 2, height / 2),
    width / 4,
    Paint()..color = const Color(0xFFFFCC00),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// A [PickedPhoto] around [fakePngBytes].
Future<PickedPhoto> fakePhoto() async {
  final bytes = await fakePngBytes();
  return PickedPhoto(bytes: bytes, width: 64, height: 48, path: null);
}

/// An [AnalysisService] that returns [result] immediately (or throws).
class FakeAnalysisService implements AnalysisService {
  FakeAnalysisService(this.result, {this.error});

  final AnalysisResult result;
  final Object? error;
  int calls = 0;
  String? lastLocale;
  AnalyzeHints? lastHints;

  @override
  Future<AnalysisResult> analyze(Uint8List jpegBytes,
      {required String locale, AnalyzeHints? hints}) async {
    calls++;
    lastLocale = locale;
    lastHints = hints;
    if (error != null) throw error!;
    return result;
  }
}

/// A picker that never opens the OS UI.
class FakeImagePicker extends ImagePicker {
  FakeImagePicker([this.file]);

  final XFile? file;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async =>
      file;
}

/// Builds a loaded [SettingsStore] on top of mock preferences.
Future<SettingsStore> loadedSettings({Map<String, Object> initial = const {}}) async {
  SharedPreferences.setMockInitialValues(initial);
  final s = SettingsStore();
  await s.load();
  return s;
}

/// Wraps [home] in the full app shell with the given services.
Widget testApp({
  required SettingsStore settings,
  required HistoryStore history,
  Widget? home,
  AnalysisService? service,
  PhotoPicker? picker,
}) =>
    IWantFigureApp(
      settings: settings,
      history: history,
      home: home,
      serviceOverride: service,
      picker: picker ?? PhotoPicker(picker: FakeImagePicker()),
    );

/// Localized strings for [code] without a widget tree.
S stringsFor(String code) => S(AppLocale.fromCode(code));

/// Lets real asynchronous IO started from the widget tree (file writes,
/// image decoding) make progress: the automated binding only flushes the
/// fake-async microtask queue around `runAsync`, so each IO hop needs a round.
Future<void> settleRealIO(WidgetTester tester, {int rounds = 30}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
}

/// Phone-sized viewport (432 × 960 logical px).
void usePhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
}

/// A throw-away history directory for a test.
Directory tempHistoryDir(String tag) =>
    Directory.systemTemp.createTempSync('iwf_history_$tag');
