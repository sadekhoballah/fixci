import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../craftsman_home_controller.dart';
import '../widgets/rating_performance_card.dart';
import '../widgets/stats_chip_row.dart';

// Shares CraftsmanHomeController rather than loading its own copy of the
// same data — tier/rating/stats are already fetched and kept fresh for the
// Home tab, and this is just a fuller view of the same numbers.
class CraftsmanStatsScreen extends ConsumerWidget {
  const CraftsmanStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(craftsmanHomeControllerProvider);
    final controller = ref.read(craftsmanHomeControllerProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.statisticsTitle)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                l10n.todayLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              StatsChipRow(stats: state.stats),
              const SizedBox(height: 24),
              Text(
                l10n.performanceLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              RatingPerformanceCard(
                averageRating: state.averageRating,
                ratingsCount: state.ratingsCount,
                avgResponseSeconds: state.stats?.avgResponseSeconds,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
