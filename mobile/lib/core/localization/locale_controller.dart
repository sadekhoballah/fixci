import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import 'locale_storage.dart';

// French until the client explicitly picks something else — not derived
// from the device's own locale, since none of this app's launched markets
// (Côte d'Ivoire, Liban, Russie — see registration_screen.dart's phone
// country picker) can be assumed to want their OS language over the
// business's own default.
const defaultLocale = Locale('fr');

// Kept separate from SessionStorage/other per-account state: language is a
// device/install-level preference the client sets once on first launch
// (typically before registering), not something tied to their account.
class LocaleController extends Notifier<Locale> {
  @override
  Locale build() {
    _restore();
    return defaultLocale;
  }

  Future<void> _restore() async {
    final code = await ref.read(localeStorageProvider).loadLocaleCode();
    for (final locale in AppLocalizations.supportedLocales) {
      if (locale.languageCode == code) {
        state = locale;
        return;
      }
    }
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    await ref.read(localeStorageProvider).saveLocaleCode(locale.languageCode);
  }
}

final localeControllerProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

// Gives non-widget code (Notifiers, repositories, plain services — none of
// which have a BuildContext) the same localized strings a screen would get
// via `AppLocalizations.of(context)`, so error messages built outside the
// widget tree still follow the client's chosen language. Rebuilds (and so
// invalidates anything reading it) whenever localeControllerProvider changes.
final l10nProvider = Provider<AppLocalizations>(
  (ref) => lookupAppLocalizations(ref.watch(localeControllerProvider)),
);
