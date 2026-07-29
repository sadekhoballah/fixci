import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/service_category.dart';
import '../admin_ops_controller.dart';
import '../admin_ops_state.dart';

const _statusLabels = {
  'pending': 'En attente',
  'assigned': 'Assignée',
  'in_progress': 'En cours',
  'awaiting_client_confirmation': 'Attente confirmation',
  'completed': 'Terminée',
  'cancelled': 'Annulée',
  'expired': 'Expirée',
};

String _categoryLabel(String wireValue) => ServiceCategory.values
    .firstWhere(
      (c) => c.wireValue == wireValue,
      orElse: () => ServiceCategory.plumber,
    )
    .label;

class AdminOpsScreen extends ConsumerWidget {
  const AdminOpsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminOpsControllerProvider);
    final controller = ref.read(adminOpsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Live Ops')),
      body: SafeArea(
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: controller.refresh,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (state.errorMessage != null) ...[
                      Text(
                        state.errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _RangeSelector(
                      selected: state.range,
                      onChanged: controller.setRange,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Présence (${state.online.length} en ligne)',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _PresenceTable(online: state.online),
                    if (state.stats case final stats?) ...[
                      const SizedBox(height: 28),
                      const Text(
                        'Demandes par statut',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _CountGrid(
                        entries: stats.byStatus
                            .map(
                              (s) => MapEntry(
                                _statusLabels[s.status] ?? s.status,
                                s.count,
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'Par district',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _CountGrid(
                        entries: stats.byDistrict
                            .map((d) => MapEntry(d.name, d.count))
                            .toList(),
                        emptyLabel: 'Aucune demande sur cette période.',
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'Par métier',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _CountGrid(
                        entries: stats.byCategory
                            .map(
                              (c) => MapEntry(_categoryLabel(c.name), c.count),
                            )
                            .toList(),
                        emptyLabel: 'Aucune demande sur cette période.',
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.selected, required this.onChanged});

  final OpsStatsRange selected;
  final ValueChanged<OpsStatsRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<OpsStatsRange>(
      segments: OpsStatsRange.values
          .map(
            (r) => ButtonSegment(value: r, label: Text(r.label)),
          )
          .toList(),
      selected: {selected},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class _PresenceTable extends StatelessWidget {
  const _PresenceTable({required this.online});

  final List<OnlineCraftsman> online;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (online.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'Aucun artisan en ligne actuellement.',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    return Container(
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Nom')),
            DataColumn(label: Text('Téléphone')),
            DataColumn(label: Text('Métier')),
            DataColumn(label: Text('District')),
            DataColumn(label: Text('En ligne depuis')),
          ],
          rows: online
              .map(
                (c) => DataRow(
                  cells: [
                    DataCell(Text(c.fullName ?? '—')),
                    DataCell(Text(c.phone)),
                    DataCell(Text(_categoryLabel(c.category))),
                    DataCell(Text(c.districtName)),
                    DataCell(Text(_formatSince(c.onlineSince))),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  String _formatSince(DateTime? since) {
    if (since == null) return '—';
    final elapsed = DateTime.now().toUtc().difference(since);
    if (elapsed.inMinutes < 1) return "à l'instant";
    if (elapsed.inHours < 1) return '${elapsed.inMinutes} min';
    if (elapsed.inDays < 1) return '${elapsed.inHours} h';
    return '${elapsed.inDays} j';
  }
}

class _CountGrid extends StatelessWidget {
  const _CountGrid({
    required this.entries,
    this.emptyLabel,
  });

  final List<MapEntry<String, int>> entries;
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (entries.isEmpty && emptyLabel != null) {
      return Text(emptyLabel!, style: TextStyle(color: colorScheme.onSurfaceVariant));
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: entries
          .map(
            (entry) => Container(
              width: 160,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.value}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
