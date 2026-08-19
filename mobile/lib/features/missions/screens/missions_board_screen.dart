import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/current_user_country.dart';
import '../../../core/models/district.dart';
import '../../../core/models/service_category.dart';
import '../../../l10n/app_localizations.dart';
import '../../onboarding/onboarding_repository.dart' show districtsProvider;
import '../mission_price_format.dart';
import '../mission_timing_format.dart';
import '../missions_board_controller.dart';
import '../missions_board_state.dart';
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

    return Column(
      children: [
        _FilterBar(state: state, controller: controller),
        Expanded(
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : state.items.isEmpty
              ? _EmptyBoardMessage(state: state, controller: controller)
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
                ),
        ),
      ],
    );
  }
}

// Own-district-by-default board with an empty result — most likely cause is
// the 5km cap (see MissionsBoardState.isDefaultLocationFilter), so offer
// the one-tap way out rather than a dead-end message. Any other empty case
// (an explicit district/category with nothing posted, or a real error)
// falls back to a plain centered message, same as before this widget
// existed.
class _EmptyBoardMessage extends StatelessWidget {
  const _EmptyBoardMessage({required this.state, required this.controller});

  final MissionsBoardState state;
  final MissionsBoardController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final offerWidenSearch =
        state.errorMessage == null &&
        state.isDefaultLocationFilter &&
        state.latitude != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              state.errorMessage ??
                  (offerWidenSearch
                      ? 'Aucune mission à moins de $kDefaultBoardRadiusKm km.'
                      : l10n.noMissionsYetMessage),
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            if (offerWidenSearch) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: controller.setAllDistricts,
                icon: const Icon(Icons.travel_explore_rounded, size: 18),
                label: const Text('Élargir la recherche'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// District picker chip + trade (métier) picker chip, side by side, pinned
// above the list — founder's ask: let people narrow a crowded board down to
// a trade and an area before it gets confusing to scroll through. Both open
// the same style of modal bottom sheet rather than one being a chip row and
// the other a chip+dropdown — a horizontally-scrolling trade chip row grew
// unreadable once "Tous les métiers" + all 17 trades didn't fit on screen
// (see the "Élec…" chip getting cut off at the edge before this).
class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.state, required this.controller});

  final MissionsBoardState state;
  final MissionsBoardController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Flexible(
            child: _DistrictFilterChip(state: state, controller: controller),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: _CategoryFilterChip(state: state, controller: controller),
          ),
        ],
      ),
    );
  }
}

class _CategoryFilterChip extends ConsumerWidget {
  const _CategoryFilterChip({required this.state, required this.controller});

  final MissionsBoardState state;
  final MissionsBoardController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final label = state.category?.localizedLabel(l10n) ?? 'Tous les métiers';
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => _openCategoryPicker(context),
      child: Chip(
        avatar: Icon(state.category?.icon ?? Icons.handyman_rounded, size: 16),
        label: Text(label, overflow: TextOverflow.ellipsis),
        deleteIcon: const Icon(Icons.expand_more_rounded, size: 18),
        onDeleted: () => _openCategoryPicker(context),
      ),
    );
  }

  Future<void> _openCategoryPicker(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) =>
          _CategoryPickerSheet(state: state, controller: controller),
    );
  }
}

class _CategoryPickerSheet extends StatelessWidget {
  const _CategoryPickerSheet({required this.state, required this.controller});

  final MissionsBoardState state;
  final MissionsBoardController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.apps_rounded),
              title: const Text('Tous les métiers'),
              trailing: state.category == null
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () {
                controller.setCategory(null);
                Navigator.of(context).pop();
              },
            ),
            const Divider(height: 1),
            for (final category in ServiceCategory.values)
              ListTile(
                leading: Icon(category.icon),
                title: Text(category.localizedLabel(l10n)),
                trailing: state.category == category
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () {
                  controller.setCategory(category);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _DistrictFilterChip extends ConsumerWidget {
  const _DistrictFilterChip({required this.state, required this.controller});

  final MissionsBoardState state;
  final MissionsBoardController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = state.allDistricts
        ? 'Tous les districts'
        : (state.districtName ?? 'Mon district');
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => _openDistrictPicker(context, ref),
      child: Chip(
        avatar: const Icon(Icons.place_outlined, size: 16),
        label: Text(label, overflow: TextOverflow.ellipsis),
        deleteIcon: const Icon(Icons.expand_more_rounded, size: 18),
        onDeleted: () => _openDistrictPicker(context, ref),
      ),
    );
  }

  Future<void> _openDistrictPicker(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _DistrictPickerSheet(controller: controller),
    );
  }
}

