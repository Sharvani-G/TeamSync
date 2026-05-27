import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import '../services/boot_logger_stub.dart'
    if (dart.library.html) '../services/boot_logger_web.dart';
import 'package:flutter/material.dart';

import '../app/main_shell.dart';
import '../models/models.dart';
import 'entry_screen.dart';
import '../services/user_profile_service.dart';
import '../services/user_service.dart';
import 'chat_channel_screen.dart';
import 'chat_home_screen.dart';
import 'username_repair_screen.dart';
import '../services/web_utils_stub.dart'
    if (dart.library.html) '../services/web_utils_web.dart';

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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final startupRoute = _buildStartupRouteName();
          if (startupRoute != null) {
            appendBootLog('[ROUTE] restoring deep-link $startupRoute');
            print(
                '${DateTime.now().toIso8601String()} [ROUTE] restoring deep-link $startupRoute');
            Navigator.of(context).pushReplacementNamed(startupRoute);
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

    // If the browser was redirected with an OAuth fragment (e.g. code=...)
    // clear it early so the app doesn't remain stuck on an auth callback.
    try {
      final frag = getLocationFragment().trim();
      if (frag.isNotEmpty && !frag.startsWith('/') && frag.contains('=')) {
        appendBootLog('[AUTH] detected OAuth fragment; clearing it');
        clearOAuthCallbackState();
      }
    } catch (_) {}

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
    final fragment = getLocationFragment().trim();
    if (fragment.isNotEmpty) {
      // If fragment looks like an OAuth callback (contains '=' and
      // does not start with '/'), clear it and fall back to '/'.
      if (!fragment.startsWith('/') && fragment.contains('=')) {
        clearOAuthCallbackState();
        return '/';
      }
      return fragment.startsWith('/') ? fragment : '/$fragment';
    }

    final path = Uri.base.path.trim();
    return path.isEmpty ? '/' : path;
  }

  String? _buildStartupRouteName() {
    final path = _startupPath();
    print('${DateTime.now().toIso8601String()} [ROUTE] browser hash = $path');
    final supportedPrefixes = [
      RegExp(r'^/project/\w+$'),
      RegExp(r'^/project/\w+/idea-board$'),
      RegExp(r'^/project/\w+/idea-board/\w+$'),
      RegExp(r'^/project/\w+/chat$'),
      RegExp(r'^/project/\w+/chat/[\w-]+$'),
      RegExp(r'^/project/\w+/call$'),
      RegExp(r'^/project/\w+/workspace(?:/(idea-board|chat|calls))?$'),
      RegExp(r'^/project/\w+/track$'),
      RegExp(r'^/project/\w+/ai-report$'),
    ];

    for (final pattern in supportedPrefixes) {
      if (pattern.hasMatch(path)) {
        return path;
      }
    }

    return null;
  }

  Widget? _buildStartupRoute() {
    final path = _startupPath();

    final chatChannelMatch =
        RegExp(r'^/project/(\w+)/chat/([\w-]+)$').firstMatch(path);
    if (chatChannelMatch != null) {
      return ChatChannelScreen(
        projectId: chatChannelMatch.group(1)!,
        channelId: chatChannelMatch.group(2)!,
      );
    }

    final chatMatch = RegExp(r'^/project/(\w+)/chat$').firstMatch(path);
    if (chatMatch != null) {
      return ChatHomeScreen(projectId: chatMatch.group(1)!);
    }

    final projectMatch = RegExp(r'^/project/(\w+)$').firstMatch(path);
    if (projectMatch != null) {
      return const MainShell();
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

              final user = userSnapshot.data;

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

        appendBootLog('[ROUTE] navigating to EntryScreen');
        print(
            '${DateTime.now().toIso8601String()} [ROUTE] navigating to EntryScreen');
        try {
          clearOAuthCallbackState();
        } catch (_) {}
        return const EntryScreen();
      },
    );
  }
}
