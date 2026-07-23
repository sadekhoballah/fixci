import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
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
            ServiceRequestStatus.assigned => _AssignedCard(
              category: category,
              state: state,
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
  const _AssignedCard({required this.category, required this.state});

  final ServiceCategory category;
  final ServiceRequestState state;

  Future<void> _call() async {
    final phone = state.craftsmanPhone;
    if (phone == null) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openMap() async {
    final lat = state.craftsmanLatitude;
    final lng = state.craftsmanLongitude;
    if (lat == null || lng == null) return;
    final uri = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation =
        state.craftsmanLatitude != null && state.craftsmanLongitude != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_rounded, color: Colors.green, size: 72),
        const SizedBox(height: 20),
        const Text(
          'Professionnel trouvé !',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          state.craftsmanFullName ?? category.label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          _distanceLabel(state),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: state.craftsmanPhone == null ? null : _call,
                icon: const Icon(Icons.call_rounded),
                label: const Text('Appeler'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: hasLocation ? _openMap : null,
                icon: const Icon(Icons.map_rounded),
                label: const Text('Voir sur la carte'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              "Retour à l'accueil",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
