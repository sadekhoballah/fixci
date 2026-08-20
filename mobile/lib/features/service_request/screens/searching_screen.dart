import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/service_category.dart';
import '../../../l10n/app_localizations.dart';
import '../../safety/widgets/report_block_menu.dart';
import '../service_request_controller.dart';
import '../service_request_repository.dart' show ActiveRequest;
import '../service_request_state.dart';
import '../widgets/star_rating_input.dart';

class SearchingScreen extends ConsumerStatefulWidget {
  const SearchingScreen({super.key, required this.category, this.resumeFrom});

  final ServiceCategory category;
  // Set when opened from the client Home screen's "mission en cours" banner
  // rather than from a fresh submit() — see initState below for why this
  // can't just be applied by the caller before pushing this route.
  final ActiveRequest? resumeFrom;

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
    // Deliberately not done by the banner's onTap before pushing this route:
    // serviceRequestControllerProvider is autoDispose, and a bare ref.read()
    // with nothing watching it yet doesn't keep it alive — Riverpod disposes
    // it again (silently reverting to a blank state) before this screen ever
    // gets to build() and actually watch it. Calling it here, right before
    // the first build() runs in the very same frame, closes that gap.
    final resumeFrom = widget.resumeFrom;
    if (resumeFrom != null) {
      ref
          .read(serviceRequestControllerProvider.notifier)
          .resumeActiveRequest(resumeFrom);
    }
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
    final l10n = AppLocalizations.of(context)!;
    final categoryLabel = category.localizedLabel(l10n);

    return Scaffold(
      appBar: AppBar(title: Text(categoryLabel)),
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
              craftsmanName: state.craftsmanFullName ?? categoryLabel,
              isSubmitting: state.isSubmittingRating,
              onSubmit: (stars, comment) =>
                  notifier.submitRating(stars: stars, comment: comment),
              onSkip: notifier.skipRating,
            ),
            ServiceRequestStatus.noCraftsmanAvailable => _Outcome(
              icon: Icons.search_off_rounded,
              iconColor: Colors.grey,
              title: l10n.noCraftsmanTitle,
              message: l10n.noCraftsmanMessage(categoryLabel.toLowerCase()),
              primaryLabel: l10n.retryButton,
              onPrimary: () => ref
                  .read(serviceRequestControllerProvider.notifier)
                  .retry(category),
              secondaryLabel: l10n.backToHomeButton,
              onSecondary: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
            ),
            _ => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _SearchRadar(),
                const SizedBox(height: 24),
                Text(
                  l10n.searchingForMessage(categoryLabel.toLowerCase()),
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
                        : Text(l10n.cancelSearchButton),
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
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.cancelRequestDialogTitle),
      content: Text(l10n.cancelRequestDialogContent),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.backButton),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.cancelRequestButton),
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
String _distanceLabel(ServiceRequestState state, AppLocalizations l10n) {
  if (state.craftsmanLatitude == null ||
      state.craftsmanLongitude == null ||
      state.myLatitude == null ||
      state.myLongitude == null) {
    return l10n.enRouteMessage;
  }
  final meters = Geolocator.distanceBetween(
    state.myLatitude!,
    state.myLongitude!,
    state.craftsmanLatitude!,
    state.craftsmanLongitude!,
  );
  final minutes = (meters / 500).round().clamp(1, 999);
  final km = (meters / 1000).toStringAsFixed(meters >= 1000 ? 1 : 2);
  return l10n.distanceEta(km, minutes);
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
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.cancelJobDialogTitle),
        content: Text(
          l10n.cancelJobDialogContent(
            state.craftsmanFullName ?? l10n.defaultCraftsmanName,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.backButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.cancelRequestButton),
          ),
        ],
      ),
    );
    if (confirmed == true) await onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
            l10n.craftsmanAcceptedMessage(
              state.craftsmanFullName ?? category.localizedLabel(l10n),
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            switch (state.status) {
              ServiceRequestStatus.inProgress => l10n.jobInProgressDetail,
              ServiceRequestStatus.awaitingClientConfirmation =>
                l10n.craftsmanMarkedDoneMessage,
              _ => l10n.craftsmanEnRouteMessage,
            },
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
          if (!inProgress && !awaitingConfirmation) ...[
            const SizedBox(height: 8),
            Text(
              _distanceLabel(state, l10n),
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
                  label: Text(l10n.callButton),
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
              ReportBlockMenu(
                targetUserId: state.craftsmanId,
                contextType: 'service_request',
                contextId: state.requestId,
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
                label: Text(l10n.viewOnMapButton),
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
                label: Text(l10n.confirmJobCompletionButton),
              ),
            )
          // Once the craftsman has started the job, cancelByClient
          // (matching.service.ts) intentionally rejects the client's cancel —
          // the craftsman owns the job's transitions from here on, not the
          // client — so showing this button just led to a silent no-op
          // (backend 409, no error UI wired for it on this screen). Call/
          // WhatsApp above are the actual way to reach the craftsman now.
          else if (!inProgress)
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
                  : Text(l10n.cancelButton),
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
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 56),
        const SizedBox(height: 16),
        Text(
          l10n.jobCompletedTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.rateCraftsmanQuestion(widget.craftsmanName),
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
          decoration: InputDecoration(
            hintText: l10n.commentHint,
            border: const OutlineInputBorder(),
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
                : Text(
                    l10n.sendButton,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: widget.isSubmitting ? null : widget.onSkip,
          child: Text(l10n.skipButton),
        ),
      ],
    );
  }
}

