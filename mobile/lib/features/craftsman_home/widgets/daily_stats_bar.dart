import 'package:flutter/material.dart';
import '../craftsman_home_state.dart';

class DailyStatsBar extends StatelessWidget {
  const DailyStatsBar({super.key, required this.stats});

  final CraftsmanHomeStats? stats;

  String get _responseLabel {
    final seconds = stats?.avgResponseSeconds;
    if (seconds == null) return '—';
    final minutes = (seconds / 60).round();
    return minutes < 1 ? '<1 min' : '$minutes min';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'Jobs aujourd\'hui',
            value: '${stats?.jobsDoneToday ?? 0}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            label: 'Missions assignées',
            value: '${stats?.jobsAssignedToday ?? 0}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: _StatTile(label: 'Réponse', value: _responseLabel)),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
