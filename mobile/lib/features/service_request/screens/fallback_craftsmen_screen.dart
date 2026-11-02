import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/fallback_craftsmen_panel.dart';

// The contact-directly list on its own, for when the client comes back from
// the "nobody accepted in time" push rather than still sitting on
// SearchingScreen — see PushNotificationService._navigateForEvent.
class FallbackCraftsmenScreen extends StatelessWidget {
  const FallbackCraftsmenScreen({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.fallbackScreenTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: FallbackCraftsmenPanel(
            requestId: requestId,
            onBackHome: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ),
      ),
    );
  }
}
