// When the poster wants the mission carried out. Deliberately a coarse
// weekday + hour preference rather than a real calendar date/time picker —
// mirrors the rest of Missions/Freelance's "no date/map picker anywhere"
// minimalism (see Mission.locationAddress). UNSPECIFIED is the default: the
// poster simply didn't say, IMMEDIATE means "as soon as possible", and
// SCHEDULED is the only variant that actually carries
// scheduledDayOfWeek/scheduledHour on the Mission entity.
export enum MissionTimingPreference {
  UNSPECIFIED = 'unspecified',
  IMMEDIATE = 'immediate',
  SCHEDULED = 'scheduled',
}
