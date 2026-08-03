import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/locale_controller.dart';
import '../../l10n/app_localizations.dart';

// Language names are shown in their own language, not translated per the
// active locale — the standard convention (a French speaker still needs to
// recognize "English"/"العربية"/"Русский" to pick them).
const _nativeNames = {'fr': 'Français', 'en': 'English', 'ar': 'العربية', 'ru': 'Русский'};

class LanguagePicker extends ConsumerWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeControllerProvider);
    final controller = ref.read(localeControllerProvider.notifier);

    return Semantics(
      label: AppLocalizations.of(context)!.selectLanguage,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: AppLocalizations.supportedLocales.map((locale) {
          final selected = locale.languageCode == current.languageCode;
          return ChoiceChip(
            label: Text(
              _nativeNames[locale.languageCode] ?? locale.languageCode,
            ),
            selected: selected,
            onSelected: (_) => controller.setLocale(locale),
          );
        }).toList(),
      ),
    );
  }
}
