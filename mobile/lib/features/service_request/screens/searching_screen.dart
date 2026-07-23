import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/service_category.dart';
import '../service_request_controller.dart';
import '../service_request_state.dart';

class SearchingScreen extends ConsumerWidget {
  const SearchingScreen({super.key, required this.category});

  final ServiceCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(serviceRequestControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(category.label)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: switch (state.status) {
            ServiceRequestStatus.assigned => _Outcome(
              icon: Icons.check_circle_rounded,
              iconColor: Colors.green,
              title: 'Professionnel trouvé !',
              message:
                  'Un ${category.label.toLowerCase()} a accepté votre demande et est en route.',
              primaryLabel: "Retour à l'accueil",
              onPrimary: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
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
              ],
            ),
          },
        ),
      ),
    );
  }
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
