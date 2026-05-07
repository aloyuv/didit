import 'package:flutter/material.dart';
import '../../theme.dart';

class EmojiFormField extends StatelessWidget {
  final TextEditingController controller;

  const EmojiFormField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      style: kEmojiStyle,
      decoration: const InputDecoration(
        labelText: 'Emoji (optional)',
        border: OutlineInputBorder(),
      ),
      maxLines: 1,
    );
  }
}
