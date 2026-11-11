import 'dart:math' as math;

/// One line of text recognised on a photo of a food label.
///
/// The box is optional. With it, a value printed on the same table row as
/// its name is found even when the text recogniser reads the name column
/// and the value columns as separate lines.
class LabelTextLine {
  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  const LabelTextLine(
    this.text, {
    this.left = 0,
    this.top = 0,
    this.right = 0,
    this.bottom = 0,
  });

  bool get hasBox => bottom > top;

  double get centerY => (top + bottom) / 2;

  double get height => bottom - top;
}

/// The rows of a nutrition declaration the parser looks for.
enum LabelNutrient {
  energy,
  fat,
  saturatedFat,
  carbs,
  sugars,
  fiber,
  protein,
  salt,
}

/// Values read from a nutrition table, per 100 g or 100 ml.
///
/// Every value is null when the row was not found. Energy is in kcal; the
/// rest are in grams.
class NutritionLabelValues {
  final double? energyKcal;
  final double? fat;
  final double? saturatedFat;
  final double? carbs;
  final double? sugars;
  final double? fiber;
  final double? protein;
  final double? salt;

  const NutritionLabelValues({
    this.energyKcal,
    this.fat,
    this.saturatedFat,
    this.carbs,
    this.sugars,
    this.fiber,
    this.protein,
    this.salt,
  });

  /// How many rows were read.
  int get foundCount => [
    energyKcal,
    fat,
    saturatedFat,
    carbs,
    sugars,
    fiber,
    protein,
    salt,
  ].where((value) => value != null).length;

  bool get isEmpty => foundCount == 0;

  /// Sodium in mg for the label's salt (EU labels declare salt, which is
  /// sodium × 2.5).
  double? get sodiumMg => salt == null ? null : salt! * 400;

  /// Relative gap between the declared energy and the energy worked out
  /// from fat, carbs, protein and fibre (9/4/4/2 kcal per gram, the EU
  /// factors). Null when a value is missing or the food is too low in
  /// energy to judge.
  double? get energyGap {
    final kcal = energyKcal;
    final f = fat;
    final c = carbs;
    final p = protein;
    if (kcal == null || f == null || c == null || p == null) return null;
    final computed = 9 * f + 4 * c + 4 * p + 2 * (fiber ?? 0);
    final larger = math.max(kcal, computed);
    if (larger < 20) return null;
    return (kcal - computed).abs() / larger;
  }

  /// False when the energy and the macros disagree by more than a quarter,
  /// which usually means a digit or a decimal comma was misread.
  bool get energyMatchesMacros => (energyGap ?? 0) <= 0.25;
}

/// Reads the nutrition table of a food label from recognised text.
///
/// Built for EU labels (Regulation (EU) No 1169/2011): the per 100 g or
/// 100 ml column comes first and energy is given in kJ and kcal. Row names
/// are understood in English, Polish and German, with or without
/// diacritics, and decimal commas are accepted.
class NutritionLabelParser {
  static const double _kjPerKcal = 4.184;
  static const double _maxKcal = 950;
  static const double _maxGrams = 100;

  // Order matters: a sub-row is checked before the row whose word it
  // contains ("kwasy tłuszczowe nasycone" also contains "tłuszcz").
  static final List<(LabelNutrient, RegExp)> _rowNames = [
    (LabelNutrient.saturatedFat, RegExp(r'nasycon|saturat|gesattigt')),
    (LabelNutrient.sugars, RegExp(r'cukr|sugar|zucker')),
    (LabelNutrient.fiber, RegExp(r'blonnik|fibre|fiber|ballaststoff')),
    (LabelNutrient.salt, RegExp(r'\bsol\b|\bsalt\b|\bsalz\b')),
    (LabelNutrient.protein, RegExp(r'bialk|protein|eiweis')),
    (LabelNutrient.carbs, RegExp(r'weglowodan|carbohydrate|kohlenhydrat')),
    (LabelNutrient.fat, RegExp(r'tluszcz|\bfat\b|\bfats\b|\bfett\b')),
    (LabelNutrient.energy, RegExp(r'energ|brennwert')),
  ];

