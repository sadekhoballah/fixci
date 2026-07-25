import 'package:flutter/material.dart';
import '../../client_account/screens/client_account_screen.dart';
import '../../client_jobs/screens/client_jobs_screen.dart';
import 'client_home_screen.dart';

// The client side's app shell: Home (trade grid), Historique, Compte —
// mirrors ArtisanShellScreen's IndexedStack + NavigationBar shape, minus the
// Stats tab (craftsman-only concern).
class ClientShellScreen extends StatefulWidget {
  const ClientShellScreen({super.key});

  @override
  State<ClientShellScreen> createState() => _ClientShellScreenState();
}

class _ClientShellScreenState extends State<ClientShellScreen> {
  int _index = 0;

  static const _tabs = [
    ClientHomeScreen(),
    ClientJobsScreen(),
    ClientAccountScreen(),
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
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Compte',
          ),
        ],
      ),
    );
  }
}
