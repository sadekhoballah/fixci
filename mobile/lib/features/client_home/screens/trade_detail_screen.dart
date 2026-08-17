import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/service_category.dart';
import '../../../l10n/app_localizations.dart';
import '../../service_request/service_request_controller.dart';
import '../../service_request/service_request_state.dart';
import '../../service_request/screens/searching_screen.dart';

class TradeDetailScreen extends ConsumerStatefulWidget {
  const TradeDetailScreen({super.key, required this.category});

  final ServiceCategory category;

  @override
  ConsumerState<TradeDetailScreen> createState() => _TradeDetailScreenState();
}

class _TradeDetailScreenState extends ConsumerState<TradeDetailScreen> {
  // Taxi/camion only (see ServiceCategory.requiresDestination) — plain text
  // rather than a map pin: there's no map integration anywhere in the app
  // yet (google_maps_flutter is an unused dependency, no API key
  // configured), so this is the fast, dependency-free first cut. The
  // craftsman sees these on the incoming-request card before accepting.
  final _destinationController = TextEditingController();
  final _loadDetailsController = TextEditingController();

  ServiceCategory get category => widget.category;

  @override
  void initState() {
    super.initState();
    // Trigger the OS location prompt as soon as the client is looking at a
    // trade, well before they tap "Demander maintenant" — see
    // ServiceRequestController.prewarmLocation.
    Future.microtask(
      () => ref.read(serviceRequestControllerProvider.notifier).prewarmLocation(),
    );
    // Rebuilds so the submit button's enabled state tracks the destination
    // field for taxi/camion (see the button's onPressed below).
    _destinationController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _loadDetailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(serviceRequestControllerProvider, (previous, next) {
      if (next.status == ServiceRequestStatus.searching &&
          previous?.status != ServiceRequestStatus.searching) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SearchingScreen(category: category),
          ),
        );
      }
      if (next.status == ServiceRequestStatus.error &&
          next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!)),
        );
      }
    });
    final requestState = ref.watch(serviceRequestControllerProvider);
    final l10n = AppLocalizations.of(context)!;
    final isBusy =
        requestState.status == ServiceRequestStatus.locating ||
        requestState.status == ServiceRequestStatus.submitting;
    final destinationMissing =
        category.requiresDestination && _destinationController.text.trim().isEmpty;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/categories/${category.wireValue}.jpg',
                    fit: BoxFit.cover,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black87],
                        stops: [0.5, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          category.icon,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        category.localizedLabel(l10n),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    category.localizedDescription(l10n),
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  if (category.requiresDestination) ...[
                    const SizedBox(height: 20),
                    TextField(
                      controller: _destinationController,
                      decoration: InputDecoration(
                        labelText: l10n.destinationLabel,
                        hintText: l10n.destinationHint,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _loadDetailsController,
                      decoration: InputDecoration(
                        labelText: l10n.loadDetailsLabel,
                        hintText: l10n.loadDetailsHint,
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(20),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: isBusy || destinationMissing
                ? null
                : () => ref
                      .read(serviceRequestControllerProvider.notifier)
                      .submit(
                        category,
                        destinationAddress: _destinationController.text.trim(),
                        loadDetails: _loadDetailsController.text.trim(),
                      ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: isBusy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    l10n.requestNowButton,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
