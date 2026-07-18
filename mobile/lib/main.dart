import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/platform/firebase_support.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (isFirebaseSupportedPlatform) {
    await Firebase.initializeApp();
  }
  runApp(const ProviderScope(child: FixCiApp()));
}
