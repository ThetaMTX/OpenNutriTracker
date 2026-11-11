import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:opennutritracker/core/utils/nutrition_label_parser.dart';

/// Reads a nutrition table from a photo, on the device.
///
/// Uses ML Kit's Latin text recogniser, which runs offline and is free;
/// the photo never leaves the phone. The recognised lines, with their
/// boxes, go to [NutritionLabelParser].
class NutritionLabelReader {
  Future<NutritionLabelValues> readFromImage(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognized = await recognizer.processImage(
        InputImage.fromFilePath(imagePath),
      );
      final lines = <LabelTextLine>[
        for (final block in recognized.blocks)
          for (final line in block.lines)
            LabelTextLine(
              line.text,
              left: line.boundingBox.left,
              top: line.boundingBox.top,
              right: line.boundingBox.right,
              bottom: line.boundingBox.bottom,
            ),
      ];
      return NutritionLabelParser.parse(lines);
    } finally {
      await recognizer.close();
    }
  }
}
