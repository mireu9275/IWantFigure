import 'package:flutter_test/flutter_test.dart';
import 'package:iwantfigure/l10n/guide_content.dart';
import 'package:iwantfigure/models/analysis.dart';

import 'helpers.dart';

void main() {
  const locales = ['ko', 'ja', 'en'];

  /// Words that would promise a win; none may appear anywhere in the guide.
  const banned = ['보장', '保証', 'guarantee'];

  bool promisesWin(String text) {
    final lower = text.toLowerCase();
    return banned.any(lower.contains);
  }

  /// First token of the Japanese community name, e.g. '橋渡し' from
  /// '橋渡し(平行)' or 'D環' from 'D環 / Oリング'.
  String jaKeyTerm(LayoutType t) => t.labelJa.split(RegExp(r'[ (/]')).first;

  for (final code in locales) {
    final s = stringsFor(code);

    test('every LayoutType has a complete guide in $code', () {
      for (final type in LayoutType.values) {
        final g = guideFor(type, s);
        expect(g.type, type);
        expect(g.summary.trim(), isNotEmpty, reason: '$type summary');
        expect(g.recognize.length, inInclusiveRange(3, 6), reason: '$type recognize');
        expect(g.howTo.length, inInclusiveRange(4, 8), reason: '$type howTo');
        expect(g.tips.length, inInclusiveRange(2, 4), reason: '$type tips');
        expect(g.abortWhen.length, inInclusiveRange(2, 3), reason: '$type abortWhen');
        expect(g.typicalCost.trim(), isNotEmpty, reason: '$type cost');
        for (final line in g.allText) {
          expect(line.trim(), isNotEmpty, reason: '$type has an empty line');
        }
        if (type == LayoutType.unknown) {
          expect(g.techniques, isEmpty, reason: 'no technique is recommended for an unidentified layout');
        } else {
          expect(g.techniques, isNotEmpty, reason: '$type techniques');
          expect(g.techniques, isNot(contains(Technique.unknown)));
          expect(g.techniques.toSet().length, g.techniques.length, reason: '$type has duplicate techniques');
          // The Japanese community term stays in the Japanese and English text;
          // Korean screens are plain Korean (the name is shown once on the page).
          if (code != 'ko') {
            expect(g.summary, contains(jaKeyTerm(type)), reason: '$type summary should name ${jaKeyTerm(type)}');
          }
          expect(g.typicalCost, contains('★'), reason: '$type cost is a community reference value');
        }
      }
    });

    test('no guide string promises a win in $code', () {
      for (final type in LayoutType.values) {
        for (final line in guideFor(type, s).allText) {
          expect(promisesWin(line), isFalse, reason: '$type/$code: "$line"');
        }
      }
      for (final ui in [
        s.guideTitle,
        s.guideSubtitle,
        s.guideOpenThis,
        s.guideAboutLayout,
        s.guideRecognize,
        s.guideHowTo,
        s.guideTechniques,
        s.guideTips,
        s.guideAbort,
        s.guideCost,
        s.guideCostNote,
        s.clawRotationTitle,
        s.clawRotationHint,
        for (final r in ClawRotation.values) s.clawRotationLabel(r),
        for (final r in ClawRotation.values) s.clawRotationShort(r),
        for (final r in ClawRotation.values) s.labelRotation(r),
      ]) {
        expect(ui.trim(), isNotEmpty);
        expect(promisesWin(ui), isFalse, reason: '"$ui"');
      }
    });
  }

  test('the unknown guide tells the player to re-shoot from another angle', () {
    expect(guideFor(LayoutType.unknown, stringsFor('ko')).summary, contains('다시 촬영'));
    expect(guideFor(LayoutType.unknown, stringsFor('ja')).summary, contains('撮り直'));
    expect(guideFor(LayoutType.unknown, stringsFor('en')).summary.toLowerCase(), contains('re-shoot'));
  });

  test('guides are translated, not shared, between locales', () {
    for (final type in LayoutType.values) {
      final ko = guideFor(type, stringsFor('ko'));
      final ja = guideFor(type, stringsFor('ja'));
      final en = guideFor(type, stringsFor('en'));
      expect(ko.summary, isNot(ja.summary), reason: '$type ko/ja');
      expect(ja.summary, isNot(en.summary), reason: '$type ja/en');
      expect(ko.howTo.first, isNot(en.howTo.first), reason: '$type ko/en');
      // Structure is identical across languages.
      expect(ja.howTo.length, ko.howTo.length);
      expect(en.howTo.length, ko.howTo.length);
      expect(ja.recognize.length, ko.recognize.length);
      expect(en.recognize.length, ko.recognize.length);
      expect(ja.techniques, ko.techniques);
      expect(en.techniques, ko.techniques);
    }
  });

  test('every layout type has an icon and rotation labels are distinct', () {
    final icons = LayoutType.values.map(layoutIcon).toList();
    expect(icons.toSet().length, icons.length, reason: 'icon must be unique per layout');
    for (final code in locales) {
      final s = stringsFor(code);
      final labels = ClawRotation.values.map(s.clawRotationLabel).toList();
      expect(labels.toSet().length, labels.length);
      // Direction is conveyed by Material icons, not by arrow glyphs that
      // some fonts lack; the text must stay glyph-free.
      expect(s.clawRotationLabel(ClawRotation.clockwise), isNot(contains('↻')));
      expect(s.clawRotationShort(ClawRotation.clockwise), isNot(contains('↻')));
      expect(s.clawRotationShort(ClawRotation.clockwise), isNot(equals(s.clawRotationShort(ClawRotation.counterClockwise))));
      expect(s.labelExtraBar(3), contains('3'));
    }
  });
}
