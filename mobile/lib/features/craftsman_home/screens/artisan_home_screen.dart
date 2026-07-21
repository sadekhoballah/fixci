import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../craftsman_home_controller.dart';
import '../widgets/availability_toggle_card.dart';
import '../widgets/daily_stats_bar.dart';
import '../widgets/quick_tip_card.dart';
import '../widgets/radar_waiting_widget.dart';
import '../widgets/rating_performance_card.dart';
import '../widgets/subscription_status_card.dart';

class ArtisanHomeScreen extends ConsumerWidget {
  const ArtisanHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(craftsmanHomeControllerProvider);
    final controller = ref.read(craftsmanHomeControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Tableau de bord')),
      body: SafeArea(
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: controller.refresh,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    AvailabilityToggleCard(
                      isAvailable: state.isAvailable,
                      isUpdating: state.isTogglingAvailability,
                      onChanged: controller.toggleAvailability,
                    ),
                    if (state.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      _ErrorBanner(message: state.errorMessage!),
                    ],
                    const SizedBox(height: 16),
                    SubscriptionStatusCard(
                      tier: state.tier,
                      daysRemaining: state.daysRemaining,
                    ),
                    const SizedBox(height: 16),
                    RatingPerformanceCard(
                      averageRating: state.averageRating,
                      ratingsCount: state.ratingsCount,
                      avgResponseSeconds: state.stats?.avgResponseSeconds,
                    ),
                    const SizedBox(height: 24),
                    if (state.isAvailable) ...[
                      const RadarWaitingWidget(),
                      const SizedBox(height: 24),
                      DailyStatsBar(stats: state.stats),
                      const SizedBox(height: 16),
                      const QuickTipCard(),
                    ] else
                      _OfflinePrompt(),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _OfflinePrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.pause_circle_outline, size: 56, color: colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'Passez en service pour recevoir des demandes',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
