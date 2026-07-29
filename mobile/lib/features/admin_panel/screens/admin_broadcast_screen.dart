import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/service_category.dart';
import '../admin_broadcast_controller.dart';
import '../admin_broadcast_state.dart';
import '../admin_districts_controller.dart';

const _roleLabels = {'client': 'Clients', 'craftsman': 'Artisans'};

String _categoryLabel(String wireValue) => ServiceCategory.values
    .firstWhere(
      (c) => c.wireValue == wireValue,
      orElse: () => ServiceCategory.plumber,
    )
    .label;

class AdminBroadcastScreen extends ConsumerStatefulWidget {
  const AdminBroadcastScreen({super.key});

  @override
  ConsumerState<AdminBroadcastScreen> createState() =>
      _AdminBroadcastScreenState();
}

class _AdminBroadcastScreenState extends ConsumerState<AdminBroadcastScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  String? _role;
  ServiceCategory? _serviceCategory;
  String? _districtId;
  bool _waitlistOnly = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminBroadcastControllerProvider);
    final controller = ref.read(adminBroadcastControllerProvider.notifier);
    final districts = ref.watch(adminDistrictsControllerProvider).districts;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Diffusion')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.refreshHistory,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Nouvelle notification',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Titre'),
                maxLength: 120,
              ),
              TextField(
                controller: _bodyController,
                decoration: const InputDecoration(labelText: 'Message'),
                maxLines: 3,
                maxLength: 1000,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Destinataires'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Tous')),
                  DropdownMenuItem(value: 'client', child: Text('Clients')),
                  DropdownMenuItem(
                    value: 'craftsman',
                    child: Text('Artisans'),
                  ),
                ],
                onChanged: (value) => setState(() {
                  _role = value;
                  if (value != 'craftsman') _serviceCategory = null;
                }),
              ),
              if (_role == 'craftsman') ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<ServiceCategory?>(
                  initialValue: _serviceCategory,
                  decoration: const InputDecoration(labelText: 'Métier'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Tous les métiers'),
                    ),
                    ...ServiceCategory.values.map(
                      (c) =>
                          DropdownMenuItem(value: c, child: Text(c.label)),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _serviceCategory = value),
                ),
              ],
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                initialValue: _districtId,
                decoration: const InputDecoration(labelText: 'District'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Tous les districts'),
                  ),
                  ...districts.map(
                    (d) => DropdownMenuItem(
                      value: d.id,
                      child: Text(d.name),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _districtId = value),
              ),
              CheckboxListTile(
                value: _waitlistOnly,
                onChanged: (value) =>
                    setState(() => _waitlistOnly = value ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  "Uniquement les comptes en liste d'attente",
                ),
              ),
              const SizedBox(height: 12),
              if (state.errorMessage != null) ...[
                Text(
                  state.errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 12),
              ],
              if (state.lastResult != null) ...[
                _ResultBanner(result: state.lastResult!),
                const SizedBox(height: 12),
              ],
              FilledButton(
                onPressed: state.isSending ? null : () => _send(controller),
                child: state.isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Envoyer'),
              ),
              const SizedBox(height: 28),
              const Text(
                'Historique',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              if (state.isLoadingHistory)
                const Center(child: CircularProgressIndicator())
              else if (state.history.isEmpty)
                const Text('Aucune notification envoyée.')
              else
                ...state.history.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _HistoryCard(entry: entry, colorScheme: colorScheme),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _send(AdminBroadcastController controller) async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) return;
    await controller.send(
      title: title,
      body: body,
      role: _role,
      serviceCategory: _serviceCategory?.wireValue,
      districtId: _districtId,
      waitlistOnly: _waitlistOnly,
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.result});

  final BroadcastSendResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Envoyé à ${result.recipientCount} destinataire(s) '
        '(${result.successCount} réussi(s), ${result.failureCount} échec(s)).',
        style: const TextStyle(color: Colors.green),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry, required this.colorScheme});

  final BroadcastHistoryEntry entry;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final filters = <String>[
      if (entry.targetRole != null) _roleLabels[entry.targetRole]!,
      if (entry.targetServiceCategory != null)
        _categoryLabel(entry.targetServiceCategory!),
      if (entry.targetDistrictName != null) entry.targetDistrictName!,
      if (entry.waitlistOnly) "Liste d'attente uniquement",
    ];

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
          Text(
            entry.title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(entry.body, style: TextStyle(color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text(
            '${filters.isEmpty ? "Tous les utilisateurs" : filters.join(" · ")} '
            '— ${entry.recipientCount} destinataire(s)',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
