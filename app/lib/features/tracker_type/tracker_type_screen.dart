import 'dart:convert';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../db/database.dart';
import '../../router.dart';

class TrackerTypeScreen extends ConsumerWidget {
  const TrackerTypeScreen({super.key});

  Future<void> _createHabitTemplate(
    BuildContext context,
    WidgetRef ref, {
    required String name,
    required String period,
    List<String>? valueOptions,
  }) async {
    final db = ref.read(dbProvider);
    final now = DateTime.now();
    final maxRow = await db
        .customSelect('SELECT COALESCE(MAX(sort_order), 0) AS m FROM trackers')
        .getSingle();
    final sortOrder = maxRow.read<int>('m') + 1;
    final valueOptionsJson = (valueOptions == null || valueOptions.isEmpty)
        ? null
        : jsonEncode(valueOptions);
    await db.into(db.trackers).insert(TrackersCompanion.insert(
          name: name,
          type: 'habit',
          sortOrder: sortOrder,
          habitPeriod: Value(period),
          habitValueOptions: Value(valueOptionsJson),
          createdAt: now,
          modifiedAt: now,
        ));
    if (context.mounted) context.go('/');
  }

  Future<void> _createGoalTemplate(
    BuildContext context,
    WidgetRef ref, {
    required String name,
    String? unit,
    double? targetAmount,
    DateTime? targetDate,
    double? stepSize,
  }) async {
    final db = ref.read(dbProvider);
    final now = DateTime.now();
    final maxRow = await db
        .customSelect('SELECT COALESCE(MAX(sort_order), 0) AS m FROM trackers')
        .getSingle();
    final sortOrder = maxRow.read<int>('m') + 1;
    await db.into(db.trackers).insert(TrackersCompanion.insert(
          name: name,
          type: 'goal',
          sortOrder: sortOrder,
          goalUnit: Value(unit),
          goalTargetAmount: Value(targetAmount),
          goalTargetDate: Value(targetDate),
          goalStepSize: Value(stepSize),
          createdAt: now,
          modifiedAt: now,
        ));
    if (context.mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final endOfYear = DateTime(DateTime.now().year, 12, 31);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/')),
        title: const Text('New Tracker'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Templates', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _TemplateCard(
            title: '🏃Daily cardio',
            description: 'Run, cycle, or swim options',
            icon: Icons.directions_run,
            onTap: () => _createHabitTemplate(context, ref,
                name: 'Daily cardio',
                period: 'daily',
                valueOptions: ['Run', 'Other']),
          ),
          const SizedBox(height: 8),
          _TemplateCard(
            title: '❤️Track mood daily',
            description: 'Daily habit with options 1 (sad) – 5 (happy)',
            icon: Icons.mood,
            onTap: () => _createHabitTemplate(context, ref,
                name: 'Mood',
                period: 'daily',
                valueOptions: ['1', '2', '3', '4', '5']),
          ),
          const SizedBox(height: 8),
          _TemplateCard(
            title: '🏊Swim 50 km this year',
            description: 'Goal — 50 km by Dec 31',
            icon: Icons.pool,
            onTap: () => _createGoalTemplate(context, ref,
                name: 'Swim',
                unit: 'km',
                targetAmount: 50,
                targetDate: endOfYear),
          ),
          const SizedBox(height: 24),
          Text('Custom', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _TypeCard(
            title: 'Habit',
            description: 'Do repeatedly on a schedule. Track streaks.',
            icon: Icons.repeat,
            onTap: () => context.navigate('/habit-edit'),
          ),
          const SizedBox(height: 8),
          _TypeCard(
            title: 'Goal',
            description: 'Accumulate toward a target. Track your total.',
            icon: Icons.flag,
            onTap: () => context.navigate('/goal-edit'),
          ),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    Text(description,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.add, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _TypeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Icon(icon, size: 40),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(description,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
