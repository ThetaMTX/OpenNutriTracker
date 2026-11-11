import 'package:opennutritracker/core/utils/nutrition_label_parser.dart';

/// A recogniser's food label made fit to show and search for, or null for
/// labels that name no food (the classifier's "background" class, blanks).
String? cleanFoodLabel(String raw) {
  var label = raw.trim();
  if (label.length >= 2 && label.startsWith('"') && label.endsWith('"')) {
    label = label.substring(1, label.length - 1).trim();
  }
  if (label.isEmpty) return null;
  if (label.toLowerCase().contains('background')) return null;
  return label;
}

/// Reads a label map CSV ("id,name" per line, an optional header) into
/// index → name. Lines that do not start with a number are skipped.
Map<int, String> parseFoodLabelMap(String csv) {
  final labels = <int, String>{};
  for (final line in csv.split('\n')) {
    final comma = line.indexOf(',');
    if (comma <= 0) continue;
    final index = int.tryParse(line.substring(0, comma).trim());
    if (index == null) continue;
    final name = cleanFoodLabel(line.substring(comma + 1));
    if (name != null) labels[index] = name;
  }
  return labels;
}

// Matched against NutritionLabelParser.fold. "℮" is the EU estimated-sign
// printed next to a pack's net quantity.
final RegExp _netWeightKey = RegExp(
  r'netto|net\s*(?:weight|wt|wght|content|quantity)|nettogewicht|'
  r'nettofullmenge|poids net|℮',
);
final RegExp _quantity = RegExp(r'(\d+(?:[.,]\d+)?)\s*(kg|g|ml|l)\b');

/// The pack's net weight in grams (or millilitres) — "Masa netto: 410 g",
/// "Net weight 0,5 kg", "410 g ℮" — or null when no line names one. Only
/// lines with a net-weight word count, so the "100 g" of a nutrition table
/// is never taken for it. The amount may also be on the line after the word.
double? parseNetWeightGrams(List<LabelTextLine> lines) {
  for (var i = 0; i < lines.length; i++) {
    final folded = NutritionLabelParser.fold(lines[i].text);
    if (!_netWeightKey.hasMatch(folded)) continue;
    final grams =
        _quantityInGrams(folded) ??
        (i + 1 < lines.length
            ? _quantityInGrams(NutritionLabelParser.fold(lines[i + 1].text))
            : null);
    if (grams != null) return grams;
  }
  return null;
}

double? _quantityInGrams(String folded) {
  final match = _quantity.firstMatch(folded);
  if (match == null) return null;
  final number = double.parse(match.group(1)!.replaceAll(',', '.'));
  final unit = match.group(2)!;
  final grams = (unit == 'kg' || unit == 'l') ? number * 1000 : number;
  if (grams <= 0 || grams > 10000) return null;
  return grams;
}

/// Turns the text read from the front of a pack into a product search.
///
/// The brand and the product name are the largest text on a pack, so the
/// biggest lines win. Weights, nutrition rows, dates and web addresses are
/// skipped, as are long sentences (ingredients, claims).
class PackTextQuery {
  static const int _maxWords = 6;
  static const int _maxLength = 60;
  static const int _minLetters = 3;
  static const double _sizeShare = 0.6;

  static final RegExp _letter = RegExp(
    r'[a-zA-ZàáâäãåçèéêëìíîïñòóôöõùúûüýÿąćęłńóśźżÀÁÂÄÃÅÇÈÉÊËÌÍÎÏÑÒÓÔÖÕÙÚÛÜÝĄĆĘŁŃÓŚŹŻß]',
  );
  static final RegExp _notAllowed = RegExp(
    r'''[^a-zA-Z0-9àáâäãåçèéêëìíîïñòóôöõùúûüýÿąćęłńóśźżÀÁÂÄÃÅÇÈÉÊËÌÍÎÏÑÒÓÔÖÕÙÚÛÜÝĄĆĘŁŃÓŚŹŻß &,.%'-]''',
  );
  static final RegExp _spaces = RegExp(r'\s+');

  // Matched against NutritionLabelParser.fold (lower case, no diacritics).
  static final RegExp _noise = RegExp(
    r'kcal|\bkj\b|wartosc|energ|bialk|tluszcz|weglowodan|skladnik|'
    r'ingredient|nutrition|zutaten|best before|najlepiej|spozyc|'
    r'www\.|https?:|@|\be-?mail\b|'
    r'^\s*\d+([.,]\d+)?\s*(g|kg|mg|ml|l|szt|pcs)\b|'
    r'\b\d+([.,]\d+)?\s*(g|kg|ml|l)\s*$',
  );

  /// The search for [lines], or null when nothing on them looks like a
  /// product name.
  static String? fromLines(List<LabelTextLine> lines) {
    final candidates = <(LabelTextLine, String)>[];
    for (final line in lines) {
      final folded = NutritionLabelParser.fold(line.text);
      if (_noise.hasMatch(folded)) continue;
      final cleaned = line.text
          .replaceAll(_notAllowed, ' ')
          .replaceAll(_spaces, ' ')
          .trim();
      if (_letter.allMatches(cleaned).length < _minLetters) continue;
      if (cleaned.split(' ').length > _maxWords) continue;
      candidates.add((line, cleaned));
    }
    if (candidates.isEmpty) return null;

    List<(LabelTextLine, String)> chosen;
    if (candidates.every((c) => c.$1.hasBox)) {
      final bySize = [...candidates]
        ..sort((a, b) => b.$1.height.compareTo(a.$1.height));
      final largest = bySize.first.$1.height;
      chosen = bySize
          .where((c) => c.$1.height >= largest * _sizeShare)
          .take(2)
          .toList()
        ..sort((a, b) => a.$1.top.compareTo(b.$1.top));
    } else {
      chosen = candidates.take(2).toList();
    }

    var query = chosen.map((c) => c.$2).join(' ');
    if (query.length > _maxLength) {
      final cut = query.lastIndexOf(' ', _maxLength);
      query = query.substring(0, cut > 0 ? cut : _maxLength);
    }
    return query;
  }
}
