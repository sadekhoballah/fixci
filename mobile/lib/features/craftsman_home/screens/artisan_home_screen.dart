import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../craftsman_home_controller.dart';
import '../live_requests_controller.dart';
import '../live_requests_state.dart';
import '../widgets/active_job_card.dart';
import '../widgets/craftsman_header.dart';
import '../widgets/incoming_request_card.dart';
import '../widgets/location_status_card.dart';
import '../widgets/stats_chip_row.dart';
import '../widgets/subscription_status_card.dart';

class ArtisanHomeScreen extends ConsumerStatefulWidget {
  const ArtisanHomeScreen({super.key});

  @override
  ConsumerState<ArtisanHomeScreen> createState() => _ArtisanHomeScreenState();
}

class _ArtisanHomeScreenState extends ConsumerState<ArtisanHomeScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (appState == AppLifecycleState.resumed) {
      ref.read(craftsmanHomeControllerProvider.notifier).handleAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(craftsmanHomeControllerProvider);
    final controller = ref.read(craftsmanHomeControllerProvider.notifier);
    final liveState = ref.watch(liveRequestsControllerProvider);
    final liveController = ref.read(liveRequestsControllerProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () async {
                  await controller.refresh();
                  await liveController.loadActiveJob();
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    CraftsmanHeader(
                      fullName: state.fullName,
                      isAvailable: state.isAvailable,
                      isToggling: state.isTogglingAvailability,
                      tier: state.tier,
                      averageRating: state.averageRating,
                      onToggleAvailability: controller.toggleAvailability,
                    ),
                    if (state.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      _ErrorBanner(message: state.errorMessage!),
                    ],
                    if (liveState.actionError != null) ...[
                      const SizedBox(height: 12),
                      _ErrorBanner(message: liveState.actionError!),
                    ],
                    const SizedBox(height: 16),
                    LocationStatusCard(
                      serviceEnabled: state.locationServiceEnabled,
                      permission: state.locationPermission,
                      onActivate: controller.requestLocationAccess,
                    ),
                    const SizedBox(height: 14),
                    StatsChipRow(stats: state.stats),
                    const SizedBox(height: 14),
                    SubscriptionStatusCard(
                      tier: state.tier,
                      daysRemaining: state.daysRemaining,
                    ),
                    const SizedBox(height: 20),
                    _MainContent(
                      isAvailable: state.isAvailable,
                      liveState: liveState,
                      onAccept: liveController.acceptRequest,
                      onDecline: liveController.declineRequest,
                      onStart: liveController.startJob,
                      onComplete: liveController.completeJob,
                      onCancel: liveController.cancelJob,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _MainContent extends StatelessWidget {
  const _MainContent({
    required this.isAvailable,
    required this.liveState,
    required this.onAccept,
    required this.onDecline,
    required this.onStart,
    required this.onComplete,
    required this.onCancel,
  });

  final bool isAvailable;
  final LiveRequestsState liveState;
  final ValueChanged<String> onAccept;
  final ValueChanged<String> onDecline;
  final ValueChanged<String> onStart;
  final ValueChanged<String> onComplete;
  final ValueChanged<String> onCancel;

  @override
  Widget build(BuildContext context) {
    if (!isAvailable) return const _OfflinePrompt();

    final activeJob = liveState.activeJob;
    if (activeJob != null) {
      return ActiveJobCard(
        job: activeJob,
        isProcessing: liveState.isProcessingAction,
        onStart: () => onStart(activeJob.requestId),
        onComplete: () => onComplete(activeJob.requestId),
        onCancel: () => onCancel(activeJob.requestId),
      );
    }

    if (liveState.incomingRequests.isEmpty) {
      return const _EmptyRequestsState();
    }

    return Column(
      children: [
        for (final request in liveState.incomingRequests)
          IncomingRequestCard(
            request: request,
            isProcessing: liveState.isProcessingAction,
            onAccept: () => onAccept(request.requestId),
            onDecline: () => onDecline(request.requestId),
          ),
      ],
    );
  }
}

class _EmptyRequestsState extends StatelessWidget {
  const _EmptyRequestsState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            Icons.search_rounded,
            size: 48,
            color: colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune demande à proximité pour le moment',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _OfflinePrompt extends StatelessWidget {
  const _OfflinePrompt();

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
