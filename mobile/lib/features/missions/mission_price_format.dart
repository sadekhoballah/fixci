import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';

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
