import 'package:flutter/material.dart';

class AvailabilityToggleCard extends StatelessWidget {
  const AvailabilityToggleCard({
    super.key,
    required this.isAvailable,
    required this.isUpdating,
    required this.onChanged,
  });

  final bool isAvailable;
  final bool isUpdating;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final Color background = isAvailable
        ? const Color(0xFF1B8A3B)
        : const Color(0xFF5C5C5C);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        boxShadow: isAvailable
            ? [
                BoxShadow(
                  color: const Color(0xFF1B8A3B).withValues(alpha: 0.45),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Icon(
            isAvailable ? Icons.bolt_rounded : Icons.power_settings_new,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAvailable ? 'En service / Dispo' : 'Hors service',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isAvailable
                      ? 'Vous recevez les nouvelles demandes'
                      : "Vous n'apparaissez pas dans les recherches",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (isUpdating)
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          else
            Switch(
              value: isAvailable,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: Colors.white.withValues(alpha: 0.4),
            ),
        ],
      ),
    );
  }
}
