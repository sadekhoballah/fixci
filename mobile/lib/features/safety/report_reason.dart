import '../../l10n/app_localizations.dart';

// Mirrors backend/src/database/enums/report-reason.enum.ts — predefined
// categories only, no free-text reason of its own (see ReportUserDto.message
// for the optional free-text detail alongside whichever of these is picked).
enum ReportReason { harassment, noShow, fraud, inappropriateContent, other }

String reportReasonWireValue(ReportReason reason) => switch (reason) {
  ReportReason.harassment => 'harassment',
  ReportReason.noShow => 'no_show',
  ReportReason.fraud => 'fraud',
  ReportReason.inappropriateContent => 'inappropriate_content',
  ReportReason.other => 'other',
};

String reportReasonLabel(ReportReason reason, AppLocalizations l10n) =>
    switch (reason) {
      ReportReason.harassment => l10n.reportReasonHarassmentLabel,
      ReportReason.noShow => l10n.reportReasonNoShowLabel,
      ReportReason.fraud => l10n.reportReasonFraudLabel,
      ReportReason.inappropriateContent =>
        l10n.reportReasonInappropriateContentLabel,
      ReportReason.other => l10n.reportReasonOtherLabel,
    };
