import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../mission_price_format.dart';
import '../mission_timing_format.dart';
import '../missions_board_controller.dart';
import '../missions_models.dart';
import '../widgets/mission_visuals.dart';
import 'mission_detail_screen.dart';

String _formatDistance(double? meters) {
  if (meters == null) return '';
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

// The public Missions/Freelance board content — approved_published listings
// only (see MissionsService.browseMissions). Body-only (no Scaffold/AppBar/
// FAB of its own): it's one of the two tabs hosted by MissionsHomeScreen,
// which owns the shared Scaffold/TabBar/FAB.
class MissionsBoardScreen extends ConsumerStatefulWidget {
  const MissionsBoardScreen({super.key});

  @override
  ConsumerState<MissionsBoardScreen> createState() =>
      _MissionsBoardScreenState();
}

class _MissionsBoardScreenState extends ConsumerState<MissionsBoardScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >
          _scrollController.position.maxScrollExtent - 200) {
        ref.read(missionsBoardControllerProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(missionsBoardControllerProvider);
    final controller = ref.read(missionsBoardControllerProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    return state.isLoading
        ? const Center(child: CircularProgressIndicator())
        : state.items.isEmpty
        ? Center(
            child: Text(
              state.errorMessage ?? l10n.noMissionsYetMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        : RefreshIndicator(
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
                return _MissionTile(mission: state.items[index]);
              },
            ),
          );
  }
}

// A photo (or category-themed placeholder) up top, title + reverse-geocoded
// address below, then a row of badges for whatever the poster actually
// filled in (distance, timing preference, starting price) — badges that
// don't apply (no position yet, unspecified timing, no price) just don't
// render rather than showing an empty/placeholder chip.
class _MissionTile extends StatelessWidget {
  const _MissionTile({required this.mission});

  final MissionSummary mission;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final localeName = Localizations.localeOf(context).languageCode;
    final timingLabel = missionTimingDisplayLabel(
      l10n,
      localeName,
      mission.timingPreference,
      mission.scheduledDayOfWeek,
      mission.scheduledHour,
    );

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MissionDetailScreen(missionId: mission.id),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
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
            SizedBox(
              height: 140,
              width: double.infinity,
              child: MissionPhotoOrPlaceholder(
                storageKey: mission.photoStorageKeys.isEmpty
                    ? null
                    : mission.photoStorageKeys.first,
                category: mission.category,
                borderRadius: BorderRadius.zero,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mission.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: MissionResolvedAddress(
                          latitude: mission.latitude,
                          longitude: mission.longitude,
                          fallback: mission.locationAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (mission.distanceMeters != null)
                        _Badge(
                          label: l10n.distanceAwayLabel(
                            _formatDistance(mission.distanceMeters),
                          ),
                          color: colorScheme.secondaryContainer,
                          onColor: colorScheme.onSecondaryContainer,
                        ),
                      if (timingLabel != null)
                        _Badge(
                          label: timingLabel,
                          icon: Icons.schedule_rounded,
                          color: colorScheme.tertiaryContainer,
                          onColor: colorScheme.onTertiaryContainer,
                        ),
                      if (mission.startingPrice != null)
                        _Badge(
                          label: missionPriceDisplayLabel(
                            l10n,
                            localeName,
                            mission.startingPrice!,
                          ),
                          icon: Icons.sell_outlined,
                          color: colorScheme.primaryContainer,
                          onColor: colorScheme.onPrimaryContainer,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
    required this.onColor,
    this.icon,
  });

  final String label;
  final Color color;
  final Color onColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: onColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: onColor,
            ),
          ),
        ],
      ),
    );
  }
}
