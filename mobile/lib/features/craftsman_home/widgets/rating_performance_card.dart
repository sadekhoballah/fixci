import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

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

  String _responseLabel(AppLocalizations l10n) {
    final seconds = avgResponseSeconds;
    if (seconds == null) return l10n.noDataYetLabel;
    final minutes = (seconds / 60).round();
    return minutes < 1
        ? l10n.lessThanOneMinuteLabel
        : l10n.minutesShortLabel(minutes);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                l10n.ratingsCountLabel(ratingsCount),
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
                l10n.avgResponseLabel(_responseLabel(l10n)),
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
