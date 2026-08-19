import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';
import 'missions_models.dart';

// Localized weekday name for a mission's scheduledDayOfWeek (1 = Monday ..
// 7 = Sunday, matching DateTime.weekday — see MissionSummary). Builds a
// throwaway reference date landing on that weekday and lets intl name it,
// rather than hard-coding 7 weekday l10n keys across all 4 languages.
String missionWeekdayLabel(int dayOfWeek, String localeName) {
  // 2024-01-01 was a Monday — any known Monday works as the anchor.
  final anchor = DateTime(2024, 1, 1).add(Duration(days: dayOfWeek - 1));
  return DateFormat.EEEE(localeName).format(anchor);
}

// Whole-hour, 24h clock — deliberately locale-neutral (no AM/PM split to
// translate) since the form only ever lets the poster pick a whole hour.
String missionHourLabel(int hour) => '${hour.toString().padLeft(2, '0')}:00';

// The chip/detail text for a mission's timing preference — null for
// unspecified (callers should just omit the chip entirely rather than
// showing "not specified" on every single mission card).
String? missionTimingDisplayLabel(
  AppLocalizations l10n,
  String localeName,
  MissionTimingPreference timingPreference,
  int? scheduledDayOfWeek,
  int? scheduledHour,
) {
  switch (timingPreference) {
    case MissionTimingPreference.unspecified:
      return null;
    case MissionTimingPreference.immediate:
      return l10n.missionTimingImmediateLabel;
    case MissionTimingPreference.scheduled:
      if (scheduledDayOfWeek == null || scheduledHour == null) return null;
      return l10n.missionScheduledForLabel(
        missionWeekdayLabel(scheduledDayOfWeek, localeName),
        missionHourLabel(scheduledHour),
      );
  }
}
