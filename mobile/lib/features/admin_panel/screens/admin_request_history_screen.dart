import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../admin_history_controller.dart';
import '../admin_history_state.dart';
import '../admin_ops_state.dart';
import 'admin_history_widgets.dart';

const _statusLabels = {
  'pending': 'En attente',
  'assigned': 'Assignée',
  'in_progress': 'En cours',
  'awaiting_client_confirmation': 'Attente confirmation',
  'completed': 'Terminée',
  'cancelled': 'Annulée',
  'expired': 'Expirée',
};

const _statusColors = {
  'completed': Colors.green,
  'cancelled': Colors.red,
  'expired': Colors.orange,
};

const _openStatuses = {
  'pending',
  'assigned',
  'in_progress',
  'awaiting_client_confirmation',
};

// Read-only, per-request detail of the real-time matching engine: which
// client asked, how it ended, and which artisan did the job. Refreshes
// itself every 30 s (see AdminRequestHistoryController).
class AdminRequestHistoryScreen extends ConsumerWidget {
  const AdminRequestHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminRequestHistoryControllerProvider);
    final controller = ref.read(adminRequestHistoryControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Ops live détaillée')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 280,
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Client (nom ou téléphone)',
                        prefixIcon: Icon(Icons.person_search_rounded),
                      ),
                      onChanged: controller.setClient,
                    ),
                  ),
                  SizedBox(
                    width: 280,
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Artisan (nom ou téléphone)',
                        prefixIcon: Icon(Icons.engineering_outlined),
                      ),
                      onChanged: controller.setArtisan,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              HistoryDateFilter(
                date: state.date,
                onChanged: controller.setDate,
              ),
              const SizedBox(height: 16),
              _StatsTiles(byStatus: state.byStatus),
              const SizedBox(height: 16),
              HistoryStatusChips(
                byStatus: state.byStatus
                    .where((s) => s.count > 0 || s.status == state.status)
                    .toList(),
                labels: _statusLabels,
                selected: state.status,
                onSelected: controller.setStatus,
              ),
              const SizedBox(height: 16),
              if (state.errorMessage != null) ...[
                Text(
                  state.errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
              ],
              if (state.isLoading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (state.items.isEmpty)
                const Text('Aucune demande.')
              else ...[
                for (final request in state.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _RequestHistoryCard(request: request),
                  ),
                HistoryListFooter(
                  shown: state.items.length,
                  total: state.total,
                  isLoadingMore: state.isLoadingMore,
                  onLoadMore: controller.loadMore,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Headline numbers for the current client / artisan / date filters.
class _StatsTiles extends StatelessWidget {
  const _StatsTiles({required this.byStatus});

  final List<StatusCount> byStatus;

  @override
  Widget build(BuildContext context) {
    int count(String status) => byStatus
        .where((s) => s.status == status)
        .fold(0, (a, s) => a + s.count);
    final total = byStatus.fold<int>(0, (a, s) => a + s.count);
    final completed = count('completed');
    final cancelled = count('cancelled');
    final expired = count('expired');
    final open = byStatus
        .where((s) => _openStatuses.contains(s.status))
        .fold<int>(0, (a, s) => a + s.count);
    final finished = completed + cancelled + expired;
    final successRate = finished == 0
        ? '—'
        : '${(completed * 100 / finished).round()} %';

    final tiles = <MapEntry<String, String>>[
      MapEntry('Demandes', '$total'),
      MapEntry('Terminées', '$completed'),
      MapEntry('Annulées', '$cancelled'),
      MapEntry('Expirées', '$expired'),
      MapEntry('En cours', '$open'),
      MapEntry('Taux de réussite', successRate),
    ];

    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final tile in tiles)
          SizedBox(
            width: 150,
            child: HistoryCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tile.value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tile.key,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _RequestHistoryCard extends StatelessWidget {
  const _RequestHistoryCard({required this.request});

  final RequestHistoryItem request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final endLabel = switch (r.status) {
      'completed' => 'Terminée le',
      'cancelled' => 'Annulée le',
      'expired' => 'Expirée le',
      _ => null,
    };

    return HistoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  historyCategoryLabel(r.category),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              HistoryStatusBadge(
                label: _statusLabels[r.status] ?? r.status,
                color: _statusColors[r.status] ?? Colors.blue,
              ),
            ],
          ),
          const Divider(height: 20),
          HistoryInfoLine(
            label: 'Client',
            value: _person(r.client.displayName, r.client.phone),
          ),
          HistoryInfoLine(
            label: 'Artisan',
            value: r.craftsman == null
                ? '— aucun'
                : _person(r.craftsman!.displayName, r.craftsman!.phone),
          ),
          HistoryInfoLine(
            label: 'Note du client',
            value: r.ratingStars == null
                ? null
                : '${'★' * r.ratingStars!}${'☆' * (5 - r.ratingStars!)}',
          ),
          const SizedBox(height: 8),
          HistoryInfoLine(
            label: 'Demandée le',
            value: formatHistoryDate(r.createdAt),
          ),
          HistoryInfoLine(
            label: 'Assignée le',
            value: r.assignedAt == null
                ? null
                : formatHistoryDate(r.assignedAt!),
          ),
          HistoryInfoLine(
            label: 'Démarrée le',
            value: r.startedAt == null ? null : formatHistoryDate(r.startedAt!),
          ),
          if (endLabel != null)
            HistoryInfoLine(
              label: endLabel,
              value: r.endedAt == null ? null : formatHistoryDate(r.endedAt!),
            ),
          if (r.assignedAt != null)
            HistoryInfoLine(
              label: "Délai d'assignation",
              value: formatHistoryDuration(
                r.assignedAt!.difference(r.createdAt),
              ),
            ),
          if (r.startedAt != null && r.completedAt != null)
            HistoryInfoLine(
              label: "Durée d'intervention",
              value: formatHistoryDuration(
                r.completedAt!.difference(r.startedAt!),
              ),
            ),
        ],
      ),
    );
  }

  String _person(String name, String? phone) =>
      phone == null || phone == name ? name : '$name · $phone';
}
