import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../admin_auth_controller.dart';
import '../admin_reports_controller.dart';
import '../admin_reports_state.dart';

String _formatDate(DateTime dt) {
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
}

String _reasonLabel(String wireValue) => switch (wireValue) {
  'harassment' => 'Harcèlement',
  'no_show' => 'Absence / ne s\'est pas présenté(e)',
  'fraud' => 'Fraude / arnaque',
  'inappropriate_content' => 'Contenu inapproprié',
  _ => 'Autre',
};

String _contextLabel(String? type) => switch (type) {
  'mission' => 'Mission',
  'service_request' => 'Demande de service',
  _ => 'Aucun contexte',
};

class AdminReportsScreen extends ConsumerWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminReportsControllerProvider);
    final controller = ref.read(adminReportsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Signalements'),
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
                  state.errorMessage ?? 'Aucun signalement en attente.',
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
                    return _ReportCard(
                      entry: entry,
                      isProcessing: state.processingReportIds.contains(
                        entry.id,
                      ),
                      onDismiss: () => controller.resolve(entry.id, 'dismiss'),
                      onWarn: () => controller.resolve(entry.id, 'warn'),
                      onDeactivate: () => _confirmDeactivate(
                        context,
                        entry,
                        (note) => controller.resolve(
                          entry.id,
                          'deactivate_reported',
                          note: note,
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

Future<void> _confirmDeactivate(
  BuildContext context,
  AdminPendingReport entry,
  Future<void> Function(String? note) onConfirm,
) async {
  final noteController = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Suspendre ce compte ?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${entry.reportedUserFullName ?? entry.reportedUserPhone ?? "Cet utilisateur"} '
            'ne pourra plus se connecter tant que le compte n\'est pas réactivé.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: noteController,
            decoration: const InputDecoration(
              labelText: 'Note interne (optionnel)',
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
          child: const Text('Suspendre'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    final note = noteController.text.trim();
    await onConfirm(note.isEmpty ? null : note);
  }
  noteController.dispose();
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.entry,
    required this.isProcessing,
    required this.onDismiss,
    required this.onWarn,
    required this.onDeactivate,
  });

  final AdminPendingReport entry;
  final bool isProcessing;
  final VoidCallback onDismiss;
  final VoidCallback onWarn;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
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
              Icon(Icons.flag_rounded, color: colorScheme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _reasonLabel(entry.reason),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                _formatDate(entry.createdAt),
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Signalé : ${entry.reportedUserFullName ?? "Sans nom"} · ${entry.reportedUserPhone ?? "—"}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Par : ${entry.reporterFullName ?? "Sans nom"} · ${entry.reporterPhone ?? "—"}',
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            'Contexte : ${_contextLabel(entry.contextType)}',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          if (entry.message != null && entry.message!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(entry.message!, style: const TextStyle(fontSize: 13)),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isProcessing ? null : onDismiss,
                  child: const Text('Classer sans suite'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: isProcessing ? null : onWarn,
                  child: const Text('Avertir'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isProcessing ? null : onDeactivate,
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              icon: isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.block_rounded, size: 18),
              label: const Text('Suspendre le compte'),
            ),
          ),
        ],
      ),
    );
  }
}
