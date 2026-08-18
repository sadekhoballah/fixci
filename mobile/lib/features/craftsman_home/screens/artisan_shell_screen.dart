import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/user_role.dart';
import '../../../core/notifications/push_notification_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/screens/account_screen.dart';
import '../../craftsman_jobs/screens/craftsman_jobs_screen.dart';
import '../../missions/screens/missions_home_screen.dart';
import 'artisan_home_screen.dart';

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

class _ArtisanShellScreenState extends ConsumerState<ArtisanShellScreen> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Every "already logged in as a craftsman" path lands here — see
    // PushNotificationService.init for why this is the chosen choke point.
    ref
        .read(pushNotificationServiceProvider)
        .init(role: UserRole.craftsman);
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
            icon: const Icon(Icons.work_outline_rounded),
            selectedIcon: const Icon(Icons.work_rounded),
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
