import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The palette behind the calm friendly-flat redesign.
///
/// A warm-neutral canvas with a gentle surface ladder carries the app; depth
/// comes from hairline borders and soft shadows, not colour. A single vivid
/// [accent] (a fresh leaf-green by default, nodding to the nutrition brand) is
/// the only loud colour and is user-overridable via the accent picker / Material
/// You. The macro trio (carbs amber, fat coral, protein teal) stays fixed so the
/// dashboard always reads the same, whatever accent is chosen.
class AppPalette {
  final Brightness brightness;
  final Color canvas; // scaffold background
  final Color surface; // cards / sheets
  final Color surfaceMuted; // secondary fills, track backgrounds
  final Color border; // hairline outline
  final Color shadow; // soft shadow colour
  final Color accent; // the one vivid colour (overridable)
  final Color onAccent;
  final Color carbsColor;
  final Color fatColor;
  final Color proteinColor;
  final Color textStrong;
  final Color textMuted;

  const AppPalette({
    required this.brightness,
    required this.canvas,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.shadow,
    required this.accent,
    required this.onAccent,
    required this.carbsColor,
    required this.fatColor,
    required this.proteinColor,
    required this.textStrong,
    required this.textMuted,
  });

  Color get carbs => carbsColor;
  Color get fat => fatColor;
  Color get protein => proteinColor;

  // "Midnight blue" look of the personal fork: cool blue-grey neutrals and a
  // blue default accent in place of upstream's warm canvas and leaf green.
  // Every text/background pair below still clears WCAG AA (4.5:1).
  static const light = AppPalette(
    brightness: Brightness.light,
    canvas: Color(0xFFF2F5FA),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFE5EBF3),
    border: Color(0xFFD9E1EC),
    shadow: Color(0x14101828),
    // White on it ~5.8:1; as text on the canvas ~5.3:1.
    accent: Color(0xFF1F5FD1),
    onAccent: Color(0xFFFFFFFF),
    carbsColor: Color(0xFFB87410),
    fatColor: Color(0xFFD05536),
    proteinColor: Color(0xFF1F8E80),
    textStrong: Color(0xFF111827),
    // ~5.2:1 even on surfaceMuted.
    textMuted: Color(0xFF566175),
  );

  static const dark = AppPalette(
    brightness: Brightness.dark,
    canvas: Color(0xFF0A0E16),
    surface: Color(0xFF121926),
    surfaceMuted: Color(0xFF1A2333),
    border: Color(0xFF243047),
    shadow: Color(0x66000000),
    // Electric blue; the deep navy on it reads at ~6.5:1.
    accent: Color(0xFF4C9EFF),
    onAccent: Color(0xFF04172E),
    carbsColor: Color(0xFFF2B45A),
    fatColor: Color(0xFFFF937B),
    proteinColor: Color(0xFF49C9B8),
    textStrong: Color(0xFFE6EDF7),
    // ~6.2:1 on the surface.
    textMuted: Color(0xFF8E9BB0),
  );

  /// Returns a copy with the accent swapped for [newAccent] (accent picker or a
  /// harmonized Material You primary). The neutral canvas, surfaces and macro
  /// colours are untouched, so only the one vivid role follows the user.
  /// The text colour on the accent comes from [readableOn].
  AppPalette withAccent(Color newAccent) {
    final onNew = readableOn(newAccent);
    return AppPalette(
      brightness: brightness,
      canvas: canvas,
      surface: surface,
      surfaceMuted: surfaceMuted,
      border: border,
      shadow: shadow,
      accent: newAccent,
      onAccent: onNew,
      carbsColor: carbsColor,
      fatColor: fatColor,
      proteinColor: proteinColor,
      textStrong: textStrong,
      textMuted: textMuted,
    );
  }

  /// The text or icon colour for content drawn on [background]: whichever of
  /// white or the warm dark ink gives the higher WCAG contrast ratio. When
  /// neither reaches AA (4.5:1), as on red, teal, blue and pink, pure black
  /// replaces the ink: white or black always reaches at least 4.58:1.
  static Color readableOn(Color background) {
    const darkInk = Color(0xFF20201C);
    const black = Color(0xFF000000);
    final white = _contrastRatio(Colors.white, background);
    final ink = _contrastRatio(darkInk, background);
    if (math.max(white, ink) >= 4.5) {
      return white >= ink ? Colors.white : darkInk;
    }
    return white >= _contrastRatio(black, background) ? Colors.white : black;
  }

  /// WCAG 2.x contrast ratio between two opaque colours.
  static double _contrastRatio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    return la > lb ? (la + 0.05) / (lb + 0.05) : (lb + 0.05) / (la + 0.05);
  }

  ColorScheme get colorScheme => ColorScheme(
        brightness: brightness,
        primary: accent,
        onPrimary: onAccent,
        primaryContainer: accent,
        onPrimaryContainer: onAccent,
        secondary: proteinColor,
        onSecondary: onAccent,
        secondaryContainer: surfaceMuted,
        onSecondaryContainer: textStrong,
        tertiary: carbsColor,
        onTertiary: onAccent,
        tertiaryContainer: surfaceMuted,
        onTertiaryContainer: textStrong,
        error: brightness == Brightness.light ? const Color(0xFFC4453A) : const Color(0xFFFFB4AB),
        onError: brightness == Brightness.light ? Colors.white : const Color(0xFF690005),
        surface: surface,
        onSurface: textStrong,
        surfaceContainerLowest: canvas,
        surfaceContainerLow: canvas,
        surfaceContainer: surfaceMuted,
        surfaceContainerHigh: surfaceMuted,
        surfaceContainerHighest: surfaceMuted,
        onSurfaceVariant: textMuted,
        outline: border,
        outlineVariant: border,
        surfaceTint: Colors.transparent,
        shadow: shadow,
      );
}
