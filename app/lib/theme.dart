import 'package:flutter/material.dart';

// Logo green. Material derives the rest of the app palette from this seed.
const Color kSeedColor = Color(0xFF6CCA65);

ThemeData buildAppTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: kSeedColor),
    useMaterial3: true,
    splashFactory: NoSplash.splashFactory,
    highlightColor: kSeedColor.withValues(alpha: 0.1),
  );
}

// Card gradient helpers.
// t=0 is unlogged (neutral grey), t=1 is logged (light brand green).
Color cardGradientTop(ColorScheme cs, double t) => Color.lerp(
      Color.lerp(cs.surface, cs.surfaceContainerHighest, 0.12)!,
      Color.lerp(cs.surface, cs.primaryContainer, 0.9)!,
      t,
    )!;

Color cardGradientBottom(ColorScheme cs, double t) => Color.lerp(
      Color.lerp(cs.surface, cs.surfaceContainerHighest, 0.5)!,
      Color.lerp(cs.primaryContainer, kSeedColor, 0.18)!,
      t,
    )!;
