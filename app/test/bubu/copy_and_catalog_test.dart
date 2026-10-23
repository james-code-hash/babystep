import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/bubu/bubu_view.dart';
import 'package:little_steps/bubu/catalog.dart';
import 'package:little_steps/bubu/greeting.dart';
import 'package:little_steps/bubu/look.dart';
import 'package:little_steps/copy/bubu.dart';
import 'package:little_steps/copy/line.dart';
import 'package:little_steps/domain/models.dart';

import '../helpers/test_app.dart';

void main() {
  final rules = loadCopyRules();

  void expectClean(Line line, String where) {
    for (final tone in AgeTone.values) {
      final text = line.of(tone);
      expect(text.trim(), isNotEmpty, reason: where);
      expect(rules.check(text, tone: tone, checkLength: true), isEmpty, reason: '$where ($tone): $text');
      expect(text.runes.length, lessThanOrEqualTo(60), reason: where);
    }
  }

  group('catalog', () {
    for (final (name, items) in [
      ('hats', BubuCatalog.hats),
      ('necks', BubuCatalog.necks),
      ('colors', BubuCatalog.colors),
    ]) {
      test('$name ids are unique and names pass copy rules', () {
        final ids = items.map((a) => a.id).toList();
        expect(ids.toSet().length, ids.length);
        expect(items.length, greaterThan(1));
        for (final a in items) {
          expectClean(a.name, '$name/${a.id}');
        }
      });
    }

    test('defaults exist and DressUp.initial points into the catalog', () {
      expect(BubuCatalog.hats.map((a) => a.id), contains('none'));
      expect(BubuCatalog.necks.map((a) => a.id), contains('none'));
      expect(BubuCatalog.colors.map((a) => a.id), contains('cream'));
      expect(BubuCatalog.hats.first.id, DressUp.initial.hat);
      expect(BubuCatalog.necks.first.id, DressUp.initial.neck);
      expect(BubuCatalog.colors.first.id, DressUp.initial.color);
    });

    test('nothing award-like in the catalog', () {
      const awardish = ['crown', 'medal', 'trophy', 'badge', 'gold', 'star'];
      for (final a in [...BubuCatalog.hats, ...BubuCatalog.necks, ...BubuCatalog.colors]) {
        for (final w in awardish) {
          expect(a.id, isNot(contains(w)));
        }
        for (final w in ['皇冠', '獎', '徽章', '金牌']) {
          expect(a.name.lively + a.name.concise, isNot(contains(w)));
        }
      }
    });
  });

  group('greeting', () {
    test('every greeting line passes copy rules in both tones', () {
      for (final pool in allGreetingPools) {
        expect(pool.length, greaterThan(0));
        for (final line in pool.lines) {
          expectClean(line, 'greeting');
        }
      }
    });

    test('concise lines drop the lively particles', () {
      for (final pool in allGreetingPools) {
        for (final line in pool.lines) {
          expect(line.concise, isNot(contains('～')), reason: line.concise);
          expect(line.concise, isNot(contains('！')), reason: line.concise);
        }
      }
    });

    test('never refers to absence or how long since last visit', () {
      const absence = ['好久', '終於', '等你', '幾天', '沒來', '又來', '回來了', '想你'];
      for (final pool in allGreetingPools) {
        for (final line in pool.lines) {
          for (final w in absence) {
            expect(line.lively + line.concise, isNot(contains(w)));
          }
        }
      }
    });

    test('greeting is deterministic for a seed and comes from the right pools', () {
      for (var h = 0; h < 24; h++) {
        for (final month in [1, 4, 7, 10]) {
          final now = DateTime(2026, month, 5, h);
          for (final tone in AgeTone.values) {
            final a = greeting(tone, now, Random(h * 31 + month));
            expect(greeting(tone, now, Random(h * 31 + month)), a);
            final allowed = {
              ...dayPartGreetings(dayPartOf(now)).lines.map((l) => l.of(tone)),
              ...seasonalGreetings(seasonOf(now)).lines.map((l) => l.of(tone)),
            };
            expect(allowed, contains(a));
          }
        }
      }
    });

    test('over many draws both time-of-day and seasonal lines appear', () {
      final now = DateTime(2026, 10, 23, 8);
      final r = Random(7);
      final seen = {for (var i = 0; i < 200; i++) greeting(AgeTone.lively, now, r)};
      final seasonal = seasonalGreetings(Season.autumn).lines.map((l) => l.lively).toSet();
      final morning = dayPartGreetings(DayPart.morning).lines.map((l) => l.lively).toSet();
      expect(seen.intersection(seasonal), isNotEmpty);
      expect(seen.intersection(morning), isNotEmpty);
    });
  });

  test('semantics descriptions pass copy rules', () {
    for (final e in BubuExpression.values) {
      expectClean(semanticsFor(e), 'semantics/$e');
    }
    expectClean(BubuCopy.semanticsThinking, 'semantics/thinking');
  });

  test('only the six allowed expressions exist', () {
    expect(
      BubuExpression.values.map((e) => e.name).toSet(),
      {'happy', 'curious', 'caring', 'calm', 'surprised', 'relaxed'},
    );
  });
}