// Purely decorative: a weather-radar-style sweep plus a countdown display.
// The countdown is cosmetic only — it mirrors the backend's worst-case
// matching duration (matching.constants.ts: 6 rounds x ACCEPT_TIMEOUT_MS
// [18s] + WAKEUP_ACCEPT_TIMEOUT_MS [90s] = 198s) so it lands near zero right
// as a real timeout would occur, but it never triggers navigation itself —
// the screen still transitions purely from serviceRequestControllerProvider
// state changes (see the `switch` in _SearchingScreenState.build), so a match
// found before or after 00:00 behaves identically.
class _SearchRadar extends StatefulWidget {
  const _SearchRadar();

  @override
  State<_SearchRadar> createState() => _SearchRadarState();
}

class _SearchRadarState extends State<_SearchRadar>
    with SingleTickerProviderStateMixin {
  static const _worstCaseSearchDuration = Duration(seconds: 198);

  late final AnimationController _sweepController;
  final ValueNotifier<Duration> _remaining = ValueNotifier(
    _worstCaseSearchDuration,
  );
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final next = _remaining.value - const Duration(seconds: 1);
      _remaining.value = next.isNegative ? Duration.zero : next;
      if (_remaining.value == Duration.zero) _countdownTimer?.cancel();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _sweepController.dispose();
    _remaining.dispose();
    super.dispose();
  }

  static String _format(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 140,
          height: 140,
          child: AnimatedBuilder(
            animation: _sweepController,
            builder: (context, _) => CustomPaint(
              painter: _RadarPainter(_sweepController.value * 2 * math.pi),
            ),
          ),
        ),
        const SizedBox(height: 14),
        ValueListenableBuilder<Duration>(
          valueListenable: _remaining,
          builder: (context, value, _) => Text(
            _format(value),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.green,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter(this.angle);

  // Current sweep angle in radians, measured clockwise from the top.
  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()..color = Colors.green.withValues(alpha: 0.06),
    );

    final ringPaint = Paint()
      ..color = Colors.green.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final fraction in [0.33, 0.66, 1.0]) {
      canvas.drawCircle(center, radius * fraction, ringPaint);
    }

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.green.withValues(alpha: 0.0),
          Colors.green.withValues(alpha: 0.5),
        ],
        transform: GradientRotation(angle - math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, sweepPaint);

    final lineEnd = Offset(
      center.dx + radius * math.cos(angle - math.pi / 2),
      center.dy + radius * math.sin(angle - math.pi / 2),
    );
    canvas.drawLine(
      center,
      lineEnd,
      Paint()
        ..color = Colors.green
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(center, 3, Paint()..color = Colors.green);
    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..color = Colors.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.angle != angle;
}
