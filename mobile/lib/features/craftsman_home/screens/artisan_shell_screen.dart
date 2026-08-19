import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/user_role.dart';
import '../../../core/notifications/push_notification_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/screens/account_screen.dart';
import '../../craftsman_jobs/screens/craftsman_jobs_screen.dart';
import '../../missions/missions_unseen_count_controller.dart';
import '../../missions/screens/missions_home_screen.dart';
import 'artisan_home_screen.dart';

// Mirrors ClientShellScreen's _activeRequestPollInterval — same cadence for
// the same reason, just for the Missions badge instead of the active-order
// banner.
const _unseenMissionsPollInterval = Duration(seconds: 20);

// The craftsman side's app shell: Home (live requests), History,
// Missions/Freelance, Account. IndexedStack keeps every tab's state (notably
// Home's live socket connection) alive across tab switches rather than
// tearing it down. Missions replaced the old Stats tab (see
// account_screen.dart for where its RatingPerformanceCard moved) — stays at
// 4 tabs rather than growing to 5.
class ArtisanShellScreen extends ConsumerStatefulWidget {
  const ArtisanShellScreen({super.key});

  @override
  ConsumerState<ArtisanShellScreen> createState() => _ArtisanShellScreenState();
}

class _ArtisanShellScreenState extends ConsumerState<ArtisanShellScreen>
    with WidgetsBindingObserver {
  int _index = 0;
  Timer? _unseenMissionsPollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Every "already logged in as a craftsman" path lands here — see
    // PushNotificationService.init for why this is the chosen choke point.
    ref
        .read(pushNotificationServiceProvider)
        .init(role: UserRole.craftsman);
    _unseenMissionsPollTimer = Timer.periodic(
      _unseenMissionsPollInterval,
      (_) => ref.read(missionsUnseenCountControllerProvider.notifier).refresh(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unseenMissionsPollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (appState == AppLifecycleState.resumed) {
      ref.read(missionsUnseenCountControllerProvider.notifier).refresh();
    }
  }

  static const _tabs = [
    ArtisanHomeScreen(),
    CraftsmanJobsScreen(),
    MissionsHomeScreen(),
    AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final unseenMissionsCount = ref.watch(missionsUnseenCountControllerProvider);
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: l10n.homeTab,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_outlined),
            selectedIcon: const Icon(Icons.history_rounded),
            label: l10n.historyTab,
          ),
          NavigationDestination(
            icon: Badge.count(
              count: unseenMissionsCount,
              isLabelVisible: unseenMissionsCount > 0,
              child: const Icon(Icons.work_outline_rounded),
            ),
            selectedIcon: Badge.count(
              count: unseenMissionsCount,
              isLabelVisible: unseenMissionsCount > 0,
              child: const Icon(Icons.work_rounded),
            ),
            label: l10n.missionsTab,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: l10n.accountTab,
          ),
        ],
      ),
    );
  }
}
