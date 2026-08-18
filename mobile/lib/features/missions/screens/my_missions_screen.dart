import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../mission_status_style.dart';
import '../missions_models.dart';
import '../my_missions_controller.dart';
import 'mission_detail_screen.dart';

// "Mes missions" — postées + candidatées, terminées/archivées incluses en
// lecture seule (voir MissionsService.getMyMissions : pas d'endpoint
// d'archive séparé). Calqué sur client_jobs_screen.dart.
class MyMissionsScreen extends ConsumerStatefulWidget {
  const MyMissionsScreen({super.key});

  @override
  ConsumerState<MyMissionsScreen> createState() => _MyMissionsScreenState();
}

class _MyMissionsScreenState extends ConsumerState<MyMissionsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >
          _scrollController.position.maxScrollExtent - 200) {
        ref.read(myMissionsControllerProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openDetail(String missionId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MissionDetailScreen(missionId: missionId),
      ),
    );
    // Status may have changed while the detail screen was open (withdraw,
    // complete, a candidature resolving) — cheap to just refetch.
    if (mounted) ref.read(myMissionsControllerProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myMissionsControllerProvider);
    final controller = ref.read(myMissionsControllerProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.items.isEmpty) {
      return Center(
        child: Text(
          state.errorMessage ?? l10n.myMissionsEmptyMessage,
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        itemCount: state.items.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= state.items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final item = state.items[index];
          return _MineMissionTile(
            item: item,
            onTap: () => _openDetail(item.id),
          );
        },
      ),
    );
  }
}

class _MineMissionTile extends StatelessWidget {
  const _MineMissionTile({required this.item, required this.onTap});

  final MineMissionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final (chipBg, chipFg, chipLabel) = missionStatusStyle(item.status, l10n);
    // Resolved missions (no longer actionable) read as visually muted —
    // read-only archive, same idea as a greyed-out row rather than a
    // separate screen.
    final isResolved =
        item.status == MissionStatus.completed ||
        item.status == MissionStatus.archived;

    return Opacity(
      opacity: isResolved ? 0.6 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  item.category?.icon ?? Icons.handyman_rounded,
                  size: 20,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.roleInMission == 'poster'
                          ? l10n.roleInMissionPosterLabel
                          : l10n.roleInMissionApplicantLabel,
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  chipLabel,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: chipFg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
