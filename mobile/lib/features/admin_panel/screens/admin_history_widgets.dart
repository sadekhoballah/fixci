import 'package:flutter/material.dart';
import '../../../core/models/service_category.dart';
import '../admin_ops_state.dart';

// Small building blocks shared by the two read-only history tabs
// ("Missions effectuées" and "Ops live détaillée").

String formatHistoryDate(DateTime dt) {
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
}

String formatHistoryDay(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.day)}/${two(dt.month)}/${dt.year}';
}

String formatHistoryDuration(Duration d) {
  if (d.inMinutes < 1) return '${d.inSeconds} s';
  if (d.inHours < 1) return '${d.inMinutes} min';
  if (d.inDays < 1) return '${d.inHours} h ${d.inMinutes % 60} min';
  return '${d.inDays} j ${d.inHours % 24} h';
}

String historyCategoryLabel(String? wireValue) {
  if (wireValue == null) return 'Autre';
  for (final c in ServiceCategory.values) {
    if (c.wireValue == wireValue) return c.label;
  }
  return wireValue;
}

// Status filter chips, each carrying its count — doubles as the per-status
// statistics for whatever the other filters currently select.
class HistoryStatusChips extends StatelessWidget {
  const HistoryStatusChips({
    super.key,
    required this.byStatus,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  final List<StatusCount> byStatus;
  final Map<String, String> labels;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final total = byStatus.fold<int>(0, (sum, s) => sum + s.count);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: Text('Tous ($total)'),
          selected: selected == null,
          onSelected: (_) => onSelected(null),
        ),
        for (final s in byStatus)
          ChoiceChip(
            label: Text('${labels[s.status] ?? s.status} (${s.count})'),
            selected: selected == s.status,
            onSelected: (_) =>
                onSelected(selected == s.status ? null : s.status),
          ),
      ],
    );
  }
}

class HistoryDateFilter extends StatelessWidget {
  const HistoryDateFilter({
    super.key,
    required this.date,
    required this.onChanged,
  });

  final DateTime? date;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today_rounded, size: 18),
          label: Text(
            date == null ? 'Toutes les dates' : formatHistoryDay(date!),
          ),
          onPressed: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: date ?? now,
              firstDate: DateTime(2024),
              lastDate: now,
            );
            if (picked != null) onChanged(picked);
          },
        ),
        if (date != null)
          IconButton(
            tooltip: 'Effacer la date',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => onChanged(null),
          ),
      ],
    );
  }
}

class HistoryCard extends StatelessWidget {
  const HistoryCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class HistoryStatusBadge extends StatelessWidget {
  const HistoryStatusBadge({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// One "label: value" line of a card; skipped entirely when value is null.
class HistoryInfoLine extends StatelessWidget {
  const HistoryInfoLine({super.key, required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value == null) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(value!, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class HistoryListFooter extends StatelessWidget {
  const HistoryListFooter({
    super.key,
    required this.shown,
    required this.total,
    required this.isLoadingMore,
    required this.onLoadMore,
  });

  final int shown;
  final int total;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Text(
            '$shown / $total affiché(s)',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (shown < total) ...[
            const SizedBox(height: 8),
            isLoadingMore
                ? const CircularProgressIndicator()
                : OutlinedButton(
                    onPressed: onLoadMore,
                    child: const Text('Charger plus'),
                  ),
          ],
        ],
      ),
    );
  }
}
