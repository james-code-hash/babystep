import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/bubu/catalog.dart';
import 'package:little_steps/bubu/look.dart';
import 'package:little_steps/domain/models.dart';

void main() {
  final colorIds = BubuCatalog.colors.map((a) => a.id).toList();

  test('every catalog color has a palette and vice versa', () {
    expect(bubuPalettes.keys.toSet(), colorIds.toSet());
  });

  test('season follows Taiwan (northern hemisphere) months', () {
    const expected = {
      1: Season.winter,
      2: Season.winter,
      3: Season.spring,
      4: Season.spring,
      5: Season.spring,
      6: Season.summer,
      7: Season.summer,
      8: Season.summer,
      9: Season.autumn,
      10: Season.autumn,
      11: Season.autumn,
      12: Season.winter,
    };
    expected.forEach((m, s) => expect(seasonOf(DateTime(2026, m, 15)), s, reason: 'month $m'));
  });

  test('day parts cover all 24 hours', () {
    final parts = {for (var h = 0; h < 24; h++) h: dayPartOf(DateTime(2026, 10, 23, h))};
    expect(parts[7], DayPart.morning);
    expect(parts[13], DayPart.day);
    expect(parts[18], DayPart.evening);
    expect(parts[22], DayPart.night);
    expect(parts[2], DayPart.night);
    expect(parts.values.toSet(), DayPart.values.toSet());
  });

  test('look is deterministic and depends only on dressUp and the month/hour', () {
    for (final color in colorIds) {
      for (final hat in BubuCatalog.hats) {
        final d = DressUp(hat: hat.id, neck: 'scarf', color: color);
        for (var m = 1; m <= 12; m++) {
          for (var h = 0; h < 24; h++) {
            final t = DateTime(2026, m, 10, h, 5);
            final a = look(d, t);
            // 同樣的輸入 → 同樣的輸出。
            expect(look(d, t), a);
            // 同月同小時，換分鐘、換日、換年都一樣。
            expect(look(d, DateTime(2026, m, 20, h, 55, 30)), a);
            expect(look(DressUp(hat: hat.id, neck: 'scarf', color: color), DateTime(2031, m, 3, h)), a);
            expect(a.hat, hat.id);
            expect(a.neck, 'scarf');
            expect(a.season, seasonOf(t));
            expect(a.dayPart, dayPartOf(t));
            expect(a.ambient, isNotEmpty);
          }
        }
      }
    }
  });

  test('changing the color changes the palette; night softens it', () {
    final noon = DateTime(2026, 10, 23, 12);
    final palettes = {for (final c in colorIds) look(DressUp(color: c), noon).palette};
    expect(palettes.length, colorIds.length);
    final night = look(DressUp.initial, DateTime(2026, 10, 23, 22));
    expect(night.palette, isNot(look(DressUp.initial, noon).palette));
    expect(night.ambient, containsAll([Ambient.moon, Ambient.stars]));
  });

  test('seasonal ambient decorations', () {
    Ambient seasonal(int month) => look(DressUp.initial, DateTime(2026, month, 1, 12)).ambient.first;
    expect(seasonal(4), Ambient.petals);
    expect(seasonal(7), Ambient.sparkle);
    expect(seasonal(10), Ambient.leaf);
    expect(seasonal(1), Ambient.snowflake);
    expect(look(DressUp.initial, DateTime(2026, 10, 1, 18)).ambient, contains(Ambient.sunsetGlow));
  });

  test('unknown ids fall back to defaults instead of breaking', () {
    final a = look(const DressUp(hat: 'crown', neck: 'medal', color: 'gold'), DateTime(2026, 10, 23, 12));
    expect(a.hat, 'none');
    expect(a.neck, 'none');
    expect(a.palette, bubuPalettes['cream']);
  });

  test('bubu/ never reads plan/review/app state (bottom line 2)', () {
    final files = Directory('lib/bubu').listSync().whereType<File>().where((f) => f.path.endsWith('.dart'));
    expect(files, isNotEmpty);
    final directive = RegExp(r'''^\s*(import|export)\s+['"]([^'"]+)['"]''', multiLine: true);
    for (final f in files) {
      if (f.path.endsWith('bubu_inputs.dart')) continue;
      for (final m in directive.allMatches(f.readAsStringSync())) {
        final i = m.group(2)!;
        for (final banned in ['providers.dart', 'data/', 'features/', 'lesson', 'parent_view', 'repository']) {
          expect(i, isNot(contains(banned)), reason: '${f.path} imports $i');
        }
      }
    }
  });
}
