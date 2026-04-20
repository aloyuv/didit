import 'package:flutter/material.dart';

// Seed color — change this to re-theme the whole app.
const Color kSeedColor = Colors.deepPurple;

ThemeData buildAppTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: kSeedColor),
    useMaterial3: true,
    splashFactory: NoSplash.splashFactory,
    highlightColor: kSeedColor.withValues(alpha: 0.1),
  );
}

// Card gradient helpers.
// t=0 → unlogged (subtle tint), t=1 → logged (full purple).
Color cardGradientTop(ColorScheme cs, double t) =>
    Color.lerp(cs.surface, cs.primaryContainer, t)!;

Color cardGradientBottom(ColorScheme cs, double t) => Color.lerp(
      Color.lerp(cs.surface, cs.primaryContainer, 0.45)!,
      Color.lerp(cs.primaryContainer, cs.primary, 0.4)!,
      t,
    )!;
