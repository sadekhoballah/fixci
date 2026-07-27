import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/service_category.dart';
import '../service_request_controller.dart';
import '../service_request_state.dart';
import '../widgets/star_rating_input.dart';

class SearchingScreen extends ConsumerStatefulWidget {
  const SearchingScreen({super.key, required this.category});

  final ServiceCategory category;

  @override
  ConsumerState<SearchingScreen> createState() => _SearchingScreenState();
}

// Mirrors ArtisanHomeScreen's WidgetsBindingObserver — the client side of the
// same gap: without this, a client who backgrounds the app (tapping
// "Appeler"/"WhatsApp" to reach the craftsman, or just locking the screen)
// and comes back has no way to recover a socket connection/room membership
// the OS may have quietly suspended while away. See
// ServiceRequestController.handleAppResumed.
class _SearchingScreenState extends ConsumerState<SearchingScreen>
    with WidgetsBindingObserver {
  ServiceCategory get category => widget.category;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (appState == AppLifecycleState.resumed) {
      ref.read(serviceRequestControllerProvider.notifier).handleAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(serviceRequestControllerProvider, (previous, next) {
      if (next.status == ServiceRequestStatus.cancelled &&
          previous?.status != ServiceRequestStatus.cancelled) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      if (next.status == ServiceRequestStatus.rated &&
          previous?.status != ServiceRequestStatus.rated) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
    final state = ref.watch(serviceRequestControllerProvider);
    final notifier = ref.read(serviceRequestControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(category.label)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: switch (state.status) {
            ServiceRequestStatus.assigned ||
            ServiceRequestStatus.inProgress ||
            ServiceRequestStatus.awaitingClientConfirmation => _AssignedCard(
              category: category,
              state: state,
              onCancel: notifier.cancel,
              onConfirmCompletion: notifier.confirmCompletion,
            ),
            ServiceRequestStatus.completed => _RatingCard(
              craftsmanName: state.craftsmanFullName ?? category.label,
              isSubmitting: state.isSubmittingRating,
              onSubmit: (stars, comment) =>
                  notifier.submitRating(stars: stars, comment: comment),
              onSkip: notifier.skipRating,
            ),
            ServiceRequestStatus.noCraftsmanAvailable => _Outcome(
              icon: Icons.search_off_rounded,
              iconColor: Colors.grey,
              title: 'Aucun professionnel disponible',
              message:
                  "Nous n'avons trouvé aucun ${category.label.toLowerCase()} disponible pour le moment. Réessayez dans quelques minutes.",
              primaryLabel: 'Réessayer',
              onPrimary: () => ref
                  .read(serviceRequestControllerProvider.notifier)
                  .retry(category),
              secondaryLabel: "Retour à l'accueil",
              onSecondary: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
            ),
            _ => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  'Recherche d\'un ${category.label.toLowerCase()} disponible…',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                if (state.requestId != null) ...[
                  const SizedBox(height: 32),
                  TextButton(
                    onPressed: state.isCancelling
                        ? null
                        : () => _confirmCancel(context, notifier.cancel),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: state.isCancelling
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Annuler la recherche'),
                  ),
                ],
              ],
            ),
          },
        ),
      ),
    );
  }
}

Future<void> _confirmCancel(
  BuildContext context,
  Future<void> Function() onConfirm,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Annuler la demande ?'),
      content: const Text(
        'Le professionnel assigné (le cas échéant) en sera informé.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Retour'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Annuler la demande'),
        ),
      ],
    ),
  );
  if (confirmed == true) await onConfirm();
}

class _Outcome extends StatelessWidget {
  const _Outcome({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 72),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: onPrimary,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              primaryLabel,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        if (secondaryLabel != null) ...[
          const SizedBox(height: 12),
          TextButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
        ],
      ],
    );
  }
}

// Mirrors the backend's estimateArrivalMinutes heuristic (matching.gateway.ts)
// so the client sees a comparable ETA computed locally from the craftsman's
// live position — no extra server round-trip needed.
String _distanceLabel(ServiceRequestState state) {
  if (state.craftsmanLatitude == null ||
      state.craftsmanLongitude == null ||
      state.myLatitude == null ||
      state.myLongitude == null) {
    return 'En route vers vous…';
  }
  final meters = Geolocator.distanceBetween(
    state.myLatitude!,
    state.myLongitude!,
    state.craftsmanLatitude!,
    state.craftsmanLongitude!,
  );
  final minutes = (meters / 500).round().clamp(1, 999);
  final km = (meters / 1000).toStringAsFixed(meters >= 1000 ? 1 : 2);
  return '$km km — environ $minutes min';
}

