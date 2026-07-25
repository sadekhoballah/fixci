import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/session_storage.dart';
import '../../../core/network/api_client.dart';
import '../../admin/screens/admin_verifications_screen.dart';

class _ClientMe {
  const _ClientMe({
    required this.fullName,
    required this.phone,
    required this.idVerified,
    required this.completedMissionsCount,
  });

  final String? fullName;
  final String phone;
  final bool idVerified;
  final int completedMissionsCount;
}

class ClientAccountScreen extends ConsumerStatefulWidget {
  const ClientAccountScreen({super.key});

  @override
  ConsumerState<ClientAccountScreen> createState() => _ClientAccountScreenState();
}

class _ClientAccountScreenState extends ConsumerState<ClientAccountScreen> {
  _ClientMe? _me;
  String? _errorMessage;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _load();
    ref.read(sessionStorageProvider).loadIsAdmin().then((isAdmin) {
      if (mounted) setState(() => _isAdmin = isAdmin);
    });
  }

  Future<void> _load() async {
    try {
      final response = await ref.read(apiClientProvider).get('/clients/me');
      if (!mounted) return;
      setState(() {
        _me = _ClientMe(
          fullName: response['fullName'] as String?,
          phone: response['phone'] as String,
          idVerified: response['idVerified'] as bool,
          completedMissionsCount: response['completedMissionsCount'] as int,
        );
        _errorMessage = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Impossible de charger votre compte.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final me = _me;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compte'),
        actions: [
          if (_isAdmin)
            IconButton(
              tooltip: 'Vérifications en attente',
              icon: const Icon(Icons.admin_panel_settings_rounded),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdminVerificationsScreen(),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: me == null
            ? Center(
                child: Text(
                  _errorMessage ?? '',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          me.fullName ?? '—',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _InfoRow(
                          icon: Icons.phone_iphone_rounded,
                          label: me.phone,
                        ),
                        const SizedBox(height: 12),
                        _InfoRow(
                          icon: Icons.task_alt_rounded,
                          label:
                              '${me.completedMissionsCount} mission${me.completedMissionsCount > 1 ? 's' : ''} terminée${me.completedMissionsCount > 1 ? 's' : ''}',
                        ),
                        const SizedBox(height: 12),
                        _InfoRow(
                          icon: me.idVerified
                              ? Icons.verified_rounded
                              : Icons.error_outline_rounded,
                          label: me.idVerified
                              ? 'Identité vérifiée'
                              : 'Identité non vérifiée',
                          color: me.idVerified
                              ? const Color(0xFF1B8A3B)
                              : const Color(0xFFC62828),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedColor = color ?? colorScheme.primary;
    return Row(
      children: [
        Icon(icon, color: resolvedColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