  static final RegExp _number = RegExp(r'<?\s*(\d+(?:[.,]\d+)?)');
  static final RegExp _kcal = RegExp(r'(\d+(?:[.,]\d+)?)\s*kcal');
  static final RegExp _kj = RegExp(r'(\d+(?:[.,]\d+)?)\s*kj');
  static final RegExp _kjKcalPair = RegExp(
    r'kj\s*/\s*kcal\D*?(\d+(?:[.,]\d+)?)\s*/\s*(\d+(?:[.,]\d+)?)',
  );
  static final RegExp _valueOnly = RegExp(
    r'^\s*<?\s*\d+(?:[.,]\d+)?\s*(?:g|mg)?\b',
  );
  static final RegExp _per100 = RegExp(r'100\s*(?:g|ml)');

  static const Map<String, String> _foldMap = {
    'ą': 'a',
    'ć': 'c',
    'ę': 'e',
    'ł': 'l',
    'ń': 'n',
    'ó': 'o',
    'ś': 's',
    'ź': 'z',
    'ż': 'z',
    'ä': 'a',
    'ö': 'o',
    'ü': 'u',
    'é': 'e',
    'è': 'e',
    'à': 'a',
    'ß': 's',
  };

  /// Lower case without diacritics, so "Białko", "Bialko" and "BIAŁKO"
  /// all read the same.
  static String fold(String text) {
    final buffer = StringBuffer();
    for (final char in text.toLowerCase().split('')) {
      buffer.write(_foldMap[char] ?? char);
    }
    return buffer.toString();
  }

  /// Convenience for text without position data, one label line per line.
  static NutritionLabelValues parseText(String text) => parse([
    for (final line in text.split('\n'))
      if (line.trim().isNotEmpty) LabelTextLine(line),
  ]);

  static NutritionLabelValues parse(List<LabelTextLine> lines) {
    final all = [for (final line in lines) _Line(line, fold(line.text))];
    final found = <LabelNutrient, double>{};
    final used = <_Line>{};
    final pending = <LabelNutrient>[];

    final named = <(LabelNutrient, int, _Line)>[];
    for (final line in all) {
      final rowName = _rowName(line.folded);
      if (rowName != null) named.add((rowName.$1, rowName.$2, line));
    }

    for (final (nutrient, nameEnd, line) in named) {
      if (found.containsKey(nutrient)) continue;
      final rest = line.folded.substring(nameEnd);
      double? value;
      if (nutrient == LabelNutrient.energy) {
        value = _energyForRow(line, rest, all, used);
      } else {
        value = _firstNumber(rest);
        if (value == null) {
          for (final partner in _rowPartners(all, line)) {
            if (_rowName(partner.folded) != null) continue;
            final partnerValue = _firstNumber(partner.folded);
            if (partnerValue != null) {
              value = partnerValue;
              used.add(partner);
              break;
            }
          }
        }
      }
      if (value != null && _plausible(nutrient, value)) {
        found[nutrient] = value;
      } else if (!pending.contains(nutrient)) {
        pending.add(nutrient);
      }
    }

    // A label with no energy row name: take the first energy in reading
    // order, kcal before kJ.
    if (!found.containsKey(LabelNutrient.energy)) {
      for (final useKj in [false, true]) {
        for (final line in all) {
          final energy = _energy(line.folded, useKj: useKj);
          if (energy != null && _plausible(LabelNutrient.energy, energy)) {
            found[LabelNutrient.energy] = energy;
            used.add(line);
            break;
          }
        }
        if (found.containsKey(LabelNutrient.energy)) break;
      }
    }

    // The recogniser often reads the name column and the value column as
    // separate runs of lines. Pair them up in order when the counts allow.
    final missing = [
      for (final nutrient in pending)
        if (!found.containsKey(nutrient) && nutrient != LabelNutrient.energy)
          nutrient,
    ];
    if (missing.isNotEmpty) {
      final values = <double>[];
      for (final line in all) {
        if (used.contains(line) || _rowName(line.folded) != null) continue;
        final text = line.folded;
        if (!_valueOnly.hasMatch(text) ||
            text.contains('kj') ||
            text.contains('kcal') ||
            _per100.hasMatch(text)) {
          continue;
        }
        final value = _firstNumber(text);
        if (value != null) values.add(value);
      }
      if (values.length >= missing.length) {
        for (var i = 0; i < missing.length; i++) {
          if (_plausible(missing[i], values[i])) {
            found[missing[i]] = values[i];
          }
        }
      }
    }

    return NutritionLabelValues(
      energyKcal: found[LabelNutrient.energy],
      fat: found[LabelNutrient.fat],
      saturatedFat: found[LabelNutrient.saturatedFat],
      carbs: found[LabelNutrient.carbs],
      sugars: found[LabelNutrient.sugars],
      fiber: found[LabelNutrient.fiber],
      protein: found[LabelNutrient.protein],
      salt: found[LabelNutrient.salt],
    );
  }

