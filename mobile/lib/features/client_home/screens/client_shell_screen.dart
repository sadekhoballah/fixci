import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/user_role.dart';
import '../../../core/notifications/push_notification_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../client_account/screens/client_account_screen.dart';
import '../../client_jobs/screens/client_jobs_screen.dart';
import '../../missions/screens/missions_home_screen.dart';
import '../../service_request/service_request_repository.dart';
import 'client_home_screen.dart';

// How often the shell re-polls clientActiveRequestNoticeProvider while the
// app sits open in the foreground — see the timer in initState below for why
// this exists alongside the resume-triggered invalidate.
const _activeRequestPollInterval = Duration(seconds: 20);

// The client side's app shell: Home (trade grid), Missions/Freelance,
// Historique, Compte — mirrors ArtisanShellScreen's IndexedStack +
// NavigationBar shape, minus the Stats tab (craftsman-only concern).
class ClientShellScreen extends ConsumerStatefulWidget {
  const ClientShellScreen({super.key});

  @override
  ConsumerState<ClientShellScreen> createState() => _ClientShellScreenState();
}

class _ClientShellScreenState extends ConsumerState<ClientShellScreen>
    with WidgetsBindingObserver {
  int _index = 0;
  Timer? _activeRequestPollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Every "already logged in as a client" path lands here — see
    // PushNotificationService.init for why this is the chosen choke point.
    ref.read(pushNotificationServiceProvider).init(role: UserRole.client);
    // Covers the gap neither mount-fetch nor didChangeAppLifecycleState
    // catches: a client who leaves the live-tracking screen (its socket
    // subscription disconnects on dispose — see
    // ServiceRequestController.build's onDispose) and then just sits on Home
    // in the foreground the whole time. Without this, a craftsman completing
    // the job mid-sit never updates the "mission en cours" banner — nothing
    // here re-fetches until the app backgrounds/resumes or Home remounts.
    // Cheap best-effort REST poll; a push notification / resume invalidate
    // still wins the race whenever either fires first.
    _activeRequestPollTimer = Timer.periodic(
      _activeRequestPollInterval,
      (_) => ref.invalidate(clientActiveRequestNoticeProvider),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _activeRequestPollTimer?.cancel();
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
    MissionsHomeScreen(),
    ClientJobsScreen(),
    ClientAccountScreen(),
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
            icon: const Icon(Icons.work_outline_rounded),
            selectedIcon: const Icon(Icons.work_rounded),
            label: l10n.missionsTab,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_outlined),
            selectedIcon: const Icon(Icons.history_rounded),
            label: l10n.historyTab,
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
