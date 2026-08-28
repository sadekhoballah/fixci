import 'package:flutter/material.dart';
import 'admin_blacklist_screen.dart';
import 'admin_broadcast_screen.dart';
import 'admin_directory_screen.dart';
import 'admin_districts_screen.dart';
import 'admin_kyc_screen.dart';
import 'admin_missions_screen.dart';
import 'admin_ops_screen.dart';
import 'admin_reports_screen.dart';

// Post-login shell. The dashboard grew to 8 modules, which is well past what
// a bottom NavigationBar can show legibly — so the four daily-driver screens
// (the three review queues + Live Ops) sit directly in the bar, and the
// four occasional ones (config / comms / browse) live behind a "Plus"
// destination that opens a sheet. An IndexedStack over all 8 keeps each
// screen's state alive regardless of how it's reached.
class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({super.key});

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminNavItem {
  const _AdminNavItem(this.icon, this.label, this.screen);
  final IconData icon;
  final String label;
  final Widget screen;
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  // 0..3 primary (shown in the bar), 4..7 secondary (reached via "Plus").
  int _index = 0;

  static const _primary = <_AdminNavItem>[
    _AdminNavItem(Icons.verified_user_outlined, 'KYC', AdminKycScreen()),
    _AdminNavItem(Icons.flag_outlined, 'Signalements', AdminReportsScreen()),
    _AdminNavItem(Icons.work_outline_rounded, 'Missions', AdminMissionsScreen()),
    _AdminNavItem(Icons.insights_outlined, 'Live Ops', AdminOpsScreen()),
  ];

  static const _secondary = <_AdminNavItem>[
    _AdminNavItem(Icons.contacts_outlined, 'Annuaire', AdminDirectoryScreen()),
    _AdminNavItem(Icons.block_rounded, 'Liste noire', AdminBlacklistScreen()),
    _AdminNavItem(Icons.campaign_outlined, 'Diffusion', AdminBroadcastScreen()),
    _AdminNavItem(Icons.map_outlined, 'Districts', AdminDistrictsScreen()),
  ];

  static const _all = [..._primary, ..._secondary];

  bool get _onSecondary => _index >= _primary.length;

  Future<void> _openMoreSheet() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _secondary.length; i++)
              ListTile(
                leading: Icon(_secondary[i].icon),
                title: Text(_secondary[i].label),
                selected: _index == _primary.length + i,
                onTap: () =>
                    Navigator.of(sheetContext).pop(_primary.length + i),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _index = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [for (final item in _all) item.screen],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _onSecondary ? _primary.length : _index,
        onDestinationSelected: (index) {
          if (index == _primary.length) {
            _openMoreSheet();
          } else {
            setState(() => _index = index);
          }
        },
        destinations: [
          for (final item in _primary)
            NavigationDestination(
              icon: Icon(item.icon),
              label: item.label,
            ),
          NavigationDestination(
            icon: Icon(
              _onSecondary
                  ? _secondary[_index - _primary.length].icon
                  : Icons.more_horiz_rounded,
            ),
            label: _onSecondary
                ? _secondary[_index - _primary.length].label
                : 'Plus',
          ),
        ],
      ),
    );
  }
}
