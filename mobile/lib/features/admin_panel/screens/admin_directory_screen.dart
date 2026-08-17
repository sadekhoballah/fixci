import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/service_category.dart';
import '../admin_directory_controller.dart';
import '../admin_directory_state.dart';

String _categoryLabel(String wireValue) => ServiceCategory.values
    .firstWhere(
      (c) => c.wireValue == wireValue,
      orElse: () => ServiceCategory.plumber,
    )
    .label;

class AdminDirectoryScreen extends ConsumerWidget {
  const AdminDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminDirectoryControllerProvider);
    final controller = ref.read(adminDirectoryControllerProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Annuaire')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                children: [
                  SegmentedButton<DirectoryTab>(
                    segments: const [
                      ButtonSegment(
                        value: DirectoryTab.clients,
                        label: Text('Clients'),
                      ),
                      ButtonSegment(
                        value: DirectoryTab.craftsmen,
                        label: Text('Artisans'),
                      ),
                    ],
                    selected: {state.tab},
                    onSelectionChanged: (selection) =>
                        controller.setTab(selection.first),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    // Keyed to the tab: this field has no controller (state
                    // only holds the debounced value, not every keystroke),
                    // so without a key change here Flutter reuses the
                    // Element on tab switch and keeps whatever text was
                    // last typed on screen — even after setTab resets
                    // state.search, since that's a different mechanism
                    // than this widget's own internal TextEditingValue.
                    key: ValueKey(state.tab),
                    decoration: const InputDecoration(
                      labelText: 'Rechercher par téléphone',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    keyboardType: TextInputType.phone,
                    onChanged: controller.setSearch,
                  ),
                  if (state.tab == DirectoryTab.craftsmen) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: state.category,
                      decoration: const InputDecoration(labelText: 'Métier'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Tous les métiers'),
                        ),
                        ...ServiceCategory.values.map(
                          (c) => DropdownMenuItem(
                            value: c.wireValue,
                            child: Text(c.label),
                          ),
                        ),
                      ],
                      onChanged: controller.setCategory,
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: controller.refresh,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        children: [
                          if (state.errorMessage != null) ...[
                            Text(
                              state.errorMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 16),
                          ],
                          Text(
                            '${state.entries.length} résultat(s)',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (state.entries.isEmpty)
                            const Text('Aucun résultat.')
                          else
                            ...state.entries.map(
                              (entry) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _DirectoryCard(
                                  entry: entry,
                                  colorScheme: colorScheme,
                                  isProcessing: state.processingIds.contains(
                                    entry.userId,
                                  ),
                                  onDelete: () =>
                                      _confirmDeleteAccount(
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
          ],
        ),
      ),
    );
  }

  // Step 1 of the "reset account" flow: type the phone number back to
  // confirm (irreversible action), then delete. If the account still has a
  // mission in progress, the delete comes back as activeMission instead of
  // a dead-end error — offer to force-cancel the mission and retry once.
  Future<void> _confirmDeleteAccount(
    BuildContext context,
    AdminDirectoryController controller,
    DirectoryEntry entry,
  ) async {
    final result = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => _DeleteAccountDialog(entry: entry),
    );
    if (result == null) return;
    final reason = result.isEmpty ? null : result;

    final outcome = await controller.deleteAccount(entry.userId, reason);
    if (outcome != DeleteAccountOutcome.activeMission || !context.mounted) {
      return;
    }

    final shouldCancelMission = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mission en cours'),
        content: Text(
          'Ce compte (${entry.phone}) a une mission en cours. '
          "L'annuler et supprimer le compte quand même ?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Annuler la mission et supprimer'),
          ),
        ],
      ),
    );
    if (shouldCancelMission != true) return;

    final cancelled = await controller.cancelActiveMissions(entry.userId);
    if (!cancelled) return;
    await controller.deleteAccount(entry.userId, reason);
  }
}

class _DirectoryCard extends StatelessWidget {
  const _DirectoryCard({
    required this.entry,
    required this.colorScheme,
    required this.isProcessing,
    required this.onDelete,
  });

  final DirectoryEntry entry;
  final ColorScheme colorScheme;
  final bool isProcessing;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
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
                  entry.fullName ?? '—',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.phone,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    entry.districtName,
                    if (entry.serviceCategory != null)
                      _categoryLabel(entry.serviceCategory!),
                  ].join(' · '),
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                // ratingsCount is only ever populated for craftsmen (see
                // AdminDirectoryRepository._parseItems) — absent on the
                // clients tab.
                if (entry.ratingsCount != null) ...[
                  const SizedBox(height: 6),
                  _CraftsmanStats(entry: entry, colorScheme: colorScheme),
                ],
              ],
            ),
          ),
          _OnlineBadge(isOnline: entry.isOnline),
          const SizedBox(width: 8),
          isProcessing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  icon: const Icon(Icons.person_remove_outlined),
                  tooltip: 'Supprimer le compte',
                  onPressed: onDelete,
                ),
        ],
      ),
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.entry});

  final DirectoryEntry entry;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
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
    final entry = widget.entry;
    return AlertDialog(
      title: const Text('Supprimer le compte ?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Action irréversible. ${entry.fullName ?? 'Ce compte'} pourra '
            'se réinscrire avec ce numéro par la suite.\n\n'
            'Tapez ${entry.phone} pour confirmer.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            autofocus: true,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Téléphone'),
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
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _phoneController,
          builder: (context, value, _) {
            final matches = value.text.trim() == entry.phone;
            return TextButton(
              onPressed: matches
                  ? () => Navigator.of(
                      context,
                    ).pop(_reasonController.text.trim())
                  : null,
              child: const Text('Supprimer'),
            );
          },
        ),
      ],
    );
  }
}

class _CraftsmanStats extends StatelessWidget {
  const _CraftsmanStats({required this.entry, required this.colorScheme});

  final DirectoryEntry entry;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final rating = entry.averageRating;
    final statStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurfaceVariant,
    );
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, size: 16, color: Colors.amber[700]),
            const SizedBox(width: 2),
            Text(
              rating != null
                  ? '${rating.toStringAsFixed(1)} (${entry.ratingsCount})'
                  : 'Pas encore noté',
              style: statStyle,
            ),
          ],
        ),
        Text(
          '${entry.completedCount ?? 0} terminées · '
          '${entry.assignedCount ?? 0} assignées',
          style: statStyle,
        ),
      ],
    );
  }
}

class _OnlineBadge extends StatelessWidget {
  const _OnlineBadge({required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? Colors.green : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            isOnline ? 'En ligne' : 'Hors ligne',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
