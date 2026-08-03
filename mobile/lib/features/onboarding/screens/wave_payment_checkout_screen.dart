import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/subscription_tier.dart';
import '../../../core/network/api_client.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../craftsman_home/craftsman_home_controller.dart';
import '../../craftsman_home/screens/artisan_shell_screen.dart';
import '../onboarding_controller.dart';
import '../onboarding_repository.dart';

enum _CheckoutStatus { requesting, pending, success, failed }

// The artisan pays via the Wave app outside FixCi (no card entry, no receipt
// upload), and this screen only finds out it's done by polling the backend,
// which itself only knows once Wave's webhook confirms it — so there's
// nothing here for the user to lie to. Until real Wave API access exists,
// the backend's StubWaveClient simulates that webhook after a short delay.
class WavePaymentCheckoutScreen extends ConsumerStatefulWidget {
  const WavePaymentCheckoutScreen({
    super.key,
    required this.tier,
    this.isChangingPlan = false,
  });

  final SubscriptionTier tier;
  // True when this checkout was reached from the Account tab to change an
  // already-active plan — on success this pops back to the shell (refreshing
  // the craftsman's profile) instead of resetting the nav stack to it, since
  // there's no onboarding stack to clear in that case.
  final bool isChangingPlan;

  @override
  ConsumerState<WavePaymentCheckoutScreen> createState() =>
      _WavePaymentCheckoutScreenState();
}

// Polling stops (with an error shown) after this many ticks so a lost
// payment record or a Wave charge that's abandoned mid-flow doesn't leave
// the user staring at "waiting for confirmation" forever.
const _maxPollAttempts = 30; // ~60s at the 2s poll interval below

class _WavePaymentCheckoutScreenState
    extends ConsumerState<WavePaymentCheckoutScreen> {
  _CheckoutStatus _status = _CheckoutStatus.requesting;
  String? _reference;
  String? _errorMessage;
  Timer? _pollTimer;
  int _pollAttempts = 0;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _startPayment();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _startPayment() async {
    setState(() {
      _status = _CheckoutStatus.requesting;
      _errorMessage = null;
    });
    try {
      final reference = await ref
          .read(onboardingRepositoryProvider)
          .subscribeToTier(widget.tier);
      if (!mounted) return;
      setState(() {
        _reference = reference;
        _status = _CheckoutStatus.pending;
        _pollAttempts = 0;
      });
      _pollTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _checkStatus(reference),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _CheckoutStatus.failed;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _status = _CheckoutStatus.failed;
        _errorMessage = AppLocalizations.of(context)!.paymentStartError;
      });
    }
  }

  Future<void> _checkStatus(String reference) async {
    // A slow response can still be in flight when the next tick fires —
    // skip this tick rather than let two checks race each other.
    if (_isChecking) return;
    _isChecking = true;
    try {
      _pollAttempts++;
      if (_pollAttempts > _maxPollAttempts) {
        _pollTimer?.cancel();
        if (!mounted) return;
        setState(() {
          _status = _CheckoutStatus.failed;
          _errorMessage =
              AppLocalizations.of(context)!.paymentConfirmationDelayError;
        });
        return;
      }

      final String status;
      try {
        status = await ref
            .read(onboardingRepositoryProvider)
            .getPaymentStatus(reference);
      } on ApiException catch (e) {
        // A missing/rejected reference is permanent — no amount of
        // retrying will resolve it. Anything else (timeout, 5xx) is
        // treated as transient and retried on the next tick.
        if (e.statusCode == 404 || e.statusCode == 401) {
          _pollTimer?.cancel();
          if (!mounted) return;
          setState(() {
            _status = _CheckoutStatus.failed;
            _errorMessage = e.message;
          });
        }
        return;
      } catch (_) {
        return; // transient network hiccup — the next tick will retry
      }
      if (!mounted || status == 'pending') return;

      _pollTimer?.cancel();
      if (status == 'success') {
        await ref
            .read(onboardingControllerProvider.notifier)
            .confirmActiveTier();
        if (!mounted) return;
        setState(() => _status = _CheckoutStatus.success);
        await Future<void>.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        if (widget.isChangingPlan) {
          await ref.read(craftsmanHomeControllerProvider.notifier).refresh();
          if (!mounted) return;
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const ArtisanShellScreen()),
            (route) => false,
          );
        }
      } else {
        setState(() {
          _status = _CheckoutStatus.failed;
          _errorMessage = AppLocalizations.of(context)!.paymentFailedError;
        });
      }
    } finally {
      _isChecking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final reference = _reference;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.wavePaymentTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.tierPlanLabel(widget.tier.label),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.priceCfaPerMonth(widget.tier.priceCfa),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${l10n.wavePaymentInstructions}'
                  '${reference != null ? '\n\n${l10n.wavePaymentReference(reference)}' : ''}',
                ),
              ),
              const Spacer(),
              _StatusPanel(status: _status, errorMessage: _errorMessage),
              const SizedBox(height: 16),
              if (_status == _CheckoutStatus.failed)
                PrimaryButton(
                  label: l10n.retryButton,
                  onPressed: _startPayment,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.status, required this.errorMessage});

  final _CheckoutStatus status;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (status) {
      case _CheckoutStatus.requesting:
      case _CheckoutStatus.pending:
        return Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 12),
            Text(
              status == _CheckoutStatus.requesting
                  ? l10n.preparingPaymentStatus
                  : l10n.awaitingWaveConfirmationStatus,
            ),
          ],
        );
      case _CheckoutStatus.success:
        return Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 12),
            Text(l10n.paymentConfirmedStatus),
          ],
        );
      case _CheckoutStatus.failed:
        return Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(
              child: Text(errorMessage ?? l10n.genericErrorMessage),
            ),
          ],
        );
    }
  }
}
