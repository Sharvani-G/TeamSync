// Anti-pattern guard:
// - Do not reintroduce self-notification echoes.
// - Do not write placeholder file rows before Storage upload completes.
// - Do not create duplicate unread chat alerts per message.
// - Do not show blank attachment downloads or SVG previews in-place.
// - Do not leak local optimistic chat state into the visible timeline.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
// models referenced in other files; keep import minimal at top-level
import 'config/env_config.dart';
import 'app/router.dart';
import 'theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'services/settings_service.dart';
import 'services/notification_service.dart';
import 'services/file_picker_web_bootstrap_stub.dart'
    if (dart.library.html) 'services/file_picker_web_bootstrap_web.dart';
import 'services/boot_logger_stub.dart'
    if (dart.library.html) 'services/boot_logger_web.dart';
import 'services/web_utils_stub.dart'
    if (dart.library.html) 'services/web_utils_web.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  appendBootLog('[BOOT] app start');
  print('${DateTime.now().toIso8601String()} [BOOT] app start');
  final envConfig = await TeamSyncEnvConfig.instance;
  envConfig.logStartupSelection();
  await Firebase.initializeApp(
    options: envConfig.firebaseOptions,
  );
  if (kIsWeb) {
    appendBootLog('[BOOT] using ${envConfig.storageRegion} storage profile');
  }
  appendBootLog('[BOOT] firebase initialized');
  print('${DateTime.now().toIso8601String()} [BOOT] firebase initialized');
  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    ensureFilePickerWebInitialized();
  }
  if (!kIsWeb) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }
  await NotificationService.instance.initializePushNotifications(
    onNotificationTap: (route, data) {
      final navigator = appNavigatorKey.currentState;
      if (navigator == null) {
        return;
      }

      navigator.pushNamed(route.isEmpty ? '/notifications' : route, arguments: data);
    },
  );
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
        return ScreenUtilInit(
          designSize: const Size(375, 812),
          minTextAdapt: true,
          builder: (context, child) {
            return MaterialApp(
              title: 'TeamSync',
              debugShowCheckedModeBanner: false,
              navigatorKey: appNavigatorKey,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: mode,
              initialRoute: _initialRoute(),
              onGenerateRoute: generateRoute,
            );
          },
        );
      },
    );
  }

  String _initialRoute() {
    final fragment = getLocationFragment().trim();
    if (fragment.isNotEmpty) {
      // If the fragment looks like an OAuth callback (contains '=' and
      // does not start with a route '/'), clear it and fall back to '/'.
      if (!fragment.startsWith('/') && fragment.contains('=')) {
        clearOAuthCallbackState();
        return '/';
      }
      final route = fragment.startsWith('/') ? fragment : '/$fragment';
      return route;
    }

    final path = Uri.base.path.trim();
    if (path.isEmpty || path == '/') {
      return '/';
    }

    return path.startsWith('/') ? path : '/$path';
  }
}
