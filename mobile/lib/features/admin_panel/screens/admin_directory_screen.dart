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
}

class _DirectoryCard extends StatelessWidget {
  const _DirectoryCard({required this.entry, required this.colorScheme});

  final DirectoryEntry entry;
  final ColorScheme colorScheme;

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
              ],
            ),
          ),
          _OnlineBadge(isOnline: entry.isOnline),
        ],
      ),
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
