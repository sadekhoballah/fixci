import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../admin_auth_controller.dart';
import '../admin_missions_controller.dart';
import '../admin_missions_repository.dart';
import '../admin_missions_state.dart';

String _formatDate(DateTime dt) {
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
}

class AdminMissionsScreen extends ConsumerWidget {
  const AdminMissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminMissionsControllerProvider);
    final controller = ref.read(adminMissionsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Missions en attente'),
        actions: [
          IconButton(
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () =>
                ref.read(adminAuthControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : state.entries.isEmpty
            ? Center(
                child: Text(
                  state.errorMessage ?? 'Aucune mission en attente.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: controller.refresh,
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: state.entries.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final entry = state.entries[index];
                    return _MissionCard(
                      entry: entry,
                      isProcessing: state.processingMissionIds.contains(
                        entry.id,
                      ),
                      onApprove: () => controller.approve(entry.id),
                      onReject: () => _confirmReject(
                        context,
                        entry,
                        (reason) => controller.reject(entry.id, reason),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

Future<void> _confirmReject(
  BuildContext context,
  AdminPendingMission entry,
  Future<void> Function(String? reason) onConfirm,
) async {
  final reasonController = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Rejeter cette mission ?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '« ${entry.title} » ne sera pas publiée sur le tableau. '
            'Une notification sera envoyée à son auteur.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: reasonController,
            decoration: const InputDecoration(
              labelText: 'Raison du rejet (optionnel)',
              hintText: 'Ex. : photo illisible, description incomplète',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Retour'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Rejeter'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    final reason = reasonController.text.trim();
    await onConfirm(reason.isEmpty ? null : reason);
  }
  reasonController.dispose();
}

class _MissionCard extends ConsumerWidget {
  const _MissionCard({
    required this.entry,
    required this.isProcessing,
    required this.onApprove,
    required this.onReject,
  });

  final AdminPendingMission entry;
  final bool isProcessing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                entry.category?.icon ?? Icons.handyman_rounded,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${entry.category?.label ?? "Autre métier"} · ${entry.locationAddress}',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${entry.posterFullName ?? "Sans nom"} · ${entry.posterPhone ?? "—"}',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            entry.description,
            style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            'Publiée le ${_formatDate(entry.createdAt)}',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          if (entry.photoStorageKeys.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: entry.photoStorageKeys.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: 8),
                itemBuilder: (context, index) => _MissionPhoto(
                  missionId: entry.id,
                  storageKey: entry.photoStorageKeys[index],
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isProcessing ? null : onReject,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Rejeter'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: isProcessing ? null : onApprove,
                  icon: isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Approuver'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Renders one mission photo, fetched lazily from the admin-only endpoint —
// same shape as admin_kyc_screen.dart's _DocumentPreview.
class _MissionPhoto extends ConsumerStatefulWidget {
  const _MissionPhoto({required this.missionId, required this.storageKey});

  final String missionId;
  final String storageKey;

  @override
  ConsumerState<_MissionPhoto> createState() => _MissionPhotoState();
}

class _MissionPhotoState extends ConsumerState<_MissionPhoto> {
  late Future<Uint8List> _bytesFuture;

  @override
  void initState() {
    super.initState();
    _bytesFuture = ref
        .read(adminMissionsRepositoryProvider)
        .getMissionPhotoBytes(widget.missionId, widget.storageKey);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 90,
        height: 90,
        child: FutureBuilder<Uint8List>(
          future: _bytesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const ColoredBox(
                color: Color(0xFFF0F0F0),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const ColoredBox(
                color: Color(0xFFF0F0F0),
                child: Center(
                  child: Icon(Icons.broken_image_outlined, color: Colors.grey),
                ),
              );
            }
            return Image.memory(
              snapshot.data!,
              fit: BoxFit.cover,
              width: 90,
              height: 90,
            );
          },
        ),
      ),
    );
  }
}
