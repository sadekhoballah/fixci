import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'missions_models.dart';

// Shared by MyMissionsScreen's status pills and MissionDetailScreen's status
// banner — same (bg, fg, label) shape as client_jobs_screen.dart's
// _statusStyle, just for MissionStatus instead of RequestHistoryStatus.
(Color, Color, String) missionStatusStyle(
  MissionStatus status,
  AppLocalizations l10n,
) => switch (status) {
  MissionStatus.draft => (
    const Color(0xFFF0F0F0),
    const Color(0xFF757575),
    l10n.missionStatusDraftLabel,
  ),
  MissionStatus.pendingModeration => (
    const Color(0xFFFFF3CD),
    const Color(0xFF7A5B00),
    l10n.missionStatusPendingLabel,
  ),
  MissionStatus.approvedPublished => (
    const Color(0xFFE3F2FD),
    const Color(0xFF1565C0),
    l10n.missionStatusPublishedLabel,
  ),
  MissionStatus.rejected => (
    const Color(0xFFFDE8E8),
    const Color(0xFFC62828),
    l10n.missionStatusRejectedLabel,
  ),
  MissionStatus.inProgress => (
    const Color(0xFFFFF3CD),
    const Color(0xFF7A5B00),
    l10n.missionStatusInProgressLabel,
  ),
  MissionStatus.completed => (
    const Color(0xFFE0F2E9),
    const Color(0xFF1B8A3B),
    l10n.missionStatusCompletedLabel,
  ),
  MissionStatus.archived => (
    const Color(0xFFF0F0F0),
    const Color(0xFF757575),
    l10n.missionStatusArchivedLabel,
  ),
};
