import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../craftsman_home_state.dart';

// Compact chip row for today's numbers — a horizontally scrollable strip
// rather than fixed Expanded columns, so it degrades gracefully on small
// phones and scales up cleanly on tablets instead of ever cramping text.
class StatsChipRow extends StatelessWidget {
  const StatsChipRow({super.key, required this.stats});

  final CraftsmanHomeStats? stats;

  String _responseLabel(AppLocalizations l10n) {
    final seconds = stats?.avgResponseSeconds;
    if (seconds == null) return '—';
    final minutes = (seconds / 60).round();
    return minutes < 1
        ? l10n.lessThanOneMinuteLabel
        : l10n.minutesShortLabel(minutes);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final chips = [
      _StatChip(
        icon: Icons.task_alt_rounded,
        label: l10n.statsCompletedLabel,
        value: '${stats?.jobsDoneToday ?? 0}',
      ),
      _StatChip(
        icon: Icons.assignment_turned_in_outlined,
        label: l10n.statsAssignedLabel,
        value: '${stats?.jobsAssignedToday ?? 0}',
      ),
      _StatChip(
        icon: Icons.timer_outlined,
        label: l10n.statsResponseLabel,
        value: _responseLabel(l10n),
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final chip in chips) ...[chip, const SizedBox(width: 10)],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
