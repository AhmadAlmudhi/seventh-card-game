import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'state/prefs.dart';
import 'theme/colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The Cairo font is SIL OFL: its license ships with the app.
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['Cairo'], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });

  // In a release build, a part of the screen that fails to build shows a quiet placeholder rather
  // than Flutter's grey box. Debug builds keep the full error.
  if (kReleaseMode) {
    ErrorWidget.builder = (_) =>
        const Center(child: Icon(Icons.error_outline_rounded, color: AppColors.onTableMuted, size: 28));
  }

  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(overrides: [prefsProvider.overrideWithValue(Prefs(prefs))], child: const SeventhCardApp()));
}
