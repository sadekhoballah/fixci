import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../network/api_config.dart';
import '../screenshot_mode.dart';

enum _UpdateState { none, optional, required }

/// Wraps the whole app (via MaterialApp.builder) and asks the backend's
/// GET /app/version which builds are still allowed. The build number after
/// the "+" in pubspec.yaml is compared to:
///  - minBuild: below it, a full-screen blocking "update required" screen;
///  - latestBuild: below it, a dismissible "new version" banner.
/// Re-checked on every resume, so raising APP_MIN_BUILD_* on the server
/// reaches users already inside the app. Any network/parse error lets the
/// app through: a backend hiccup must never lock people out.
class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate>
    with WidgetsBindingObserver {
  _UpdateState _state = _UpdateState.none;
  String? _storeUrl;
  bool _optionalDismissed = false;

  static bool get _enabled =>
      !kIsWeb && !kScreenshotMode && (Platform.isAndroid || Platform.isIOS);

  @override
  void initState() {
    super.initState();
    if (!_enabled) return;
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    try {
      final platform = Platform.isIOS ? 'ios' : 'android';
      final results = await Future.wait([
        PackageInfo.fromPlatform(),
        http
            .get(
              Uri.parse('${ApiConfig.baseUrl}/app/version?platform=$platform'),
            )
            .timeout(const Duration(seconds: 10)),
      ]);
      final info = results[0] as PackageInfo;
      final response = results[1] as http.Response;
      if (response.statusCode != 200) return;

      final build = int.tryParse(info.buildNumber) ?? 0;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final minBuild = (data['minBuild'] as num?)?.toInt() ?? 0;
      final latestBuild = (data['latestBuild'] as num?)?.toInt() ?? 0;
      final storeUrl = data['storeUrl'] as String?;
      if (build <= 0) return;

      final next = build < minBuild
          ? _UpdateState.required
          : build < latestBuild
          ? _UpdateState.optional
          : _UpdateState.none;
      if (!mounted) return;
      setState(() {
        _state = next;
        _storeUrl = storeUrl;
      });
    } catch (_) {
      // Offline, timeout, bad JSON: keep whatever state we had.
    }
  }

  Future<void> _openStore() async {
    final url = _storeUrl;
    if (url == null || url.isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final showOptional = _state == _UpdateState.optional && !_optionalDismissed;
    return Stack(
      children: [
        widget.child,
        if (_state == _UpdateState.required)
          Positioned.fill(child: _RequiredScreen(onUpdate: _openStore)),
        if (showOptional)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: _OptionalBanner(
                onUpdate: _openStore,
                onLater: () => setState(() => _optionalDismissed = true),
              ),
            ),
          ),
      ],
    );
  }
}

class _RequiredScreen extends StatelessWidget {
  const _RequiredScreen({required this.onUpdate});

  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    // Swallow the Android back button too, so the blocking screen can't be
    // popped to reach the screens underneath.
    return PopScope(
      canPop: false,
      child: Material(
        color: theme.colorScheme.surface,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.system_update,
                  size: 72,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.updateRequiredTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.updateRequiredBody,
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onUpdate,
                    child: Text(l10n.updateNowButton),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionalBanner extends StatelessWidget {
  const _OptionalBanner({required this.onUpdate, required this.onLater});

  final VoidCallback onUpdate;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.updateAvailableTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(l10n.updateAvailableBody, style: theme.textTheme.bodyMedium),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onLater,
                  child: Text(l10n.updateLaterButton),
                ),
                FilledButton(
                  onPressed: onUpdate,
                  child: Text(l10n.updateNowButton),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
