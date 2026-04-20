import 'package:didit/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('placeholder', () {
    expect(1 + 1, 2);
  });

  test('theme uses the logo color as its seed', () {
    expect(kSeedColor, const Color(0xFF6CCA65));
  });

  test('unlogged cards use a neutral grey gradient', () {
    final colorScheme = ColorScheme.fromSeed(seedColor: kSeedColor);

    expect(
      cardGradientBottom(colorScheme, 0),
      Color.lerp(colorScheme.surface, colorScheme.surfaceContainerHighest, 0.5),
    );
  });

  test('logged cards use a light logo green gradient', () {
    final colorScheme = ColorScheme.fromSeed(seedColor: kSeedColor);

    expect(
      cardGradientTop(colorScheme, 1),
      Color.lerp(colorScheme.surface, colorScheme.primaryContainer, 0.9),
    );
    expect(
      cardGradientBottom(colorScheme, 1),
      Color.lerp(colorScheme.primaryContainer, kSeedColor, 0.18),
    );
  });
}
