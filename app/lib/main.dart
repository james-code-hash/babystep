import 'package:flutter/widgets.dart';

import 'app_root.dart';
import 'bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final overrides = await bootstrapOverrides();
  runApp(AppRoot(overrides: overrides));
}