class _DistrictPickerSheet extends ConsumerWidget {
  const _DistrictPickerSheet({required this.controller});

  final MissionsBoardController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final districtsAsync = ref.watch(districtsProvider);
    // Own-country only — a client/craftsman only ever operates in the
    // country they registered in (see District.countryCode), so every other
    // country's districts are just noise here. Falls back to the full list
    // whenever the country lookup itself hasn't resolved yet or failed
    // (never a dead end — see currentUserCountryCodeProvider).
    final countryCodeAsync = ref.watch(currentUserCountryCodeProvider);
    final countryCode = countryCodeAsync.asData?.value;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.my_location_rounded),
              title: const Text('Mon district'),
              subtitle: const Text('Missions près de chez moi (par défaut)'),
              onTap: () {
                controller.setDistrict(null, null);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.public_rounded),
              title: const Text('Tous les districts'),
              onTap: () {
                controller.setAllDistricts();
                Navigator.of(context).pop();
              },
            ),
            const Divider(height: 1),
            Flexible(
              child: districtsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Impossible de charger les districts.'),
                ),
                data: (districts) {
                  final scoped = countryCode == null
                      ? districts
                      : districts
                            .where((d) => d.countryCode == countryCode)
                            .toList();
                  final sorted = [...scoped]
                    ..sort((a, b) => a.name.compareTo(b.name));
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: sorted.length,
                    itemBuilder: (context, index) {
                      final District district = sorted[index];
                      return ListTile(
                        title: Text(district.name),
                        onTap: () {
                          controller.setDistrict(district.id, district.name);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
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
    // Always a badge, never omitted — founder's call: even the defaults
    // ("Non précisé") are useful information on a card the applicant only
    // glances at, unlike missionTimingDisplayLabel's original "omit rather
    // than show a not-specified chip" contract.
    final timingLabel =
        missionTimingDisplayLabel(
          l10n,
          localeName,
          mission.timingPreference,
          mission.scheduledDayOfWeek,
          mission.scheduledHour,
        ) ??
        l10n.missionTimingUnspecifiedLabel;
    final priceLabel = mission.startingPrice != null
        ? missionPriceDisplayLabel(l10n, localeName, mission.startingPrice!)
        : l10n.missionStartingPriceUnspecifiedLabel;
    final accentColor = mission.category?.accentColor ?? colorScheme.outline;

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
          // Full-perimeter frame in the trade's own color, not just the
          // left accent bar — founder's ask: make each card's trade legible
          // as a color even from the card's outline alone.
          border: Border.all(color: accentColor.withValues(alpha: 0.55)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        // Accent bar (trade color) + info column + a small thumbnail on the
        // right — info-first layout (founder's call: the text is what a
        // craftsman scans first, the photo is confirmation, not the hook),
        // with the accent bar making the trade readable even scrolling fast
        // without stopping to read the badge.
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CategoryAccentBar(category: mission.category),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 10, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CategoryBadge(category: mission.category, dense: true),
                      const SizedBox(height: 8),
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
                          _Badge(
                            label: timingLabel,
                            icon: Icons.schedule_rounded,
                            color: colorScheme.tertiaryContainer,
                            onColor: colorScheme.onTertiaryContainer,
                          ),
                          _Badge(
                            label: priceLabel,
                            icon: Icons.sell_outlined,
                            color: colorScheme.primaryContainer,
                            onColor: colorScheme.onPrimaryContainer,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: SizedBox(
                    width: 76,
                    child: MissionPhotoOrPlaceholder(
                      storageKey: mission.photoStorageKeys.isEmpty
                          ? null
                          : mission.photoStorageKeys.first,
                      category: mission.category,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
