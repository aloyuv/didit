// Design docs:
// - docs/design/goals.md
// - docs/design/visual-effects.md

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Logo green. Material derives the rest of the app palette from this seed.
const Color kSeedColor = Color(0xFF6CCA65);
const String kEmojiFontFamily = 'NotoColorEmoji';

ThemeData buildAppTheme() {
  final cs = ColorScheme.fromSeed(seedColor: kSeedColor);
  return ThemeData(
    colorScheme: cs,
    textTheme: GoogleFonts.interTextTheme(),
    fontFamilyFallback: const [kEmojiFontFamily],
    useMaterial3: true,
    splashFactory: NoSplash.splashFactory,
    highlightColor: kSeedColor.withValues(alpha: 0.1),
    scaffoldBackgroundColor: cs.surfaceContainerHigh,
  );
}

// Card gradient helpers.
// t=0 is unlogged (neutral grey), t=1 is logged (light brand green).
Color cardGradientTop(ColorScheme cs, double t) => Color.lerp(
      cs.surface,
      Color.lerp(cs.surface, cs.primaryContainer, 0.9)!,
      t,
    )!;

Color cardGradientBottom(ColorScheme cs, double t) => Color.lerp(
      Color.lerp(cs.surface, cs.surfaceContainerHighest, 0.2)!,
      Color.lerp(cs.primaryContainer, kSeedColor, 0.18)!,
      t,
    )!;
