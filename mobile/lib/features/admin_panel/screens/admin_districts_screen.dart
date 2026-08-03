import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../admin_districts_controller.dart';
import '../admin_districts_state.dart';

class AdminDistrictsScreen extends ConsumerWidget {
  const AdminDistrictsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminDistrictsControllerProvider);
    final controller = ref.read(adminDistrictsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Districts')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context, controller),
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
                    ...state.districts.map(
                      (district) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _DistrictCard(
                          district: district,
                          isProcessing: state.processingDistrictIds.contains(
                            district.id,
                          ),
                          onToggleArtisan: (value) =>
                              controller.toggleArtisanRegistration(
                                district.id,
                                value,
                              ),
                          onToggleClient: (value) => controller
                              .toggleClientOrdering(district.id, value),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _showCreateDialog(
    BuildContext context,
    AdminDistrictsController controller,
  ) async {
    final nameController = TextEditingController();
    var countryCode = 'CI';
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Ajouter un district'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nom (ex. Divo)'),
              ),
              const SizedBox(height: 16),
              // Matches CreateDistrictDto's LAUNCHED_COUNTRY_CODES — Russie
              // has no districts at all until it actually launches.
              DropdownButtonFormField<String>(
                initialValue: countryCode,
                decoration: const InputDecoration(labelText: 'Pays'),
                items: const [
                  DropdownMenuItem(
                    value: 'CI',
                    child: Text("Côte d'Ivoire"),
                  ),
                  DropdownMenuItem(value: 'LB', child: Text('Liban')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => countryCode = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop((nameController.text.trim(), countryCode)),
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    if (result != null && result.$1.isNotEmpty) {
      await controller.createDistrict(result.$1, result.$2);
    }
  }
}

class _DistrictCard extends StatelessWidget {
  const _DistrictCard({
    required this.district,
    required this.isProcessing,
    required this.onToggleArtisan,
    required this.onToggleClient,
  });

  final DistrictWithCounts district;
  final bool isProcessing;
  final ValueChanged<bool> onToggleArtisan;
  final ValueChanged<bool> onToggleClient;

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
              Expanded(
                child: Text(
                  district.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  district.countryCode,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ToggleRow(
            label: 'Inscription artisans',
            countLabel: district.isArtisanRegistrationActive
                ? '${district.artisansCount} actifs'
                : '${district.artisansCount} en attente',
            value: district.isArtisanRegistrationActive,
            onChanged: isProcessing ? null : onToggleArtisan,
          ),
          const SizedBox(height: 8),
          _ToggleRow(
            label: 'Commandes clients',
            countLabel: district.isClientOrderingActive
                ? '${district.clientsCount} actifs'
                : '${district.clientsCount} en attente',
            value: district.isClientOrderingActive,
            onChanged: isProcessing ? null : onToggleClient,
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.countLabel,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String countLabel;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 14)),
              Text(
                countLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}
