import 'package:flutter/material.dart';

// Lets code with no BuildContext of its own — a notification tap arriving
// while the app is backgrounded/terminated is the only real user of this —
// still push a route. Attached to MaterialApp in app.dart.
final rootNavigatorKey = GlobalKey<NavigatorState>();
