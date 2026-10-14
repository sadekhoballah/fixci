import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../admin_history_controller.dart';
import '../admin_history_state.dart';
import 'admin_history_widgets.dart';

const _statusLabels = {
  'completed': 'Terminée',
  'archived': 'Retirée / annulée',
  'rejected': 'Rejetée',
};

const _statusColors = {
  'completed': Colors.green,
  'archived': Colors.orange,
  'rejected': Colors.red,
};

// Read-only history of Missions/Freelance board posts that are over:
// completed, withdrawn by the poster, or rejected at moderation.
class AdminMissionHistoryScreen extends ConsumerWidget {
  const AdminMissionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminMissionHistoryControllerProvider);
    final controller = ref.read(adminMissionHistoryControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Missions effectuées')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Rechercher (titre, nom ou téléphone)',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: controller.setSearch,
              ),
              const SizedBox(height: 12),
              HistoryDateFilter(
                date: state.date,
                onChanged: controller.setDate,
              ),
              const SizedBox(height: 4),
              Text(
                'Filtre sur le jour de création de la mission.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              HistoryStatusChips(
                byStatus: state.byStatus,
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
                const Text('Aucune mission.')
              else ...[
                for (final mission in state.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _MissionHistoryCard(mission: mission),
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

class _MissionHistoryCard extends StatelessWidget {
  const _MissionHistoryCard({required this.mission});

  final MissionHistoryItem mission;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final m = mission;
    final posterRole = m.posterRole == 'craftsman' ? 'Artisan' : 'Client';
    final endLabel = switch (m.status) {
      'completed' => 'Terminée le',
      'archived' => 'Retirée le',
      _ => 'Rejetée le',
    };

    return HistoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  m.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              HistoryStatusBadge(
                label: _statusLabels[m.status] ?? m.status,
                color: _statusColors[m.status] ?? Colors.grey,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${historyCategoryLabel(m.category)} · ${m.locationAddress}',
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
          const Divider(height: 20),
          HistoryInfoLine(
            label: 'Publiée par',
            value:
                '${_person(m.poster.displayName, m.poster.phone)} '
                '($posterRole)',
          ),
          HistoryInfoLine(
            label: 'Réalisée par',
            value: m.performer == null
                ? '—'
                : _person(m.performer!.displayName, m.performer!.phone),
          ),
          HistoryInfoLine(
            label: 'Candidatures',
            value: '${m.applicationsCount}',
          ),
          HistoryInfoLine(label: 'Prix de départ', value: m.startingPrice),
          const SizedBox(height: 8),
          HistoryInfoLine(
            label: 'Créée le',
            value: formatHistoryDate(m.createdAt),
          ),
          HistoryInfoLine(
            label: 'Publiée le',
            value: m.publishedAt == null
                ? null
                : formatHistoryDate(m.publishedAt!),
          ),
          HistoryInfoLine(
            label: 'Artisan choisi le',
            value: m.selectedAt == null
                ? null
                : formatHistoryDate(m.selectedAt!),
          ),
          HistoryInfoLine(label: endLabel, value: formatHistoryDate(m.endedAt)),
          if (m.selectedAt != null && m.completedAt != null)
            HistoryInfoLine(
              label: 'Durée de réalisation',
              value: formatHistoryDuration(
                m.completedAt!.difference(m.selectedAt!),
              ),
            ),
          HistoryInfoLine(label: 'Motif du rejet', value: m.rejectionReason),
        ],
      ),
    );
  }

  String _person(String name, String? phone) =>
      phone == null || phone == name ? name : '$name · $phone';
}
