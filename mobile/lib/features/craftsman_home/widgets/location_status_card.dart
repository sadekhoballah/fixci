import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

// Compact GPS status card: shows why location matters, and a single button
// whose action follows the official Android/iOS flow — request the app
// permission if that's missing, otherwise deep-link to the relevant system
// settings screen. Never anything that tries to flip location on directly;
// no app is allowed to do that, on either platform.
class LocationStatusCard extends StatelessWidget {
  const LocationStatusCard({
    super.key,
    required this.serviceEnabled,
    required this.permission,
    required this.onActivate,
  });

  final bool serviceEnabled;
  final LocationPermission permission;
  final VoidCallback onActivate;

  bool get _hasAccess =>
      serviceEnabled &&
      (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final active = _hasAccess;
    final activeColor = const Color(0xFF1B8A3B);
    final inactiveColor = const Color(0xFFC62828);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            active ? Icons.location_on_rounded : Icons.location_off_rounded,
            color: active ? activeColor : inactiveColor,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active ? 'Localisation activée' : 'Localisation désactivée',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  active
                      ? 'Les clients à proximité peuvent vous trouver.'
                      : 'Activez la localisation pour recevoir des demandes.',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!active)
            ElevatedButton(
              onPressed: onActivate,
              style: ElevatedButton.styleFrom(
                backgroundColor: inactiveColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text(
                'Activer',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: activeColor,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Active',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
