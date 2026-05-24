import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import '../services/boot_logger_stub.dart'
    if (dart.library.html) '../services/boot_logger_web.dart';
import 'package:flutter/material.dart';

import '../app/main_shell.dart';
import '../models/models.dart';
import '../services/user_profile_service.dart';
import '../services/user_service.dart';
import 'chat_channel_screen.dart';
import 'entry_screen.dart';
import 'username_repair_screen.dart';

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  static const Duration _authHydrationTimeout = Duration(seconds: 10);

  bool _authBootstrapComplete = false;
  User? _bootstrapUser;
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    appendBootLog('[AUTH] AuthGate mounted');
    print('${DateTime.now().toIso8601String()} [AUTH] AuthGate mounted');
    _performAuthBootstrap();
    // log currentUser at mount
    appendBootLog('[AUTH] currentUser = ${FirebaseAuth.instance.currentUser}');
    print(
        '${DateTime.now().toIso8601String()} [AUTH] currentUser = ${FirebaseAuth.instance.currentUser}');
    _authSub = FirebaseAuth.instance.authStateChanges().listen((u) {
      appendBootLog('[AUTH] authStateChanges emitted: $u');
      print(
          '${DateTime.now().toIso8601String()} [AUTH] authStateChanges emitted: $u');
      if (u != null) {
        _bootstrapUser = u;
        _authSub?.cancel();
        if (!mounted) return;
        setState(() {});
        // If we already completed bootstrap and the UI is still on the
        // unauthenticated entry screen, proactively navigate to the
        // deep-linked startup route so the user lands where they expect.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final startup = _buildStartupRoute();
          if (startup != null) {
            appendBootLog('[ROUTE] restoring deep-link $startup');
            print(
                '${DateTime.now().toIso8601String()} [ROUTE] restoring deep-link $startup');
            Navigator.of(context).pushReplacement(MaterialPageRoute(
              builder: (ctx) => startup,
            ));
            return;
          }

          appendBootLog('[ROUTE] restoring MainShell');
          print(
              '${DateTime.now().toIso8601String()} [ROUTE] restoring MainShell');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (ctx) => const MainShell()),
          );
        });
      }
    });

    // idTokenChanges: log first emission
    FirebaseAuth.instance.idTokenChanges().first.then((t) {
      appendBootLog('[AUTH] idTokenChanges emitted: $t');
      print(
          '${DateTime.now().toIso8601String()} [AUTH] idTokenChanges emitted: $t');
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _performAuthBootstrap() async {
    appendBootLog('[AUTH] starting explicit web hydration polling');
    print(
        '${DateTime.now().toIso8601String()} [AUTH] starting explicit web hydration polling');

    final end = DateTime.now().add(_authHydrationTimeout);
    try {
      while (DateTime.now().isBefore(end)) {
        final current = FirebaseAuth.instance.currentUser;
        appendBootLog('[AUTH] poll currentUser = $current');
        print(
            '${DateTime.now().toIso8601String()} [AUTH] poll currentUser = $current');
        if (current != null) {
          _bootstrapUser = current;
          appendBootLog('[AUTH] hydration success: $current');
          print(
              '${DateTime.now().toIso8601String()} [AUTH] hydration success: $current');
          break;
        }
        await Future.delayed(const Duration(milliseconds: 300));
      }
    } catch (_) {
      // ignore
    } finally {
      if (!mounted) return;
      _authBootstrapComplete = true;
      setState(() {});
      // Log final state
      appendBootLog('[AUTH] bootstrap complete, user=${_bootstrapUser}');
      print(
          '${DateTime.now().toIso8601String()} [AUTH] bootstrap complete, user=${_bootstrapUser}');
    }
  }

  String _startupPath() {
    final fragment = Uri.base.fragment.trim();
    if (fragment.isNotEmpty) {
      return fragment.startsWith('/') ? fragment : '/$fragment';
    }

    final path = Uri.base.path.trim();
    return path.isEmpty ? '/' : path;
  }

  Widget? _buildStartupRoute() {
    final path = _startupPath();
    print('${DateTime.now().toIso8601String()} [ROUTE] browser hash = $path');
    final chatMatch =
        RegExp(r'^/project/(\w+)/chat/([\w-]+)$').firstMatch(path);
    if (chatMatch != null) {
      return ChatChannelScreen(
        projectId: chatMatch.group(1)!,
        channelId: chatMatch.group(2)!,
      );
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (!_authBootstrapComplete) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: _bootstrapUser,
      builder: (context, snapshot) {
        if (snapshot.data != null) {
          return StreamBuilder<AppUser?>(
            stream: UserProfileService.instance.watchCurrentUser(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final user = userSnapshot.data;
              final authUser = FirebaseAuth.instance.currentUser;

              if (authUser == null) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final startupRoute = _buildStartupRoute();
              if (startupRoute != null) {
                return startupRoute;
              }

              final needsRepair = user == null ||
                  UserService.needsUsernameRepair(
                    username: user.username,
                    email: user.email.isNotEmpty
                        ? user.email
                        : authUser.email ?? '',
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

        // Log and return EntryScreen (only once)
        appendBootLog('[ROUTE] navigating to EntryScreen');
        print(
            '${DateTime.now().toIso8601String()} [ROUTE] navigating to EntryScreen');
        return const EntryScreen();
      },
    );
  }
}
