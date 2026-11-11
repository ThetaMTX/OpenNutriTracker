import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/utils/nutrition_label_parser.dart';

void main() {
  group('NutritionLabelParser', () {
    test('reads a Polish label with values on the same line', () {
      final values = NutritionLabelParser.parseText('''
Wartość odżywcza w 100 g
Wartość energetyczna 1580 kJ / 375 kcal
Tłuszcz 12 g
w tym kwasy tłuszczowe nasycone 5,1 g
Węglowodany 58 g
w tym cukry 22 g
Błonnik 3,0 g
Białko 6,5 g
Sól 0,45 g
''');
      expect(values.energyKcal, 375);
      expect(values.fat, 12);
      expect(values.saturatedFat, 5.1);
      expect(values.carbs, 58);
      expect(values.sugars, 22);
      expect(values.fiber, 3.0);
      expect(values.protein, 6.5);
      expect(values.salt, 0.45);
      expect(values.foundCount, 8);
      expect(values.energyMatchesMacros, isTrue);
    });

    test('takes the per 100 g column of a two-column English label', () {
      final values = NutritionLabelParser.parseText('''
Typical values Per 100g Per 30g serving
Energy 1690kJ 404kcal 507kJ 121kcal
Fat 15.2g 4.6g
of which saturates 6.1g 1.8g
Carbohydrate 59.0g 17.7g
of which sugars 30.1g 9.0g
Fibre 2.4g 0.7g
Protein 6.3g 1.9g
Salt 0.52g 0.16g
''');
      expect(values.energyKcal, 404);
      expect(values.fat, 15.2);
      expect(values.saturatedFat, 6.1);
      expect(values.carbs, 59.0);
      expect(values.sugars, 30.1);
      expect(values.fiber, 2.4);
      expect(values.protein, 6.3);
      expect(values.salt, 0.52);
    });

    test('pairs a name column with a value column read separately', () {
      final values = NutritionLabelParser.parseText('''
Nährwerte pro 100 g
Brennwert
Fett
davon gesättigte Fettsäuren
Kohlenhydrate
davon Zucker
Eiweiß
Salz
1580 kJ / 375 kcal
12 g
5,1 g
58 g
22 g
6,5 g
0,45 g
''');
      expect(values.energyKcal, 375);
      expect(values.fat, 12);
      expect(values.saturatedFat, 5.1);
      expect(values.carbs, 58);
      expect(values.sugars, 22);
      expect(values.protein, 6.5);
      expect(values.salt, 0.45);
    });

    test('reads "kJ/kcal 1580/375" and names without diacritics', () {
      final values = NutritionLabelParser.parseText('''
Wartosc odzywcza 100 g porcja
Wartosc energetyczna kJ/kcal 1580/375 395/94
Tluszcz 12g 3g
w tym kwasy tluszczowe nasycone 5,1g 1,3g
Weglowodany 58g 14,5g
w tym cukry 22g 5,5g
Bialko 6,5g 1,6g
Sol <0,01 g <0,01 g
''');
      expect(values.energyKcal, 375);
      expect(values.fat, 12);
      expect(values.saturatedFat, 5.1);
      expect(values.carbs, 58);
      expect(values.sugars, 22);
      expect(values.protein, 6.5);
      expect(values.salt, 0.01);
    });

    test('prefers kcal on the next line over kJ on the energy line', () {
      final values = NutritionLabelParser.parseText('''
Energy 1580 kJ
375 kcal
Fat 12 g
Carbohydrate 58 g
Protein 6.5 g
''');
      expect(values.energyKcal, 375);
      expect(values.fat, 12);
      expect(values.carbs, 58);
      expect(values.protein, 6.5);
    });

    test('converts kJ when the label has no kcal', () {
      final values = NutritionLabelParser.parseText('''
Energia 1569 kJ
Białko 7 g
''');
      expect(values.energyKcal, closeTo(375, 0.1));
      expect(values.protein, 7);
    });

    test('uses table rows when boxes are known', () {
      const lines = [
        LabelTextLine('Wartość odżywcza', left: 0, top: 0, right: 200, bottom: 20),
        LabelTextLine('100 g', left: 300, top: 0, right: 360, bottom: 20),
        LabelTextLine('porcja 30 g', left: 420, top: 0, right: 540, bottom: 20),
        LabelTextLine('Wartość energetyczna', left: 0, top: 30, right: 200, bottom: 50),
        LabelTextLine('1580 kJ/375 kcal', left: 300, top: 31, right: 420, bottom: 49),
        LabelTextLine('474 kJ/113 kcal', left: 430, top: 30, right: 560, bottom: 50),
        LabelTextLine('Tłuszcz', left: 0, top: 60, right: 80, bottom: 80),
        LabelTextLine('3,6 g', left: 430, top: 61, right: 470, bottom: 79),
        LabelTextLine('12 g', left: 300, top: 60, right: 340, bottom: 80),
        LabelTextLine('Białko', left: 0, top: 90, right: 70, bottom: 110),
        LabelTextLine('6,5 g', left: 300, top: 91, right: 340, bottom: 109),
        LabelTextLine('2 g', left: 430, top: 90, right: 460, bottom: 110),
      ];
      final values = NutritionLabelParser.parse(lines);
      expect(values.energyKcal, 375);
      expect(values.fat, 12);
      expect(values.protein, 6.5);
      expect(values.foundCount, 3);
    });

    test('finds nothing in text that is not a nutrition table', () {
      final values = NutritionLabelParser.parseText('''
Best before see top
Store in a cool dry place
''');
      expect(values.isEmpty, isTrue);
    });

    test('ignores values that cannot be per 100 g', () {
      final values = NutritionLabelParser.parseText('''
Fat 152 g
Protein 6 g
''');
      expect(values.fat, isNull);
      expect(values.protein, 6);
    });
  });

  group('NutritionLabelValues', () {
    test('turns salt into sodium in mg', () {
      const values = NutritionLabelValues(salt: 1.25);
      expect(values.sodiumMg, 500);
    });

    test('flags energy that does not match the macros', () {
      // 37 kcal read instead of 375: a dropped digit.
      const values = NutritionLabelValues(
        energyKcal: 37,
        fat: 12,
        carbs: 58,
        protein: 6.5,
      );
      expect(values.energyMatchesMacros, isFalse);
    });

    test('does not judge very low energy foods', () {
      const values = NutritionLabelValues(
        energyKcal: 1,
        fat: 0,
        carbs: 0.5,
        protein: 0,
      );
      expect(values.energyGap, isNull);
      expect(values.energyMatchesMacros, isTrue);
    });
  });
}
