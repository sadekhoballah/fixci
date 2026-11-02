import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../admin_countries.dart';
import '../admin_districts_controller.dart';
import '../admin_districts_state.dart';

// Verified craftsmen a waitlisted city should have before its client
// ordering is switched on — below that, clients would mostly hit the empty
// "nobody accepted" outcome. A guide shown on each card, not enforced.
const kCityReadyThreshold = 20;

class AdminDistrictsScreen extends ConsumerStatefulWidget {
  const AdminDistrictsScreen({super.key});

  @override
  ConsumerState<AdminDistrictsScreen> createState() =>
      _AdminDistrictsScreenState();
}

class _AdminDistrictsScreenState extends ConsumerState<AdminDistrictsScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminDistrictsControllerProvider);
    final controller = ref.read(adminDistrictsControllerProvider.notifier);
    // The panel-wide country filter (AppBar), shared with the other tabs.
    final countryFilter = ref.watch(adminCountryFilterProvider);
    final districts = countryFilter == null
        ? state.districts
        : state.districts
              .where((d) => d.countryCode == countryFilter)
              .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Districts'),
        actions: const [AdminCountryFilterButton()],
      ),
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
                    ...districts.map(
                      (district) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _DistrictCard(
                          district: district,
                          isProcessing: state.processingDistrictIds.contains(
                            district.id,
                          ),
                          onToggleArtisan: (value) => controller
                              .toggleArtisanRegistration(district.id, value),
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
    var countryCode = ref.read(adminCountryFilterProvider) ?? 'CI';
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
                items: adminCountries.keys
                    .map(
                      (code) => DropdownMenuItem(
                        value: code,
                        child: Text(countryWithFlag(code)),
                      ),
                    )
                    .toList(),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  countryWithFlag(district.countryCode),
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
            countLabel:
                '${district.artisansCount} '
                '${district.isArtisanRegistrationActive ? 'inscrits' : 'en attente'}'
                ' · ${district.verifiedArtisansCount} vérifiés',
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
          if (!district.isClientOrderingActive) ...[
            const SizedBox(height: 8),
            _ReadinessHint(verified: district.verifiedArtisansCount),
          ],
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

// For a city still closed to clients: how far it is from
// kCityReadyThreshold verified craftsmen.
class _ReadinessHint extends StatelessWidget {
  const _ReadinessHint({required this.verified});

  final int verified;

  @override
  Widget build(BuildContext context) {
    final ready = verified >= kCityReadyThreshold;
    final color = ready ? Colors.green : Colors.orange;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        ready
            ? '✅ $verified artisans vérifiés — prêt à ouvrir aux clients'
            : '⏳ $verified / $kCityReadyThreshold artisans vérifiés avant '
                  "l'ouverture aux clients",
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: ready ? Colors.green.shade800 : Colors.orange.shade900,
        ),
      ),
    );
  }
}
