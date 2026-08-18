export enum ServiceCategory {
  PLUMBER = 'plumber',
  ELECTRICIAN = 'electrician',
  AC_REPAIR = 'ac_repair',
  CLEANING = 'cleaning',
  CARPENTER = 'carpenter',
  MECHANIC = 'mechanic',
  PAINTER = 'painter',
  ALUMINUM_WORK = 'aluminum_work',
  CAMERA_INSTALLATION = 'camera_installation',
  TV_INSTALLATION = 'tv_installation',
  SATELLITE_INSTALLATION = 'satellite_installation',
  CONSTRUCTION = 'construction',
  BLACKSMITH = 'blacksmith',
  HOUSEKEEPING = 'housekeeping',
  HOME_TUTORING = 'home_tutoring',
  TAXI = 'taxi',
  CAMION = 'camion',
  // Catch-all for a trade that doesn't fit any category above. Never shown
  // as a client-facing tile and never queried by the real-time matching
  // engine (see CraftsmanProfile.freeTradeName) — its only entry point into
  // the app is the Missions/Freelance board.
  OTHER_TRADE = 'other_trade',
}
