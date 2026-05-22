import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'models/models.dart';
import 'app/router.dart';
import 'theme/app_theme.dart';
import 'app/main_shell.dart';
import 'screens/entry_screen.dart';
import 'screens/username_repair_screen.dart';
import 'services/file_picker_web_bootstrap_stub.dart'
  if (dart.library.html) 'services/file_picker_web_bootstrap_web.dart';
import 'services/user_profile_service.dart';
import 'services/user_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print('Firebase initialization failed: $e');
    rethrow;
  }
  
  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    ensureFilePickerWebInitialized();
  }
  if (!kIsWeb) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }
  runApp(const ProjectSyncApp());
}

class ProjectSyncApp extends StatelessWidget {
  const ProjectSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TeamSync',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      onGenerateRoute: generateRoute,
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('Auth state error: ${snapshot.error}');
          return const Scaffold(
            body: Center(
              child: Text('Authentication error. Please restart the app.'),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data != null) {
          return StreamBuilder<AppUser?>(
            stream: UserProfileService.instance.watchCurrentUser(),
            builder: (context, userSnapshot) {
              if (userSnapshot.hasError) {
                print('User profile error: ${userSnapshot.error}');
                return const Scaffold(
                  body: Center(
                    child: Text('Failed to load user profile. Please restart the app.'),
                  ),
                );
              }

              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final user = userSnapshot.data;
              final authUser = FirebaseAuth.instance.currentUser;

              if (authUser == null) {
                return const EntryScreen();
              }

              final needsRepair = user == null || UserService.needsUsernameRepair(
                username: user.username,
                email: user.email.isNotEmpty ? user.email : authUser.email ?? '',
              );

              if (needsRepair) {
                return UsernameRepairScreen(
                  authUser: authUser,
                  existingUser: user,
                );
              }

              return const MainShell();
            },
          );
        }

        return const EntryScreen();
      },
    );
  }
}
