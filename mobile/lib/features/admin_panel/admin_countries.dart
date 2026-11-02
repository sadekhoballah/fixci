import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Every launched country, in display order — matches the backend's
// LAUNCHED_COUNTRY_CODES (src/districts/launched-countries.ts).
const adminCountries = <String, String>{
  'CI': "Côte d'Ivoire",
  'SN': 'Sénégal',
  'CM': 'Cameroun',
  'BJ': 'Bénin',
  'TG': 'Togo',
  'BF': 'Burkina Faso',
  'ML': 'Mali',
  'GN': 'Guinée',
  'GH': 'Ghana',
  'NG': 'Nigeria',
  'CG': 'Congo-Brazzaville',
  'CD': 'RD Congo',
  'LB': 'Liban',
};

// "SN" → 🇸🇳 (two regional-indicator symbols).
String countryFlag(String code) => code.length != 2
    ? ''
    : String.fromCharCodes(
        code.toUpperCase().codeUnits.map((c) => 0x1F1E6 + c - 0x41),
      );

String countryLabel(String code) => adminCountries[code] ?? code;

String countryWithFlag(String code) =>
    '${countryFlag(code)} ${countryLabel(code)}';

// The country the whole panel is narrowed to (null = every country). One
// shared choice rather than a picker per tab, so switching to "Sénégal"
// applies to Live Ops, the KYC queue, the histories, the directory and the
// districts at once. Controllers ref.listen to it and refetch.
class AdminCountryFilter extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? code) => state = code;
}

final adminCountryFilterProvider =
    NotifierProvider<AdminCountryFilter, String?>(AdminCountryFilter.new);

// AppBar action showing (and changing) adminCountryFilterProvider.
class AdminCountryFilterButton extends ConsumerWidget {
  const AdminCountryFilterButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(adminCountryFilterProvider);
    return PopupMenuButton<String>(
      tooltip: 'Filtrer par pays',
      initialValue: selected ?? '',
      onSelected: (code) => ref
          .read(adminCountryFilterProvider.notifier)
          .set(code.isEmpty ? null : code),
      itemBuilder: (_) => [
        const PopupMenuItem(value: '', child: Text('🌍 Tous les pays')),
        for (final code in adminCountries.keys)
          PopupMenuItem(value: code, child: Text(countryWithFlag(code))),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selected == null ? '🌍 Tous les pays' : countryWithFlag(selected),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const Icon(Icons.arrow_drop_down_rounded),
          ],
        ),
      ),
    );
  }
}
