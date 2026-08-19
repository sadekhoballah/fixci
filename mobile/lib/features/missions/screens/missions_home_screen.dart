import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../missions_board_controller.dart';
import '../missions_unseen_count_controller.dart';
import '../my_missions_controller.dart';
import 'mission_form_screen.dart';
import 'missions_board_screen.dart';
import 'my_missions_screen.dart';

// Root of the Missions/Freelance bottom-nav tab — two inner views, "Annonces"
// (the public board) and "Mes missions" (own postings + candidatures,
// including completed/archived, read-only). Owns the single Scaffold/AppBar/
// FAB shared by both; MissionsBoardScreen/MyMissionsScreen are body-only.
class MissionsHomeScreen extends ConsumerStatefulWidget {
  const MissionsHomeScreen({super.key});

  @override
  ConsumerState<MissionsHomeScreen> createState() =>
      _MissionsHomeScreenState();
}

class _MissionsHomeScreenState extends ConsumerState<MissionsHomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Opening the tab is what "seeing" the Missions badge means — see
    // MissionsUnseenCountController.markSeen.
    Future.microtask(
      () => ref.read(missionsUnseenCountControllerProvider.notifier).markSeen(),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openCreateForm() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MissionFormScreen()));
    // A freshly-created mission won't appear on the board (still pending
    // moderation) but will on "Mes missions" — refresh both, it's cheap.
    if (!mounted) return;
    ref.read(missionsBoardControllerProvider.notifier).refresh();
    ref.read(myMissionsControllerProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.missionsBoardTitle),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.missionsAnnouncesTabLabel),
            Tab(text: l10n.myMissionsTabLabel),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateForm,
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.postMissionButton),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: const [MissionsBoardScreen(), MyMissionsScreen()],
        ),
      ),
    );
  }
}
