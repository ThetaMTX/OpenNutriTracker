# ML Kit text recognition (nutrition label reader). The Flutter plugin
# references the optional Chinese, Devanagari, Japanese and Korean
# recognisers; only Latin is bundled, so R8 must not fail on the others.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
