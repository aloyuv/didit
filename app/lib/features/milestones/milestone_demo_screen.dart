import 'package:flutter/material.dart';
import 'milestone_explosion.dart';

class MilestoneDemoScreen extends StatefulWidget {
  const MilestoneDemoScreen({super.key});

  @override
  State<MilestoneDemoScreen> createState() => _MilestoneDemoScreenState();
}

class _MilestoneDemoScreenState extends State<MilestoneDemoScreen> {
  int _key = 0;
  bool _playing = true;

  void _replay() => setState(() {
        _key++;
        _playing = true;
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Center(
            child: _playing
                ? MilestoneExplosionWithShake(
                    key: ValueKey(_key),
                    value: '400',
                    onComplete: () => setState(() => _playing = false),
                  )
                : const SizedBox.shrink(),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 48),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E1E1E),
                foregroundColor: const Color(0xFFFFB74D),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
              onPressed: _replay,
              icon: const Icon(Icons.replay),
              label: const Text('Replay', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
