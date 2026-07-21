import 'package:flutter/material.dart';

const _tips = [
  'Astuce : Ajouter 3 photos de vos réalisations augmente la confiance des clients de 40%.',
  'Astuce : Un profil complet avec vos années d\'expérience attire plus de demandes.',
  'Astuce : Répondez vite aux demandes — les clients choisissent souvent le premier artisan disponible.',
];

class QuickTipCard extends StatelessWidget {
  const QuickTipCard({super.key});

  @override
  Widget build(BuildContext context) {
    final tip = _tips[DateTime.now().day % _tips.length];
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(tip, style: const TextStyle(fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
