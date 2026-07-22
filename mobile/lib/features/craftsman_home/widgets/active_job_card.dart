import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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

  Future<void> _navigate() async {
    final uri = Uri.parse(
      'geo:${job.clientLatitude},${job.clientLongitude}'
      '?q=${job.clientLatitude},${job.clientLongitude}',
    );
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Annuler cette mission ?'),
        content: const Text(
          'Le client sera informé que vous ne pouvez plus intervenir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Retour'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Annuler la mission'),
          ),
        ],
      ),
    );
    if (confirmed == true) onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final inProgress = job.status == ActiveJobStatus.inProgress;

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
                inProgress ? Icons.handyman_rounded : Icons.directions_walk_rounded,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                inProgress ? 'Mission en cours' : 'Mission acceptée',
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
                job.serviceCategory.label,
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            job.clientFullName ?? 'Client',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _call,
                  icon: const Icon(Icons.call, size: 18),
                  label: const Text('Appeler'),
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
                  onPressed: _navigate,
                  icon: const Icon(Icons.directions_rounded, size: 18),
                  label: const Text('Itinéraire'),
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
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: isProcessing ? null : () => _confirmCancel(context),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Annuler'),
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
                    inProgress ? 'Terminer la mission' : 'Démarrer la mission',
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
