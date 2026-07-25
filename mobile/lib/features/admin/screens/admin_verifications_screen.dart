import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../admin_controller.dart';
import '../admin_repository.dart';
import '../admin_state.dart';

String _formatDate(DateTime dt) {
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
}

class AdminVerificationsScreen extends ConsumerWidget {
  const AdminVerificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminControllerProvider);
    final controller = ref.read(adminControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Vérifications en attente')),
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
                        () => controller.reject(entry.userId),
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
  Future<void> Function() onConfirm,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Rejeter cette demande ?'),
      content: Text(
        '${entry.fullName ?? "Ce compte"} ne pourra plus recevoir de missions '
        "tant qu'il ne sera pas réactivé.",
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
  if (confirmed == true) await onConfirm();
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
              Icon(entry.serviceCategory.icon, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.fullName ?? 'Sans nom',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${entry.serviceCategory.label} · ${entry.phone}',
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
          if (entry.experienceDetails != null &&
              entry.experienceDetails!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              entry.experienceDetails!,
              style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Inscrit le ${_formatDate(entry.createdAt)}',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          _IdCardPreview(userId: entry.userId),
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

class _IdCardPreview extends ConsumerStatefulWidget {
  const _IdCardPreview({required this.userId});

  final String userId;

  @override
  ConsumerState<_IdCardPreview> createState() => _IdCardPreviewState();
}

class _IdCardPreviewState extends ConsumerState<_IdCardPreview> {
  late Future<Uint8List> _bytesFuture;

  @override
  void initState() {
    super.initState();
    _bytesFuture = ref
        .read(adminRepositoryProvider)
        .getIdCardBytes(widget.userId);
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
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
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
