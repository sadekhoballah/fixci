// Only meaningful on platforms without a real Firebase session (see
// isFirebaseSupportedPlatform) — e.g. a desktop debug build — where phone
// verification goes through DevBypassPhoneVerificationService and never
// produces a real ID token, so there's nothing to send as a bearer token.
// Mirrors the backend's own ALLOW_DEV_AUTH_BYPASS escape hatch: a plain
// phone number sent as X-Dev-Phone instead, purely so the app is testable
// end-to-end on desktop without real Firebase credentials. Set once the
// phone being registered/signed-in-as is known — see onboarding_controller
// and splash_screen.
String? devBypassPhone;
