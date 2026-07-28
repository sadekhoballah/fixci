import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/user_role.dart';
import '../../../core/notifications/push_notification_service.dart';
import '../../client_account/screens/client_account_screen.dart';
import '../../client_jobs/screens/client_jobs_screen.dart';
import '../../service_request/service_request_repository.dart';
import 'client_home_screen.dart';

// The client side's app shell: Home (trade grid), Historique, Compte —
// mirrors ArtisanShellScreen's IndexedStack + NavigationBar shape, minus the
// Stats tab (craftsman-only concern).
class ClientShellScreen extends ConsumerStatefulWidget {
  const ClientShellScreen({super.key});

  @override
  ConsumerState<ClientShellScreen> createState() => _ClientShellScreenState();
}

class _ClientShellScreenState extends ConsumerState<ClientShellScreen>
    with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Every "already logged in as a client" path lands here — see
    // PushNotificationService.init for why this is the chosen choke point.
    ref.read(pushNotificationServiceProvider).init(role: UserRole.client);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    // Catches the case where the client is already sitting on the shell
    // (e.g. Home) when the craftsman marks a mission done, or was away
    // entirely and just tapped a push notification back into the app — the
    // "mission en cours" banner otherwise only refetches when Home itself
    // first mounts. See client_home_screen.dart's _ActiveRequestBanner.
    if (appState == AppLifecycleState.resumed) {
      ref.invalidate(clientActiveRequestNoticeProvider);
    }
  }

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
