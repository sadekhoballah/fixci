import 'package:flutter/material.dart';
import '../../../core/models/subscription_tier.dart';
import '../../../l10n/app_localizations.dart';

// The compact top-of-screen identity strip: photo, name, a tappable
// online/offline pill (this doubles as the availability toggle — there's no
// separate switch elsewhere), the subscription tier, and the rating as
// stars only, top-right, per the design brief (no large numeric rating).
class CraftsmanHeader extends StatelessWidget {
  const CraftsmanHeader({
    super.key,
    required this.fullName,
    required this.isAvailable,
    required this.isToggling,
    required this.tier,
    required this.averageRating,
    required this.idVerified,
    required this.onToggleAvailability,
  });

  final String? fullName;
  final bool isAvailable;
  final bool isToggling;
  final SubscriptionTier tier;
  final double? averageRating;
  final bool idVerified;
  final ValueChanged<bool> onToggleAvailability;

  String get _initials {
    final name = fullName?.trim();
    if (name == null || name.isEmpty) return '?';
    final parts = name.split(RegExp(r'\s+'));
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final last = parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  (Color, Color) _tierBadgeColors() => switch (tier) {
    SubscriptionTier.gold => (const Color(0xFFFFF3CD), const Color(0xFF7A5B00)),
    SubscriptionTier.silver => (
      const Color(0xFFEDEDED),
      const Color(0xFF4A4A4A),
    ),
    SubscriptionTier.bronze => (
      const Color(0xFFF3E0D2),
      const Color(0xFF5A3A16),
    ),
    SubscriptionTier.free => (const Color(0xFFF0F0F0), const Color(0xFF757575)),
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (badgeBg, badgeFg) = _tierBadgeColors();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: colorScheme.primaryContainer,
          child: Text(
            _initials,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fullName ?? AppLocalizations.of(context)!.defaultCraftsmanDisplayName,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _AvailabilityPill(
                    isAvailable: isAvailable,
                    isToggling: isToggling,
                    onTap: () => onToggleAvailability(!isAvailable),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      tier.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: badgeFg,
                      ),
                    ),
                  ),
                  _VerifiedPill(idVerified: idVerified),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _RatingStars(averageRating: averageRating),
      ],
    );
  }
}

class _AvailabilityPill extends StatelessWidget {
  const _AvailabilityPill({
    required this.isAvailable,
    required this.isToggling,
    required this.onTap,
  });

  final bool isAvailable;
  final bool isToggling;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isAvailable ? const Color(0xFF1B8A3B) : const Color(0xFF8A8A8A);
    return InkWell(
      onTap: isToggling ? null : onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isToggling)
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
              )
            else
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            const SizedBox(width: 6),
            Text(
              isAvailable
                  ? AppLocalizations.of(context)!.onlineStatus
                  : AppLocalizations.of(context)!.offlineStatus,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerifiedPill extends StatelessWidget {
  const _VerifiedPill({required this.idVerified});

  final bool idVerified;

  @override
  Widget build(BuildContext context) {
    final color = idVerified ? const Color(0xFF1B8A3B) : const Color(0xFFC62828);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            idVerified ? Icons.verified_rounded : Icons.error_outline_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            idVerified
                ? AppLocalizations.of(context)!.verifiedStatus
                : AppLocalizations.of(context)!.notVerifiedStatus,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _RatingStars extends StatelessWidget {
  const _RatingStars({required this.averageRating});

  final double? averageRating;

  @override
  Widget build(BuildContext context) {
    final rating = averageRating ?? 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final filled = index < rating.round();
        return Icon(
          filled ? Icons.star_rounded : Icons.star_border_rounded,
          color: filled ? const Color(0xFFFFC107) : Colors.grey,
          size: 16,
        );
      }),
    );
  }
}
