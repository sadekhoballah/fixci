import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/subscription_tier.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../craftsman_home/screens/artisan_home_screen.dart';
import '../onboarding_controller.dart';
import '../onboarding_repository.dart';

enum _CheckoutStatus { requesting, pending, success, failed }

// The artisan pays via the Wave app outside FixCi (no card entry, no receipt
// upload), and this screen only finds out it's done by polling the backend,
// which itself only knows once Wave's webhook confirms it — so there's
// nothing here for the user to lie to. Until real Wave API access exists,
// the backend's StubWaveClient simulates that webhook after a short delay.
class WavePaymentCheckoutScreen extends ConsumerStatefulWidget {
  const WavePaymentCheckoutScreen({super.key, required this.tier});

  final SubscriptionTier tier;

  @override
  ConsumerState<WavePaymentCheckoutScreen> createState() =>
      _WavePaymentCheckoutScreenState();
}

class _WavePaymentCheckoutScreenState
    extends ConsumerState<WavePaymentCheckoutScreen> {
  _CheckoutStatus _status = _CheckoutStatus.requesting;
  String? _reference;
  String? _errorMessage;
  Timer? _pollTimer;

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
    final phone = ref.read(onboardingControllerProvider).phone;
    try {
      final reference = await ref
          .read(onboardingRepositoryProvider)
          .subscribeToTier(phone, widget.tier);
      if (!mounted) return;
      setState(() {
        _reference = reference;
        _status = _CheckoutStatus.pending;
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
        _errorMessage = "Impossible de démarrer le paiement.";
      });
    }
  }

  Future<void> _checkStatus(String reference) async {
    final String status;
    try {
      status = await ref
          .read(onboardingRepositoryProvider)
          .getPaymentStatus(reference);
    } catch (_) {
      return; // transient network hiccup — the next tick will retry
    }
    if (!mounted || status == 'pending') return;

    _pollTimer?.cancel();
    if (status == 'success') {
      await ref.read(onboardingControllerProvider.notifier).confirmActiveTier();
      if (!mounted) return;
      setState(() => _status = _CheckoutStatus.success);
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ArtisanHomeScreen()),
        (route) => false,
      );
    } else {
      setState(() {
        _status = _CheckoutStatus.failed;
        _errorMessage = 'Le paiement a échoué.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Paiement Wave')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Formule ${widget.tier.label}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.tier.priceCfa} CFA / mois',
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
                  "Ouvrez l'application Wave et envoyez le montant "
                  'ci-dessus. Votre abonnement sera activé automatiquement '
                  'dès que le paiement est confirmé.'
                  '${_reference != null ? '\n\nRéférence : $_reference' : ''}',
                ),
              ),
              const Spacer(),
              _StatusPanel(status: _status, errorMessage: _errorMessage),
              const SizedBox(height: 16),
              if (_status == _CheckoutStatus.failed)
                PrimaryButton(label: 'Réessayer', onPressed: _startPayment),
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
                  ? 'Préparation du paiement...'
                  : 'En attente de confirmation Wave...',
            ),
          ],
        );
      case _CheckoutStatus.success:
        return const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 12),
            Text('Paiement confirmé, activation en cours...'),
          ],
        );
      case _CheckoutStatus.failed:
        return Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(
              child: Text(errorMessage ?? 'Une erreur est survenue.'),
            ),
          ],
        );
    }
  }
}
