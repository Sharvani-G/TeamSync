import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
// models referenced in other files; keep import minimal at top-level
import 'app/router.dart';
import 'theme/app_theme.dart';
import 'services/settings_service.dart';
import 'services/file_picker_web_bootstrap_stub.dart'
    if (dart.library.html) 'services/file_picker_web_bootstrap_web.dart';
import 'services/boot_logger_stub.dart'
  if (dart.library.html) 'services/boot_logger_web.dart';
import 'services/web_location_stub.dart'
    if (dart.library.html) 'services/web_location_web.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  appendBootLog('[BOOT] app start');
  print('${DateTime.now().toIso8601String()} [BOOT] app start');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  appendBootLog('[BOOT] firebase initialized');
  print('${DateTime.now().toIso8601String()} [BOOT] firebase initialized');
  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    ensureFilePickerWebInitialized();
  }
  if (!kIsWeb) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }
  runApp(const ProjectSyncApp());
}

class ProjectSyncApp extends StatefulWidget {
  const ProjectSyncApp({super.key});

  @override
  State<ProjectSyncApp> createState() => _ProjectSyncAppState();
}

class _ProjectSyncAppState extends State<ProjectSyncApp> {
  final _settings = SettingsService.instance;

  @override
  void initState() {
    super.initState();
    _settings.load();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _settings.themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'TeamSync',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          initialRoute: _initialRoute(),
          onGenerateRoute: generateRoute,
        );
      },
    );
  }

  String _initialRoute() {
    final webHash = getWebLocationHash().trim();
    if (webHash.isNotEmpty) {
      final route = webHash.startsWith('#') ? webHash.substring(1) : webHash;
      if (route.isNotEmpty) {
        return route.startsWith('/') ? route : '/$route';
      }
    }

    final path = Uri.base.path.trim();
    if (path.isEmpty || path == '/') {
      return '/';
    }

    return path.startsWith('/') ? path : '/$path';
  }
}
