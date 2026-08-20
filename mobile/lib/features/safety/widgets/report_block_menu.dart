import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../report_reason.dart';
import '../safety_repository.dart';

// Self-contained "..." action, dropped inline wherever another user's
// contact info is shown (a mission's poster/applicant, an active job/
// request's counterpart) — mirrors the founder's "Report/Block on
// client/craftsman profiles, mission details, and contact points" ask, and
// there's no separate "view profile" screen in this app for it to live on
// instead. Renders nothing (returns SizedBox.shrink) when targetUserId is
// null — the common case of "no counterpart to act on yet" (e.g. a mission
// with no selected applicant), so every call site can pass a nullable id
// unconditionally instead of wrapping this in its own null check.
class ReportBlockMenu extends ConsumerWidget {
  const ReportBlockMenu({
    super.key,
    required this.targetUserId,
    this.contextType,
    this.contextId,
    this.iconColor,
  });

  final String? targetUserId;
  // Which mission/service-request this report would be about, if any — see
  // ReportUserDto.contextType/contextId. Purely informational for the admin
  // reviewing it later.
  final String? contextType;
  final String? contextId;
  final Color? iconColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = targetUserId;
    if (userId == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;

    return IconButton(
      tooltip: l10n.reportOrBlockMenuTooltip,
      icon: Icon(Icons.more_vert_rounded, color: iconColor),
      onPressed: () => _openMenu(context, ref, userId),
    );
  }

  Future<void> _openMenu(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final action = await showModalBottomSheet<_SafetyAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(l10n.reportUserButton),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_SafetyAction.report),
            ),
            ListTile(
              leading: const Icon(Icons.block_rounded),
              title: Text(l10n.blockUserButton),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_SafetyAction.block),
            ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    if (action == _SafetyAction.report) {
      await _openReportDialog(context, ref, userId);
    } else {
      await _confirmBlock(context, ref, userId);
    }
  }

  Future<void> _openReportDialog(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messageController = TextEditingController();
    var reason = ReportReason.harassment;
    var alsoBlock = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(l10n.reportUserDialogTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<ReportReason>(
                  initialValue: reason,
                  decoration: InputDecoration(
                    labelText: l10n.reportReasonLabel,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final value in ReportReason.values)
                      DropdownMenuItem(
                        value: value,
                        child: Text(reportReasonLabel(value, l10n)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => reason = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageController,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.reportMessageLabel,
                    hintText: l10n.reportMessageHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: alsoBlock,
                  title: Text(l10n.alsoBlockUserCheckboxLabel),
                  onChanged: (value) =>
                      setState(() => alsoBlock = value ?? alsoBlock),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancelButton),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.submitReportButton),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;
    final message = messageController.text.trim();
    final repository = ref.read(safetyRepositoryProvider);
    try {
      await repository.reportUser(
        userId,
        reason: reason,
        message: message.isEmpty ? null : message,
        contextType: contextType,
        contextId: contextId,
      );
      if (alsoBlock) {
        await repository.blockUser(userId);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.reportSubmittedMessage)),
      );
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.genericErrorMessage)));
    }
  }

  Future<void> _confirmBlock(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.blockUserConfirmTitle),
        content: Text(l10n.blockUserConfirmContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.blockUserButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(safetyRepositoryProvider).blockUser(userId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.userBlockedMessage)));
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.genericErrorMessage)));
    }
  }
}

enum _SafetyAction { report, block }
