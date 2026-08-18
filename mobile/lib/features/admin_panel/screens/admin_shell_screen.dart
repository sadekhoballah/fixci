import 'package:flutter/material.dart';
import 'admin_blacklist_screen.dart';
import 'admin_broadcast_screen.dart';
import 'admin_directory_screen.dart';
import 'admin_districts_screen.dart';
import 'admin_kyc_screen.dart';
import 'admin_missions_screen.dart';
import 'admin_ops_screen.dart';

// Minimal shell for the post-login admin dashboard. All 5 modules of the
// founder's original spec are tabs here, plus the directory and missions
// moderation added after — an IndexedStack + NavigationBar scales fine for
// a handful of tabs without needing routing/GoRouter.
class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({super.key});

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  int _index = 0;

  static const _screens = [
    AdminKycScreen(),
    AdminDistrictsScreen(),
    AdminOpsScreen(),
    AdminBlacklistScreen(),
    AdminBroadcastScreen(),
    AdminDirectoryScreen(),
    AdminMissionsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.verified_user_outlined),
            label: 'KYC',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            label: 'Districts',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            label: 'Live Ops',
          ),
          NavigationDestination(
            icon: Icon(Icons.block_rounded),
            label: 'Liste noire',
          ),
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            label: 'Diffusion',
          ),
          NavigationDestination(
            icon: Icon(Icons.contacts_outlined),
            label: 'Annuaire',
          ),
          NavigationDestination(
            icon: Icon(Icons.work_outline_rounded),
            label: 'Missions',
          ),
        ],
      ),
    );
  }
}
