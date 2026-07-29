import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../admin_blacklist_controller.dart';
import '../admin_blacklist_state.dart';

class AdminBlacklistScreen extends ConsumerWidget {
  const AdminBlacklistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminBlacklistControllerProvider);
    final controller = ref.read(adminBlacklistControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Liste noire')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, controller),
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: controller.refresh,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (state.errorMessage != null) ...[
                      Text(
                        state.errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (state.entries.isEmpty)
                      const Text('Aucun numéro sur liste noire.')
                    else
                      ...state.entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _BlacklistCard(
                            entry: entry,
                            isProcessing: state.processingIds.contains(
                              entry.id,
                            ),
                            onRemove: () => _confirmRemove(
                              context,
                              controller,
                              entry,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _showAddDialog(
    BuildContext context,
    AdminBlacklistController controller,
  ) async {
    // The form fields live in their own StatefulWidget rather than
    // controllers created/disposed in this method: disposing right after
    // showDialog's future resolves races the dialog's own close transition
    // (its TextFields can still be mounted mid-animation), which throws
    // "TextEditingController used after being disposed". A State's
    // dispose() is only called once the widget is actually gone, so this
    // is the only place it's safe to do it.
    final result = await showDialog<(String phone, String? reason)>(
      context: context,
      builder: (dialogContext) => const _AddBlacklistDialog(),
    );
    if (result != null) {
      await controller.addEntry(result.$1, result.$2);
    }
  }

  Future<void> _confirmRemove(
    BuildContext context,
    AdminBlacklistController controller,
    BlacklistedPhone entry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Retirer de la liste noire ?'),
        content: Text(entry.phone),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.removeEntry(entry.id);
    }
  }
}

class _BlacklistCard extends StatelessWidget {
  const _BlacklistCard({
    required this.entry,
    required this.isProcessing,
    required this.onRemove,
  });

  final BlacklistedPhone entry;
  final bool isProcessing;
  final VoidCallback onRemove;

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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.phone,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (entry.reason != null && entry.reason!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    entry.reason!,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          isProcessing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: onRemove,
                ),
        ],
      ),
    );
  }
}

class _AddBlacklistDialog extends StatefulWidget {
  const _AddBlacklistDialog();

  @override
  State<_AddBlacklistDialog> createState() => _AddBlacklistDialogState();
}

class _AddBlacklistDialogState extends State<_AddBlacklistDialog> {
  final _phoneController = TextEditingController();
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bloquer un numéro'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _phoneController,
            autofocus: true,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Téléphone (ex. +2250700000001)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonController,
            decoration: const InputDecoration(labelText: 'Motif (optionnel)'),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () {
            final phone = _phoneController.text.trim();
            if (phone.isEmpty) return;
            final reason = _reasonController.text.trim();
            Navigator.of(
              context,
            ).pop((phone, reason.isEmpty ? null : reason));
          },
          child: const Text('Bloquer'),
        ),
      ],
    );
  }
}
