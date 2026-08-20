import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../l10n/app_localizations.dart';
import '../../safety/widgets/report_block_menu.dart';
import '../mission_applicants_controller.dart';
import '../missions_models.dart';

String _formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

// Owner-only — lists everyone who applied to one of the caller's own
// missions, with a "Sélectionner" action per pending candidate. Pops with
// `true` once a selection succeeds, so MissionDetailScreen knows to refresh.
class MissionApplicantsScreen extends ConsumerStatefulWidget {
  const MissionApplicantsScreen({super.key, required this.missionId});

  final String missionId;

  @override
  ConsumerState<MissionApplicantsScreen> createState() =>
      _MissionApplicantsScreenState();
}

class _MissionApplicantsScreenState
    extends ConsumerState<MissionApplicantsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(missionApplicantsControllerProvider.notifier)
          .load(widget.missionId),
    );
  }

  Future<void> _confirmSelect(MissionApplicant applicant) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.selectApplicantConfirmTitle),
        content: Text(
          l10n.selectApplicantConfirmContent(
            applicant.applicantFullName ?? applicant.applicantPhone ?? '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.selectApplicantButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    ref
        .read(missionApplicantsControllerProvider.notifier)
        .select(widget.missionId, applicant.applicationId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    ref.listen(missionApplicantsControllerProvider, (previous, next) {
      if (next.selectedApplicationId != null &&
          next.selectedApplicationId != previous?.selectedApplicationId) {
        Navigator.of(context).pop(true);
        return;
      }
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }
    });
    final state = ref.watch(missionApplicantsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.applicantsScreenTitle)),
      body: SafeArea(
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : state.applicants.isEmpty
            ? Center(
                child: Text(
                  state.errorMessage ?? l10n.noApplicantsYetMessage,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: state.applicants.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _ApplicantCard(
                  missionId: widget.missionId,
                  applicant: state.applicants[index],
                  isProcessing: state.processingApplicationIds.contains(
                    state.applicants[index].applicationId,
                  ),
                  onSelect: () => _confirmSelect(state.applicants[index]),
                ),
              ),
      ),
    );
  }
}

class _ApplicantCard extends StatelessWidget {
  const _ApplicantCard({
    required this.missionId,
    required this.applicant,
    required this.isProcessing,
    required this.onSelect,
  });

  final String missionId;
  final MissionApplicant applicant;
  final bool isProcessing;
  final VoidCallback onSelect;

  Future<void> _call() async {
    final phone = applicant.applicantPhone;
    if (phone == null) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsapp() async {
    final phone = applicant.applicantPhone;
    if (phone == null) return;
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$digits');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  applicant.applicantFullName ?? applicant.applicantPhone ?? '—',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (applicant.averageRating != null) ...[
                const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFFC107)),
                const SizedBox(width: 2),
                Text(
                  applicant.averageRating!.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ],
              ReportBlockMenu(
                targetUserId: applicant.applicantId,
                contextType: 'mission',
                contextId: missionId,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.social_distance_rounded,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                _formatDistance(applicant.distanceMeters),
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          if (applicant.message != null && applicant.message!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(applicant.message!, style: const TextStyle(fontSize: 13)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: applicant.applicantPhone == null ? null : _call,
                  icon: const Icon(Icons.call_rounded, size: 16),
                  label: Text(l10n.callButton),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: applicant.applicantPhone == null ? null : _whatsapp,
                  icon: const Icon(Icons.chat_rounded, size: 16),
                  label: const Text('WhatsApp'),
                ),
              ),
            ],
          ),
          if (applicant.status == MissionApplicationStatus.pending) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isProcessing ? null : onSelect,
                child: isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.selectApplicantButton),
              ),
            ),
          ] else if (applicant.status == MissionApplicationStatus.selected) ...[
            const SizedBox(height: 8),
            _StatusChip(
              label: l10n.youWereSelectedMessage,
              bg: const Color(0xFFE0F2E9),
              fg: const Color(0xFF1B8A3B),
            ),
          ] else if (applicant.status ==
              MissionApplicationStatus.notSelected) ...[
            const SizedBox(height: 8),
            _StatusChip(
              label: l10n.youWereNotSelectedMessage,
              bg: const Color(0xFFF0F0F0),
              fg: const Color(0xFF757575),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
