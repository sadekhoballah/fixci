import 'package:flutter/material.dart';

class RatingPerformanceCard extends StatelessWidget {
  const RatingPerformanceCard({
    super.key,
    required this.averageRating,
    required this.ratingsCount,
    required this.avgResponseSeconds,
  });

  final double? averageRating;
  final int ratingsCount;
  final int? avgResponseSeconds;

  String get _responseLabel {
    final seconds = avgResponseSeconds;
    if (seconds == null) return 'Pas encore de données';
    final minutes = (seconds / 60).round();
    return minutes < 1 ? '< 1 min' : '$minutes min';
  }

  @override
  Widget build(BuildContext context) {
    final rating = averageRating ?? 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ...List.generate(5, (index) {
                final filled = index < rating.round();
                return Icon(
                  filled ? Icons.star_rounded : Icons.star_border_rounded,
                  color: filled ? const Color(0xFFFFC107) : Colors.grey,
                  size: 22,
                );
              }),
              const SizedBox(width: 8),
              Text(
                rating > 0 ? rating.toStringAsFixed(1) : '—',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 4),
              Text(
                '($ratingsCount avis)',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.timer_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                'Réponse avg : $_responseLabel',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
