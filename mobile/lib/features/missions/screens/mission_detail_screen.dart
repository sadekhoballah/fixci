import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/api_client.dart';
import '../../../l10n/app_localizations.dart';
import '../mission_detail_controller.dart';
import '../mission_status_style.dart';
import '../missions_models.dart';
import 'mission_applicants_screen.dart';

String _formatDistance(double? meters) {
  if (meters == null) return '';
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

// Détail + candidature, et — pour le propriétaire de sa propre annonce —
// gestion (voir les candidatures, retirer, marquer terminée).
class MissionDetailScreen extends ConsumerStatefulWidget {
  const MissionDetailScreen({super.key, required this.missionId});

  final String missionId;

  @override
  ConsumerState<MissionDetailScreen> createState() =>
      _MissionDetailScreenState();
}

class _MissionDetailScreenState extends ConsumerState<MissionDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(missionDetailControllerProvider.notifier)
          .load(widget.missionId),
    );
  }

  Future<void> _confirmApply() async {
    final l10n = AppLocalizations.of(context)!;
    final messageController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.applyToMissionButton),
        content: TextField(
          controller: messageController,
          maxLength: 500,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: l10n.applicationMessageLabel,
            hintText: l10n.applicationMessageHint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.applyToMissionButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final message = messageController.text.trim();
    ref
        .read(missionDetailControllerProvider.notifier)
        .apply(message: message.isEmpty ? null : message);
  }

  Future<void> _openApplicants(String missionId) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MissionApplicantsScreen(missionId: missionId),
      ),
    );
    // A select() on that screen changes this mission's status (-> in_progress)
    // and applicantsCount context — refetch rather than guess locally.
    if (changed == true && mounted) {
      ref.read(missionDetailControllerProvider.notifier).load(missionId);
    }
  }

  Future<void> _confirmWithdraw() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.withdrawMissionConfirmTitle),
        content: Text(l10n.withdrawMissionConfirmContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.withdrawMissionButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    ref.read(missionDetailControllerProvider.notifier).withdraw();
  }

  Future<void> _confirmComplete() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.completeMissionConfirmTitle),
        content: Text(l10n.completeMissionConfirmContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.completeMissionButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    ref.read(missionDetailControllerProvider.notifier).complete();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    ref.listen(missionDetailControllerProvider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }
    });
    final state = ref.watch(missionDetailControllerProvider);
    final mission = state.mission;

    return Scaffold(
      appBar: AppBar(title: Text(mission?.title ?? l10n.missionDetailTitle)),
      body: SafeArea(
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : mission == null
            ? Center(
                child: Text(
                  state.errorMessage ?? l10n.genericErrorMessage,
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          mission.category?.icon ?? Icons.handyman_rounded,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          mission.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    mission.description,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  _LocationRow(
                    address: mission.locationAddress,
                    distanceMeters: mission.distanceMeters,
                  ),
                  if (mission.photoStorageKeys.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 90,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: mission.photoStorageKeys.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) => _MissionPhoto(
                          storageKey: mission.photoStorageKeys[index],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _MissionActionArea(
                    mission: mission,
                    isApplying: state.isApplying,
                    isUpdatingStatus: state.isUpdatingStatus,
                    onApply: _confirmApply,
                    onViewApplicants: () => _openApplicants(mission.id),
                    onWithdraw: _confirmWithdraw,
                    onComplete: _confirmComplete,
                  ),
                ],
              ),
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({required this.address, required this.distanceMeters});

  final String address;
  final double? distanceMeters;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.location_on_outlined,
          size: 20,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(address, style: const TextStyle(fontSize: 14)),
        ),
        if (distanceMeters != null) ...[
          const SizedBox(width: 8),
          Text(
            l10n.distanceAwayLabel(_formatDistance(distanceMeters)),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _MissionPhoto extends ConsumerWidget {
  const _MissionPhoto({required this.storageKey});

  final String storageKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The endpoint takes a bare filename, not the "mission-photos/…" prefix
    // stored on the entity — see uploads.controller.ts's getMissionPhoto.
    final filename = storageKey.split('/').last;
    return FutureBuilder<Uint8List>(
      future: ref.read(apiClientProvider).getBytes('/uploads/mission-photo/$filename'),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            snapshot.data!,
            width: 90,
            height: 90,
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }
}

class _MissionActionArea extends StatelessWidget {
  const _MissionActionArea({
    required this.mission,
    required this.isApplying,
    required this.isUpdatingStatus,
    required this.onApply,
    required this.onViewApplicants,
    required this.onWithdraw,
    required this.onComplete,
  });

  final MissionDetail mission;
  final bool isApplying;
  final bool isUpdatingStatus;
  final VoidCallback onApply;
  final VoidCallback onViewApplicants;
  final VoidCallback onWithdraw;
  final VoidCallback onComplete;

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsapp(String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$digits');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    if (mission.isOwnMission) {
      final canViewApplicants =
          mission.status == MissionStatus.approvedPublished ||
          mission.status == MissionStatus.inProgress ||
          mission.status == MissionStatus.completed;
      final canWithdraw =
          mission.status == MissionStatus.pendingModeration ||
          mission.status == MissionStatus.approvedPublished ||
          mission.status == MissionStatus.rejected;
      final canComplete = mission.status == MissionStatus.inProgress;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusBanner(
            label: missionStatusStyle(mission.status, l10n).$3,
            detail: mission.status == MissionStatus.rejected
                ? mission.rejectionReason
                : null,
          ),
          if (canViewApplicants) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onViewApplicants,
                icon: const Icon(Icons.people_outline_rounded, size: 18),
                label: Text(
                  l10n.viewApplicantsButton(mission.applicantsCount ?? 0),
                ),
              ),
            ),
          ],
          if (canComplete) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isUpdatingStatus ? null : onComplete,
                icon: const Icon(Icons.task_alt_rounded, size: 18),
                label: Text(l10n.completeMissionButton),
              ),
            ),
          ],
          if (canWithdraw) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isUpdatingStatus ? null : onWithdraw,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: Colors.red,
                ),
                label: Text(
                  l10n.withdrawMissionButton,
                  style: const TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ),
          ],
        ],
      );
    }

    if (mission.status != MissionStatus.approvedPublished) {
      return _StatusBanner(label: l10n.missionNotAvailableMessage);
    }

    switch (mission.myApplicationStatus) {
      case null:
        return SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: isApplying ? null : onApply,
            icon: isApplying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_outline_rounded),
            label: Text(l10n.applyToMissionButton),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        );
      case MissionApplicationStatus.pending:
      case MissionApplicationStatus.withdrawn:
        return _StatusBanner(label: l10n.youAppliedPendingMessage);
      case MissionApplicationStatus.notSelected:
        return _StatusBanner(label: l10n.youWereNotSelectedMessage);
      case MissionApplicationStatus.selected:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusBanner(label: l10n.youWereSelectedMessage),
            if (mission.posterPhone != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _call(mission.posterPhone!),
                      icon: const Icon(Icons.call_rounded, size: 18),
                      label: Text(l10n.callButton),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _whatsapp(mission.posterPhone!),
                      icon: const Icon(Icons.chat_rounded, size: 18),
                      label: const Text('WhatsApp'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
    }
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.label, this.detail});

  final String label;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          if (detail != null) ...[
            const SizedBox(height: 6),
            Text(
              detail!,
              style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
