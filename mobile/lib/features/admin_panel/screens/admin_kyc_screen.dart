import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../admin_auth_controller.dart';
import '../admin_kyc_controller.dart';
import '../admin_kyc_repository.dart';
import '../admin_kyc_state.dart';

String _formatDate(DateTime dt) {
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
}

class AdminKycScreen extends ConsumerWidget {
  const AdminKycScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminKycControllerProvider);
    final controller = ref.read(adminKycControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vérifications en attente'),
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
                  state.errorMessage ?? 'Aucune demande en attente.',
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
                    return _VerificationCard(
                      entry: entry,
                      isProcessing: state.processingUserIds.contains(
                        entry.userId,
                      ),
                      onApprove: () => controller.approve(entry.userId),
                      onReject: () => _confirmReject(
                        context,
                        entry,
                        (reason) => controller.reject(entry.userId, reason),
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
  PendingVerification entry,
  Future<void> Function(String? reason) onConfirm,
) async {
  final reasonController = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Rejeter cette demande ?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${entry.fullName ?? "Ce compte"} ne pourra plus recevoir de missions '
            "tant qu'il ne sera pas réactivé. Une notification lui sera envoyée.",
          ),
          const SizedBox(height: 16),
          TextField(
            controller: reasonController,
            decoration: const InputDecoration(
              labelText: 'Raison du rejet (optionnel)',
              hintText: 'Ex. : photo illisible',
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

class _VerificationCard extends ConsumerWidget {
  const _VerificationCard({
    required this.entry,
    required this.isProcessing,
    required this.onApprove,
    required this.onReject,
  });

  final PendingVerification entry;
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
                entry.serviceCategory?.icon ?? Icons.person_rounded,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.fullName ?? 'Sans nom',
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
            entry.serviceCategory != null
                ? '${entry.serviceCategory!.label} · ${entry.phone}'
                : 'Client · ${entry.phone}',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (entry.experienceDetails != null &&
              entry.experienceDetails!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              entry.experienceDetails!,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Inscrit le ${_formatDate(entry.createdAt)}',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          if (entry.idAutoCheck != null) ...[
            _AutoCheckBadge(check: entry.idAutoCheck!),
            const SizedBox(height: 8),
          ],
          _DocumentPreview(
            load: () => ref
                .read(adminKycRepositoryProvider)
                .getIdCardBytes(entry.userId, entry.role),
          ),
          if (entry.serviceCategory?.requiresDriverLicense ?? false) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'Permis de conduire',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  entry.licenseVerified
                      ? Icons.check_circle
                      : Icons.hourglass_bottom_rounded,
                  size: 14,
                  color: entry.licenseVerified ? Colors.green : Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (entry.licenseAutoCheck != null) ...[
              _AutoCheckBadge(check: entry.licenseAutoCheck!),
              const SizedBox(height: 8),
            ],
            _DocumentPreview(
              load: () => ref
                  .read(adminKycRepositoryProvider)
                  .getLicenseBytes(entry.userId),
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

// The Google Vision pre-check verdict, shown just above the document it
// scored. Advisory: it only pre-sorts the admin's attention (green = likely
// fine, amber = look closely, red = Vision saw no document at all). Tap to
// see exactly which signals fired.
class _AutoCheckBadge extends StatelessWidget {
  const _AutoCheckBadge({required this.check});

  final IdAutoCheck check;

  ({Color color, IconData icon, String label}) get _style {
    if (check.degraded) {
      return (
        color: Colors.blueGrey,
        icon: Icons.cloud_off_rounded,
        label: 'Auto : non analysé',
      );
    }
    return switch (check.verdict) {
      IdAutoCheckVerdict.pass => (
        color: Colors.green,
        icon: Icons.verified_rounded,
        label: 'Auto : document probable',
      ),
      IdAutoCheckVerdict.uncertain => (
        color: Colors.orange.shade800,
        icon: Icons.help_outline_rounded,
        label: 'Auto : à vérifier',
      ),
      IdAutoCheckVerdict.reject => (
        color: Colors.red.shade700,
        icon: Icons.report_gmailerrorred_rounded,
        label: 'Auto : aucun document détecté',
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = _style;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(s.label),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!check.degraded) Text('Score : ${check.score}'),
              const SizedBox(height: 8),
              Text(
                check.reasons.isEmpty
                    ? 'Aucun détail.'
                    : check.reasons.map((r) => '• $r').join('\n'),
              ),
              if (check.at != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Analysé le ${_formatDate(check.at!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      dialogContext,
                    ).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Fermer'),
            ),
          ],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: s.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: s.color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(s.icon, size: 16, color: s.color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                s.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: s.color,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.info_outline_rounded, size: 13, color: s.color),
          ],
        ),
      ),
    );
  }
}

// Renders a KYC document photo, fetched lazily via [load] — shared by the ID
// card preview and (for taxi/camion) the driver's license preview above, the
// only difference between the two being which endpoint [load] hits.
class _DocumentPreview extends StatefulWidget {
  const _DocumentPreview({required this.load});

  final Future<Uint8List> Function() load;

  @override
  State<_DocumentPreview> createState() => _DocumentPreviewState();
}

class _DocumentPreviewState extends State<_DocumentPreview> {
  late Future<Uint8List> _bytesFuture;

  @override
  void initState() {
    super.initState();
    _bytesFuture = widget.load();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 10,
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
              width: double.infinity,
            );
          },
        ),
      ),
    );
  }
}
