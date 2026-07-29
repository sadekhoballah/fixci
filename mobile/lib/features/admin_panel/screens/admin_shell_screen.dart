import 'package:flutter/material.dart';
import 'admin_districts_screen.dart';
import 'admin_kyc_screen.dart';
import 'admin_ops_screen.dart';

// Minimal shell for the post-login admin dashboard. 3 destinations so far,
// but modules 3/5 (blacklist, broadcast) each get their own screen added
// here later — an IndexedStack + NavigationBar scales to that without
// needing routing/GoRouter for what's still a handful of tabs.
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
        ],
      ),
    );
  }
}
