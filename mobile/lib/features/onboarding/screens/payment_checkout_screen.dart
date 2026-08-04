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

// The artisan pays via the Wave/Whish app outside FixCi (no card entry, no
// receipt upload), and this screen only finds out it's done by polling the
// backend, which itself only knows once the provider's webhook confirms it —
// so there's nothing here for the user to lie to. Until real provider API
// access exists, the backend's stub clients simulate that webhook after a
// short delay.
class PaymentCheckoutScreen extends ConsumerStatefulWidget {
  const PaymentCheckoutScreen({
    super.key,
    required this.tier,
    required this.countryCode,
    this.isChangingPlan = false,
  });

  final SubscriptionTier tier;
  // Picks both the provider (Wave vs Whish) and the price/currency shown —
  // see PaymentProvider.forCountry and SubscriptionTier.priceLabel.
  final String countryCode;
  // True when this checkout was reached from the Account tab to change an
  // already-active plan — on success this pops back to the shell (refreshing
  // the craftsman's profile) instead of resetting the nav stack to it, since
  // there's no onboarding stack to clear in that case.
  final bool isChangingPlan;

  @override
  ConsumerState<PaymentCheckoutScreen> createState() =>
      _PaymentCheckoutScreenState();
}

// Polling stops (with an error shown) after this many ticks so a lost
// payment record or a charge that's abandoned mid-flow doesn't leave the
// user staring at "waiting for confirmation" forever.
const _maxPollAttempts = 30; // ~60s at the 2s poll interval below

class _PaymentCheckoutScreenState
    extends ConsumerState<PaymentCheckoutScreen> {
  _CheckoutStatus _status = _CheckoutStatus.requesting;
  String? _reference;
  String? _errorMessage;
  Timer? _pollTimer;
  int _pollAttempts = 0;
  bool _isChecking = false;

  PaymentProvider get _provider =>
      PaymentProvider.forCountry(widget.countryCode);

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
    final title = switch (_provider) {
      PaymentProvider.wave => l10n.wavePaymentTitle,
      PaymentProvider.whish => l10n.whishPaymentTitle,
    };
    final instructions = switch (_provider) {
      PaymentProvider.wave => l10n.wavePaymentInstructions,
      PaymentProvider.whish => l10n.whishPaymentInstructions,
    };
    final referenceLine = reference == null
        ? null
        : switch (_provider) {
            PaymentProvider.wave => l10n.wavePaymentReference(reference),
            PaymentProvider.whish => l10n.whishPaymentReference(reference),
          };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.tierPlanLabel(widget.tier.localizedLabel(l10n)),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.tier.priceLabel(l10n, widget.countryCode),
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
                  '$instructions'
                  '${referenceLine != null ? '\n\n$referenceLine' : ''}',
                ),
              ),
              const Spacer(),
              _StatusPanel(
                status: _status,
                errorMessage: _errorMessage,
                provider: _provider,
              ),
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
  const _StatusPanel({
    required this.status,
    required this.errorMessage,
    required this.provider,
  });

  final _CheckoutStatus status;
  final String? errorMessage;
  final PaymentProvider provider;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (status) {
      case _CheckoutStatus.requesting:
      case _CheckoutStatus.pending:
        final awaitingConfirmationStatus = switch (provider) {
          PaymentProvider.wave => l10n.awaitingWaveConfirmationStatus,
          PaymentProvider.whish => l10n.awaitingWhishConfirmationStatus,
        };
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
                  : awaitingConfirmationStatus,
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
