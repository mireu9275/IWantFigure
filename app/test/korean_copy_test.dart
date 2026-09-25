/// Korean screens are plain Korean: no Japanese words or characters anywhere
/// in the Korean copy. The only Japanese on a Korean screen is the guide
/// page's "일본 명칭" line, which prints `LayoutType.labelJa` on purpose.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwantfigure/engine/aim_engine.dart';
import 'package:iwantfigure/l10n/guide_content.dart';
import 'package:iwantfigure/models/analysis.dart';

import 'helpers.dart';

/// Hiragana, katakana and CJK ideographs.
final _japanese = RegExp('[぀-ヿ一-鿿]');

void main() {
  test('every Korean string in strings.dart is free of Japanese', () {
    final source = File('lib/l10n/strings.dart').readAsStringSync();
    // The Korean text is the first string literal of each _t(ko, ja, en) call.
    final calls = RegExp(r"_t\(\s*'((?:[^'\\]|\\.)*)'").allMatches(source).toList();
    expect(calls.length, greaterThan(200), reason: 'the parser should see every _t call');
    final offenders = [
      for (final m in calls)
        if (_japanese.hasMatch(m.group(1)!)) m.group(1)!,
    ];
    expect(offenders, isEmpty);
  });

  test('Korean layout and technique names carry no Japanese suffix', () {
    final s = stringsFor('ko');
    for (final t in LayoutType.values) {
      expect(_japanese.hasMatch(s.layoutLabel(t)), isFalse, reason: s.layoutLabel(t));
    }
    for (final t in Technique.values) {
      expect(_japanese.hasMatch(s.techniqueLabel(t)), isFalse, reason: s.techniqueLabel(t));
    }
    // English keeps the Japanese name in parentheses for players in Japan.
    expect(stringsFor('en').layoutLabel(LayoutType.bridgeParallel), contains(LayoutType.bridgeParallel.labelJa));
  });

  test('every Korean guide is free of Japanese', () {
    final s = stringsFor('ko');
    for (final type in LayoutType.values) {
      for (final line in guideFor(type, s).allText) {
        expect(_japanese.hasMatch(line), isFalse, reason: '$type: "$line"');
      }
    }
  });

  test('the engine writes plain Korean for every layout and technique', () {
    const engine = AimEngine();
    // The analysis' own free text (from the LLM or the sample) is not the
    // engine's; clear it so only engine-written Korean is checked.
    final base = sampleAnalysis().copyWith(explanation: '', warnings: const [], needsMorePhotos: const []);
    for (final layout in LayoutType.values) {
      final techniques = [...?AimEngine.validTechniques[layout], Technique.unknown];
      for (final technique in techniques) {
        final r = base.copyWith(layoutType: layout, strategy: Strategy(technique: technique, targetObjectId: 'box1'));
        final plan = engine.plan(r, locale: 'ko');
        final texts = [
          ...plan.rationale,
          ...plan.warnings,
          ...plan.abortIf,
          ...plan.requestedPhotos,
          for (final step in plan.steps) ...[step.title, step.detail],
          if (plan.scene.motion case final motion?) motion.description,
          for (final box in plan.scene.boxes) box.label,
          for (final marker in plan.scene.markers) marker.label,
        ];
        for (final text in texts) {
          expect(_japanese.hasMatch(text), isFalse, reason: '$layout/$technique: "$text"');
        }
      }
    }
  });
}
