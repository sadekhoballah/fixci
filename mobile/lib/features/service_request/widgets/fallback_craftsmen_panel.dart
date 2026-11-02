import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/service_category.dart';
import '../../../l10n/app_localizations.dart';
import '../service_request_repository.dart';

const _whatsappGreen = Color(0xFF25D366);

// Shown in place of the bare "aucun artisan disponible" outcome once the 75s
// matching window closes with nobody accepting: the nearest craftsmen of the
// trade, with their rating, to reach directly by WhatsApp or a phone call.
// Falls back to that plain outcome if the list can't be loaded or is empty.
// Used both inline on SearchingScreen and standalone (FallbackCraftsmenScreen,
// opened from the "nobody accepted" push).
class FallbackCraftsmenPanel extends ConsumerStatefulWidget {
  const FallbackCraftsmenPanel({
    super.key,
    required this.requestId,
    required this.onBackHome,
    this.category,
    this.onRetry,
  });

  final String requestId;
  // Known on SearchingScreen; otherwise taken from the list itself.
  final ServiceCategory? category;
  // Null where there's no request to re-run (the standalone screen).
  final VoidCallback? onRetry;
  final VoidCallback onBackHome;

  @override
  ConsumerState<FallbackCraftsmenPanel> createState() =>
      _FallbackCraftsmenPanelState();
}

class _FallbackCraftsmenPanelState
    extends ConsumerState<FallbackCraftsmenPanel> {
  late final Future<FallbackList> _list = ref
      .read(serviceRequestRepositoryProvider)
      .getFallbackCraftsmen(widget.requestId);

  void _recordContact(String craftsmanId, ContactChannel channel) {
    // Best-effort: the call / WhatsApp opens regardless.
    ref
        .read(serviceRequestRepositoryProvider)
        .recordContact(
          widget.requestId,
          craftsmanId: craftsmanId,
          channel: channel,
        )
        .catchError((_) {});
  }

  Future<void> _call(FallbackCraftsman craftsman) async {
    _recordContact(craftsman.id, ContactChannel.call);
    final uri = Uri(scheme: 'tel', path: craftsman.phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsapp(FallbackCraftsman craftsman, FallbackList list) async {
    _recordContact(craftsman.id, ContactChannel.whatsapp);
    final l10n = AppLocalizations.of(context)!;
    final trade = list.serviceCategory.localizedLabel(l10n);
    final district = list.clientDistrictName;
    final message = district == null
        ? l10n.fallbackWhatsappMessageNoDistrict(trade)
        : l10n.fallbackWhatsappMessage(trade, district);
    final digits = craftsman.phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse(
      'https://wa.me/$digits?text=${Uri.encodeComponent(message)}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<FallbackList>(
      future: _list,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(l10n.fallbackLoadingMessage, textAlign: TextAlign.center),
            ],
          );
        }
        final list = snapshot.data;
        if (list == null || list.craftsmen.isEmpty) {
          return _NobodyAvailable(
            category: widget.category ?? list?.serviceCategory,
            onRetry: widget.onRetry,
            onBackHome: widget.onBackHome,
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.support_agent_rounded,
              size: 56,
              color: _whatsappGreen,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.fallbackTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.fallbackSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 20),
            for (final craftsman in list.craftsmen) ...[
              _CraftsmanCard(
                craftsman: craftsman,
                onWhatsapp: () => _whatsapp(craftsman, list),
                onCall: () => _call(craftsman),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            if (widget.onRetry != null)
              OutlinedButton.icon(
                onPressed: widget.onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.fallbackRetryButton),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            TextButton(
              onPressed: widget.onBackHome,
              child: Text(l10n.backToHomeButton),
            ),
          ],
        );
      },
    );
  }
}

class _CraftsmanCard extends StatelessWidget {
  const _CraftsmanCard({
    required this.craftsman,
    required this.onWhatsapp,
    required this.onCall,
  });

  final FallbackCraftsman craftsman;
  final VoidCallback onWhatsapp;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final name = craftsman.fullName?.trim();
    final displayName = (name == null || name.isEmpty) ? '—' : name;
    final km = (craftsman.distanceMeters / 1000).toStringAsFixed(1);
    final rating = craftsman.averageRating;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
                child: Text(
                  displayName.characters.first.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _Fact(
                          icon: Icons.place_outlined,
                          label: l10n.fallbackDistanceKm(km),
                        ),
                        if (rating != null && craftsman.ratingsCount > 0)
                          _Fact(
                            icon: Icons.star_rounded,
                            iconColor: Colors.amber.shade700,
                            label: l10n.fallbackRating(
                              rating.toStringAsFixed(1),
                              craftsman.ratingsCount,
                            ),
                          )
                        else
                          _Fact(
                            icon: Icons.fiber_new_outlined,
                            label: l10n.fallbackNewCraftsman,
                          ),
                        if (craftsman.completedJobsCount > 0)
                          _Fact(
                            icon: Icons.task_alt_rounded,
                            label: l10n.completedMissionsCount(
                              craftsman.completedJobsCount,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (craftsman.isOnline) ...[
                const SizedBox(width: 8),
                _OnlineBadge(label: l10n.fallbackOnlineBadge),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onWhatsapp,
                  icon: const Icon(Icons.chat_rounded, size: 18),
                  label: const Text('WhatsApp'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _whatsappGreen,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCall,
                  icon: const Icon(Icons.phone_rounded, size: 18),
                  label: Text(l10n.fallbackCallButton),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, this.iconColor});

  final IconData icon;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: iconColor ?? muted),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 13, color: muted)),
      ],
    );
  }
}

class _OnlineBadge extends StatelessWidget {
  const _OnlineBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2E9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.circle, size: 8, color: Color(0xFF1B8A3B)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1B8A3B),
            ),
          ),
        ],
      ),
    );
  }
}

// The pre-existing "nobody available" outcome, for when there's no list to
// show (none within range, or it couldn't be loaded).
class _NobodyAvailable extends StatelessWidget {
  const _NobodyAvailable({
    required this.category,
    required this.onRetry,
    required this.onBackHome,
  });

  final ServiceCategory? category;
  final VoidCallback? onRetry;
  final VoidCallback onBackHome;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final trade = category?.localizedLabel(l10n).toLowerCase();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.search_off_rounded, color: Colors.grey, size: 72),
        const SizedBox(height: 20),
        Text(
          l10n.noCraftsmanTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        if (trade != null) ...[
          const SizedBox(height: 8),
          Text(
            l10n.noCraftsmanMessage(trade),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
          ),
        ],
        const SizedBox(height: 28),
        if (onRetry != null)
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              l10n.retryButton,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        const SizedBox(height: 12),
        TextButton(onPressed: onBackHome, child: Text(l10n.backToHomeButton)),
      ],
    );
  }
}
