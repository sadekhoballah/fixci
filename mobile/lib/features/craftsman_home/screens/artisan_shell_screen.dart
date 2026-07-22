import 'package:flutter/material.dart';
import '../../account/screens/account_screen.dart';
import '../../craftsman_jobs/screens/craftsman_jobs_screen.dart';
import 'artisan_home_screen.dart';
import 'craftsman_stats_screen.dart';

// The craftsman side's app shell: Home (live requests), History, Stats,
// Account. IndexedStack keeps every tab's state (notably Home's live socket
// connection) alive across tab switches rather than tearing it down.
class ArtisanShellScreen extends StatefulWidget {
  const ArtisanShellScreen({super.key});

  @override
  State<ArtisanShellScreen> createState() => _ArtisanShellScreenState();
}

class _ArtisanShellScreenState extends State<ArtisanShellScreen> {
  int _index = 0;

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
