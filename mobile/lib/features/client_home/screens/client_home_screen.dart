import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/service_category.dart';
import '../../../l10n/app_localizations.dart';
import '../../service_request/screens/searching_screen.dart';
import '../../service_request/service_request_repository.dart';
import '../../service_request/service_request_state.dart';
import 'trade_detail_screen.dart';

class ClientHomeScreen extends ConsumerWidget {
  const ClientHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeRequest = ref.watch(clientActiveRequestNoticeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.clientHomeTitle),
      ),
      body: SafeArea(
        child: Column(
          children: [
            activeRequest.when(
              data: (active) => active == null
                  ? const SizedBox.shrink()
                  : _ActiveRequestBanner(active: active),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.05,
                ),
                itemCount: ServiceCategory.values.length,
                itemBuilder: (context, index) {
                  final category = ServiceCategory.values[index];
                  return _CategoryCard(category: category);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// The fix for a client who left the live-tracking screen (back button, app
// restart, a push-notification tap that only lands on the shell) while a
// request was still active — without this, that request just sits on the
// server with no way back into the app to see or act on it, most critically
// when it's awaiting_client_confirmation: the mission looks "done" to the
// craftsman but never actually closes until the client confirms.
class _ActiveRequestBanner extends ConsumerWidget {
  const _ActiveRequestBanner({required this.active});

  final ActiveRequest active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final needsConfirmation =
        active.status == ServiceRequestStatus.awaitingClientConfirmation;
    final bg = needsConfirmation
        ? const Color(0xFFFDE8E8)
        : const Color(0xFFFFF3CD);
    final fg = needsConfirmation
        ? const Color(0xFFC62828)
        : const Color(0xFF7A5B00);
    final message = switch (active.status) {
      ServiceRequestStatus.awaitingClientConfirmation =>
        l10n.jobAwaitingConfirmationMessage,
      ServiceRequestStatus.inProgress => l10n.jobInProgressMessage,
      ServiceRequestStatus.assigned => l10n.jobAssignedMessage,
      _ => l10n.jobSearchingMessage,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SearchingScreen(
                  category: active.serviceCategory,
                  resumeFrom: active,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  needsConfirmation
                      ? Icons.priority_high_rounded
                      : Icons.pending_rounded,
                  color: fg,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.activeJobBannerTitle,
                        style: TextStyle(fontWeight: FontWeight.w800, color: fg),
                      ),
                      const SizedBox(height: 2),
                      Text(message, style: TextStyle(fontSize: 13, color: fg)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: fg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category});

  final ServiceCategory category;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => TradeDetailScreen(category: category),
            ),
          );
        },
        child: Ink(
          decoration: const BoxDecoration(color: Color(0xFFEDEDED)),
          child: Stack(
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
                    stops: [0.4, 1.0],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Row(
                  children: [
                    Icon(category.icon, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        category.localizedLabel(AppLocalizations.of(context)!),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
