import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/user_role.dart';
import '../../../core/notifications/push_notification_service.dart';
import '../../account/screens/account_screen.dart';
import '../../craftsman_jobs/screens/craftsman_jobs_screen.dart';
import 'artisan_home_screen.dart';
import 'craftsman_stats_screen.dart';

// The craftsman side's app shell: Home (live requests), History, Stats,
// Account. IndexedStack keeps every tab's state (notably Home's live socket
// connection) alive across tab switches rather than tearing it down.
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
    CraftsmanStatsScreen(),
    AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'Historique',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Compte',
          ),
        ],
      ),
    );
  }
}
