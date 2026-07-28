import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/media/id_card_picker.dart';
import '../../../core/media/image_validation.dart';
import '../../../core/network/api_client.dart';

class _ClientMe {
  const _ClientMe({
    required this.fullName,
    required this.phone,
    required this.idVerified,
    required this.isActive,
    required this.completedMissionsCount,
  });

  final String? fullName;
  final String phone;
  final bool idVerified;
  // False only ever means an admin rejected this account.
  final bool isActive;
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
  bool _isResubmittingIdCard = false;
  String? _resubmitError;

  @override
  void initState() {
    super.initState();
    _load();
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
          isActive: response['isActive'] as bool,
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

  // Lets a rejected (isActive: false) client attach a fresh ID photo without
  // going through a whole new registration — mirrors
  // CraftsmanHomeController's resubmitIdCardFromGallery/FromCamera pick→
  // validate→upload sequence, just kept local to this screen's own state
  // instead of a dedicated controller, matching how this screen already
  // manages its data.
  Future<void> _resubmitIdCardFromGallery() =>
      _resubmitIdCard(ref.read(idCardPickerProvider).pickFromGallery);

  Future<void> _resubmitIdCardFromCamera() =>
      _resubmitIdCard(ref.read(idCardPickerProvider).pickFromCamera);

  Future<void> _resubmitIdCard(
    Future<PickedImage?> Function() pick,
  ) async {
    setState(() => _resubmitError = null);
    final PickedImage? image;
    try {
      image = await pick();
    } on IdCardPickerException catch (e) {
      if (mounted) setState(() => _resubmitError = e.message);
      return;
    } catch (_) {
      if (mounted) {
        setState(() => _resubmitError = "Impossible de sélectionner l'image.");
      }
      return;
    }
    if (image == null) return; // user cancelled the picker

    try {
      await validateIdCardImage(image.bytes);
    } on ImageValidationException catch (e) {
      if (mounted) setState(() => _resubmitError = e.message);
      return;
    }

    setState(() {
      _isResubmittingIdCard = true;
      _resubmitError = null;
    });
    try {
      final apiClient = ref.read(apiClientProvider);
      final uploadResponse = await apiClient.postMultipart(
        '/uploads/id-card',
        'file',
        image.bytes,
        image.filename,
        contentTypeHeader: image.mimeType,
      );
      final storageKey = uploadResponse['storageKey'] as String;
      await apiClient.patch('/clients/me/id-card', {
        'idCardStorageKey': storageKey,
      });
      if (!mounted) return;
      setState(() => _isResubmittingIdCard = false);
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _isResubmittingIdCard = false;
          _resubmitError = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isResubmittingIdCard = false;
          _resubmitError = "Échec de l'envoi de la pièce d'identité.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final me = _me;

    return Scaffold(
      appBar: AppBar(title: const Text('Compte')),
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _VerificationStatusCard(
                    idVerified: me.idVerified,
                    isActive: me.isActive,
                    isResubmitting: _isResubmittingIdCard,
                    errorMessage: _resubmitError,
                    onResubmitFromGallery: _resubmitIdCardFromGallery,
                    onResubmitFromCamera: _resubmitIdCardFromCamera,
                  ),
                ],
              ),
      ),
    );
  }
}

// Mirrors AccountScreen's _VerificationStatusCard (craftsman side) — same
// three states (verified / rejected / pending) derived from idVerified +
// isActive, same colors and copy, so both roles read identically.
class _VerificationStatusCard extends StatelessWidget {
  const _VerificationStatusCard({
    required this.idVerified,
    required this.isActive,
    required this.isResubmitting,
    required this.errorMessage,
    required this.onResubmitFromGallery,
    required this.onResubmitFromCamera,
  });

  final bool idVerified;
  final bool isActive;
  final bool isResubmitting;
  final String? errorMessage;
  final Future<void> Function() onResubmitFromGallery;
  final Future<void> Function() onResubmitFromCamera;

  Future<void> _showSourceSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (idCardCameraSupported)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Prendre une photo'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onResubmitFromCamera();
                },
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir depuis la galerie'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onResubmitFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rejected takes priority over "verified" being stale from before a
    // resubmission — isActive: false is the one state that needs the user
    // to actually do something.
    final rejected = !isActive;

    final (bg, fg, icon, title, message) = switch (true) {
      _ when idVerified => (
        const Color(0xFFE0F2E9),
        const Color(0xFF1B8A3B),
        Icons.verified_rounded,
        'Identité vérifiée',
        'Votre pièce d\'identité a été validée.',
      ),
      _ when rejected => (
        const Color(0xFFFDE8E8),
        const Color(0xFFC62828),
        Icons.cancel_rounded,
        'Demande rejetée',
        'Votre demande a été rejetée, possiblement à cause d\'informations '
            'incorrectes (photo illisible, document invalide...). Vous '
            'pouvez soumettre une nouvelle pièce d\'identité.',
      ),
      _ => (
        const Color(0xFFFFF3CD),
        const Color(0xFF7A5B00),
        Icons.pending_rounded,
        'En attente de vérification',
        'Votre pièce d\'identité est en cours d\'examen par notre équipe.',
      ),
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: fg, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: fg),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(message, style: TextStyle(fontSize: 13, color: fg)),
          if (rejected) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isResubmitting ? null : () => _showSourceSheet(context),
                icon: isResubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_rounded, size: 18),
                label: const Text('Soumettre une nouvelle pièce d\'identité'),
                style: OutlinedButton.styleFrom(foregroundColor: fg),
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                errorMessage!,
                style: const TextStyle(fontSize: 12, color: Color(0xFFC62828)),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, color: colorScheme.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
