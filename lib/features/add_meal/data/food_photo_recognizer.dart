import 'dart:io';

import 'package:flutter/services.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/utils/food_recognition_text.dart';
import 'package:opennutritracker/core/utils/nutrition_label_parser.dart';
import 'package:path_provider/path_provider.dart';

/// One guess at what a photo shows, with the model's confidence (0–1).
class FoodGuess {
  final String name;
  final double confidence;

  const FoodGuess(this.name, this.confidence);
}

/// What [FoodPhotoRecognizer] found in one photo.
class FoodRecognition {
  /// Dish or food guesses, most likely first.
  final List<FoodGuess> dishes;

  /// Brand and product name read from a pack, ready to search for.
  final String? packText;

  /// True when this build has no food model, so only pack text was read.
  final bool modelMissing;

  const FoodRecognition({
    this.dishes = const [],
    this.packText,
    this.modelMissing = false,
  });

  bool get isEmpty => dishes.isEmpty && packText == null;
}

/// Guesses what food a photo shows, entirely on the phone.
///
/// Two ML Kit passes over the same photo: Google's AIY "Vision Classifier
/// Food V1" (2,023 dishes and foods, Apache 2.0) through ML Kit's custom
/// image labeling, and the text recogniser for the name printed on a pack.
/// The model file is fetched by the build (see
/// .github/workflows/build-personal-apk.yml) into assets/ml/; without it,
/// only the pack text is read.
class FoodPhotoRecognizer {
  static const modelAsset = 'assets/ml/aiy_food_v1.tflite';
  static const labelMapAsset = 'assets/ml/aiy_food_v1_labelmap.csv';
  static const int _maxGuesses = 5;
  static const double _minConfidence = 0.05;

  final _log = Logger('FoodPhotoRecognizer');
  ImageLabeler? _labeler;
  Map<int, String>? _labelMap;
  bool _modelMissing = false;

  Future<FoodRecognition> recognize(String imagePath) async {
    final image = InputImage.fromFilePath(imagePath);
    final dishes = await _guessDishes(image);
    final packText = await _readPackText(image);
    return FoodRecognition(
      dishes: dishes,
      packText: packText,
      modelMissing: _modelMissing,
    );
  }

  Future<void> close() async {
    await _labeler?.close();
    _labeler = null;
  }

  Future<List<FoodGuess>> _guessDishes(InputImage image) async {
    try {
      final labeler = await _loadLabeler();
      if (labeler == null) return const [];
      final labels = await labeler.processImage(image);
      final names = await _loadLabelMap();
      final guesses = <FoodGuess>[];
      final seen = <String>{};
      for (final label in labels) {
        // The model's metadata carries the names; the CSV is a fallback for
        // a model file without them.
        final fromModel = label.label.trim();
        final raw = fromModel.isNotEmpty && int.tryParse(fromModel) == null
            ? fromModel
            : (names[label.index] ?? '');
        final name = cleanFoodLabel(raw);
        if (name == null || !seen.add(name.toLowerCase())) continue;
        guesses.add(FoodGuess(name, label.confidence));
      }
      guesses.sort((a, b) => b.confidence.compareTo(a.confidence));
      return guesses.take(_maxGuesses).toList();
    } catch (e, st) {
      _log.warning('Food recognition failed', e, st);
      return const [];
    }
  }

  /// ML Kit needs the model as a file, so the bundled asset is copied once
  /// into the app's support folder.
  Future<ImageLabeler?> _loadLabeler() async {
    final existing = _labeler;
    if (existing != null) return existing;
    if (_modelMissing) return null;
    final ByteData data;
    try {
      data = await rootBundle.load(modelAsset);
    } catch (_) {
      _log.warning('No food model in this build ($modelAsset)');
      _modelMissing = true;
      return null;
    }
    final folder = await getApplicationSupportDirectory();
    final file = File('${folder.path}/aiy_food_v1.tflite');
    if (!await file.exists() || await file.length() != data.lengthInBytes) {
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }
    final labeler = ImageLabeler(
      options: LocalLabelerOptions(
        modelPath: file.path,
        confidenceThreshold: _minConfidence,
        maxCount: 10,
      ),
    );
    _labeler = labeler;
    return labeler;
  }

  Future<Map<int, String>> _loadLabelMap() async {
    final existing = _labelMap;
    if (existing != null) return existing;
    Map<int, String> labels;
    try {
      labels = parseFoodLabelMap(await rootBundle.loadString(labelMapAsset));
    } catch (_) {
      labels = const {};
    }
    _labelMap = labels;
    return labels;
  }

  Future<String?> _readPackText(InputImage image) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognized = await recognizer.processImage(image);
      return PackTextQuery.fromLines([
        for (final block in recognized.blocks)
          for (final line in block.lines)
            LabelTextLine(
              line.text,
              left: line.boundingBox.left,
              top: line.boundingBox.top,
              right: line.boundingBox.right,
              bottom: line.boundingBox.bottom,
            ),
      ]);
    } catch (e, st) {
      _log.warning('Reading pack text failed', e, st);
      return null;
    } finally {
      await recognizer.close();
    }
  }
}
