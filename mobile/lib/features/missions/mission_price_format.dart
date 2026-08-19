import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';

// Sent as startingPrice whenever the poster leaves the (optional) price
// field blank on a new mission — founder's call, matches
// missionStartingPriceHint. Only ever applies at creation time; missions
// posted before this change can still carry a genuinely null startingPrice,
// which missionPriceDisplayLabel's callers handle separately.
const kDefaultMissionStartingPrice = 5000.0;

// Thousands-separated, no currency symbol — the app has no single launch
// currency (CFA countries vs Lebanon in USD, see SubscriptionTier), so a
// mission's startingPrice is shown as a plain figure and the two sides
// settle currency the same way they already settle everything else about
// the job, by talking directly (phone/WhatsApp).
String missionPriceDisplayLabel(
  AppLocalizations l10n,
  String localeName,
  double price,
) => l10n.missionStartingPriceDisplayLabel(
  NumberFormat.decimalPattern(localeName).format(price),
);
