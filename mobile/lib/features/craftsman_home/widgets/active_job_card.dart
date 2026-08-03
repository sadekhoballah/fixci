import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/service_category.dart';
import '../../../l10n/app_localizations.dart';
import '../live_requests_state.dart';

// Shown instead of the incoming-request feed once a job is assigned — a
// craftsman working a job shouldn't be looking at a list of unrelated new
// requests. Actions map directly to the Module A backend endpoints.
class ActiveJobCard extends StatelessWidget {
  const ActiveJobCard({
    super.key,
    required this.job,
    required this.isProcessing,
    required this.onStart,
    required this.onComplete,
    required this.onCancel,
  });

  final ActiveJob job;
  final bool isProcessing;
  final VoidCallback onStart;
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  Future<void> _call() async {
    final uri = Uri(scheme: 'tel', path: job.clientPhone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsapp() async {
    final digits = job.clientPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$digits');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _navigate() async {
    final uri = Uri.parse(
      'geo:${job.clientLatitude},${job.clientLongitude}'
      '?q=${job.clientLatitude},${job.clientLongitude}',
    );
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.cancelJobConfirmTitle),
        content: Text(l10n.cancelJobConfirmContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.backButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.cancelJobButton),
          ),
        ],
      ),
    );
    if (confirmed == true) onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final inProgress = job.status == ActiveJobStatus.inProgress;
    final awaitingConfirmation =
        job.status == ActiveJobStatus.awaitingClientConfirmation;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                awaitingConfirmation
                    ? Icons.hourglass_top_rounded
                    : inProgress
                    ? Icons.handyman_rounded
                    : Icons.directions_walk_rounded,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                awaitingConfirmation
                    ? l10n.awaitingConfirmationStatus
                    : inProgress
                    ? l10n.jobInProgressStatus
                    : l10n.jobAcceptedStatus,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
              const Spacer(),
              Icon(job.serviceCategory.icon, size: 20, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                job.serviceCategory.localizedLabel(l10n),
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            job.clientFullName ?? l10n.defaultClientName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _call,
                  icon: const Icon(Icons.call, size: 18),
                  label: Text(l10n.callButton),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _whatsapp,
                  icon: const Icon(Icons.chat_rounded, size: 18),
                  label: const Text('WhatsApp'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _navigate,
              icon: const Icon(Icons.directions_rounded, size: 18),
              label: Text(l10n.directionsButton),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (awaitingConfirmation)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                l10n.awaitingClientConfirmationMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: isProcessing ? null : () => _confirmCancel(context),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: Text(l10n.cancelButton),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: isProcessing ? null : (inProgress ? onComplete : onStart),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      inProgress ? l10n.completeJobButton : l10n.startJobButton,
                      style: const TextStyle(fontWeight: FontWeight.w700),
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