  static (LabelNutrient, int)? _rowName(String folded) {
    for (final (nutrient, pattern) in _rowNames) {
      final match = pattern.firstMatch(folded);
      if (match != null) return (nutrient, match.end);
    }
    return null;
  }

  /// Energy for the energy row: its own text first, then the rest of its
  /// table row, then the first kcal anywhere; kJ only when no kcal exists.
  static double? _energyForRow(
    _Line row,
    String rest,
    List<_Line> all,
    Set<_Line> used,
  ) {
    for (final useKj in [false, true]) {
      final own = _energy(rest, useKj: useKj);
      if (own != null) return own;
      for (final partner in _rowPartners(all, row)) {
        final value = _energy(partner.folded, useKj: useKj);
        if (value != null) {
          used.add(partner);
          return value;
        }
      }
      if (!useKj) {
        for (final line in all) {
          final value = _energy(line.folded, useKj: false);
          if (value != null) {
            used.add(line);
            return value;
          }
        }
      }
    }
    return null;
  }

  static double? _energy(String folded, {required bool useKj}) {
    if (useKj) {
      final kj = _kj.firstMatch(folded);
      if (kj == null) return null;
      final kcal = _toDouble(kj.group(1)!) / _kjPerKcal;
      return (kcal * 10).round() / 10;
    }
    final pair = _kjKcalPair.firstMatch(folded);
    if (pair != null) return _toDouble(pair.group(2)!);
    final kcal = _kcal.firstMatch(folded);
    if (kcal != null) return _toDouble(kcal.group(1)!);
    return null;
  }

  /// Lines on the same table row as [row] and to its right, nearest first.
  /// The nearest value column is the per 100 g one on EU labels.
  static List<_Line> _rowPartners(List<_Line> all, _Line row) {
    if (!row.source.hasBox) return const [];
    final tolerance = row.source.height * 0.6;
    final partners = [
      for (final other in all)
        if (!identical(other, row) &&
            other.source.hasBox &&
            (other.source.centerY - row.source.centerY).abs() < tolerance &&
            other.source.left >= row.source.left)
          other,
    ];
    partners.sort((a, b) => a.source.left.compareTo(b.source.left));
    return partners;
  }

  static double? _firstNumber(String text) {
    final match = _number.firstMatch(text);
    if (match == null) return null;
    return _toDouble(match.group(1)!);
  }

  static double _toDouble(String number) =>
      double.parse(number.replaceAll(',', '.'));

  static bool _plausible(LabelNutrient nutrient, double value) {
    if (value < 0) return false;
    return nutrient == LabelNutrient.energy
        ? value <= _maxKcal
        : value <= _maxGrams;
  }
}

class _Line {
  final LabelTextLine source;
  final String folded;

  _Line(this.source, this.folded);
}