class _AssignedCard extends StatelessWidget {
  const _AssignedCard({
    required this.category,
    required this.state,
    required this.onCancel,
    required this.onConfirmCompletion,
  });

  final ServiceCategory category;
  final ServiceRequestState state;
  final Future<void> Function() onCancel;
  final Future<void> Function() onConfirmCompletion;

  Future<void> _call() async {
    final phone = state.craftsmanPhone;
    if (phone == null) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsapp() async {
    final phone = state.craftsmanPhone;
    if (phone == null) return;
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$digits');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openMap() async {
    final lat = state.craftsmanLatitude;
    final lng = state.craftsmanLongitude;
    if (lat == null || lng == null) return;
    final uri = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _confirmCancelJob(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Annuler cette demande ?'),
        content: Text(
          '${state.craftsmanFullName ?? "Le professionnel"} sera informé que vous annulez.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Retour'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Annuler la demande'),
          ),
        ],
      ),
    );
    if (confirmed == true) await onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation =
        state.craftsmanLatitude != null && state.craftsmanLongitude != null;
    final hasPhone = state.craftsmanPhone != null;
    final inProgress = state.status == ServiceRequestStatus.inProgress;
    final awaitingConfirmation =
        state.status == ServiceRequestStatus.awaitingClientConfirmation;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.green, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            awaitingConfirmation
                ? Icons.task_alt_rounded
                : Icons.check_circle_rounded,
            color: Colors.green,
            size: 56,
          ),
          const SizedBox(height: 16),
          Text(
            '${state.craftsmanFullName ?? category.label} a accepté votre demande',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            switch (state.status) {
              ServiceRequestStatus.inProgress => 'La mission est en cours.',
              ServiceRequestStatus.awaitingClientConfirmation =>
                'Le professionnel indique avoir terminé.',
              _ => 'Il est en route vers vous.',
            },
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
          if (!inProgress && !awaitingConfirmation) ...[
            const SizedBox(height: 8),
            Text(
              _distanceLabel(state),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: hasPhone ? _call : null,
                  icon: const Icon(Icons.call_rounded, size: 18),
                  label: const Text('Appeler'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: hasPhone ? _whatsapp : null,
                  icon: const Icon(Icons.chat_rounded, size: 18),
                  label: const Text('WhatsApp'),
                ),
              ),
            ],
          ),
          if (!awaitingConfirmation) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: hasLocation ? _openMap : null,
                icon: const Icon(Icons.map_rounded, size: 18),
                label: const Text('Voir sur la carte'),
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (awaitingConfirmation)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: state.isConfirming
                    ? null
                    : () => onConfirmCompletion(),
                icon: state.isConfirming
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text('Confirmer la fin de la mission'),
              ),
            )
          else
            TextButton(
              onPressed: state.isCancelling
                  ? null
                  : () => _confirmCancelJob(context),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: state.isCancelling
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Annuler'),
            ),
        ],
      ),
    );
  }
}

class _RatingCard extends StatefulWidget {
  const _RatingCard({
    required this.craftsmanName,
    required this.isSubmitting,
    required this.onSubmit,
    required this.onSkip,
  });

  final String craftsmanName;
  final bool isSubmitting;
  final Future<void> Function(int stars, String? comment) onSubmit;
  final VoidCallback onSkip;

  @override
  State<_RatingCard> createState() => _RatingCardState();
}

class _RatingCardState extends State<_RatingCard> {
  int _stars = 5;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 56),
        const SizedBox(height: 16),
        Text(
          'Mission terminée !',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Comment évaluez-vous ${widget.craftsmanName} ?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 16),
        StarRatingInput(
          value: _stars,
          onChanged: (value) => setState(() => _stars = value),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _commentController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Un commentaire (facultatif)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: widget.isSubmitting
                ? null
                : () => widget.onSubmit(
                    _stars,
                    _commentController.text.trim().isEmpty
                        ? null
                        : _commentController.text.trim(),
                  ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: widget.isSubmitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Envoyer',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: widget.isSubmitting ? null : widget.onSkip,
          child: const Text('Passer'),
        ),
      ],
    );
  }
}
