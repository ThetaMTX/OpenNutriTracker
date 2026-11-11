import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/utils/food_recognition_text.dart';
import 'package:opennutritracker/core/utils/nutrition_label_parser.dart';

void main() {
  group('cleanFoodLabel', () {
    test('keeps a dish name', () {
      expect(cleanFoodLabel(' Pierogi '), 'Pierogi');
    });

    test('drops the background class and blanks', () {
      expect(cleanFoodLabel('__background__'), isNull);
      expect(cleanFoodLabel('Background'), isNull);
      expect(cleanFoodLabel('  '), isNull);
    });

    test('strips CSV quotes', () {
      expect(cleanFoodLabel('"Kotlet schabowy"'), 'Kotlet schabowy');
    });
  });

  group('parseFoodLabelMap', () {
    test('reads id,name lines and skips the header', () {
      final labels = parseFoodLabelMap(
        'id,name\n0,__background__\n1,Chaudin\n2,"Kotlet schabowy"\n',
      );
      expect(labels, {1: 'Chaudin', 2: 'Kotlet schabowy'});
    });
  });

  group('PackTextQuery', () {
    test('takes the largest lines and skips size and dates', () {
      const lines = [
        LabelTextLine('ŁACIATE', left: 10, top: 10, right: 300, bottom: 70),
        LabelTextLine('Mleko UHT 3,2%', left: 10, top: 90, right: 300, bottom: 130),
        LabelTextLine('1 l', left: 250, top: 300, right: 300, bottom: 340),
        LabelTextLine('Najlepiej spożyć przed', left: 10, top: 400, right: 200, bottom: 412),
      ];
      expect(PackTextQuery.fromLines(lines), 'ŁACIATE Mleko UHT 3,2%');
    });

    test('ignores small print when one line is much larger', () {
      const lines = [
        LabelTextLine('Pilos', left: 0, top: 0, right: 200, bottom: 80),
        LabelTextLine('wyprodukowano dla Lidl', left: 0, top: 100, right: 200, bottom: 112),
      ];
      expect(PackTextQuery.fromLines(lines), 'Pilos');
    });

    test('skips nutrition rows, weights and long sentences', () {
      final query = PackTextQuery.fromLines(const [
        LabelTextLine('Wartość energetyczna 1580 kJ'),
        LabelTextLine('500 g'),
        LabelTextLine('Składniki: mąka pszenna, woda, sól, drożdże, olej'),
        LabelTextLine('Chleb żytni'),
      ]);
      expect(query, 'Chleb żytni');
    });

    test('returns null when nothing looks like a name', () {
      expect(
        PackTextQuery.fromLines(const [
          LabelTextLine('500 g'),
          LabelTextLine('12'),
          LabelTextLine('www.example.pl'),
        ]),
        isNull,
      );
    });
  });
}
