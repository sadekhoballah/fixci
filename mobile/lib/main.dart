import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/platform/firebase_support.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Don't await this before runApp: it's a platform-channel round trip that
  // can take over a second on a cold start, which would otherwise hold the
  // splash screen's first frame back and leave the OS's plain-color splash
  // on screen far longer than intended. Nothing paints before the splash
  // screen needs Firebase — phone verification is the first real user of it,
  // several screens later — so it's safe to let this finish in the
  // background; firebaseInitFuture lets that real first user await it.
  if (isFirebaseSupportedPlatform) {
    firebaseInitFuture = Firebase.initializeApp();
  }
  runApp(const ProviderScope(child: FixCiApp()));
}
