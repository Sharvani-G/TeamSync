import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/home_dashboard_screen.dart';
import '../screens/discover_screen.dart';
import '../screens/notifications/notifications_page.dart';
import '../screens/profile/my_profile_page.dart';
import '../screens/incoming_call_overlay_screen.dart';
import '../services/project_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../services/webrtc_socket_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../screens/in_call_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _inviteSub;
  StreamSubscription<Map<String, dynamic>>? _incomingCallSub;
  final Set<String> _seenInvites = {};

  static const _prefKey = 'main_shell_active_index';

  static const List<Widget> _screens = [
    HomeDashboardScreen(),
    DiscoverScreen(),
    NotificationsPage(),
    MyProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    // Listener setup is handled in initState
    // Restore persisted index asynchronously
    SharedPreferences.getInstance().then((prefs) {
      final idx = prefs.getInt(_prefKey) ?? 0;
      if (idx != _currentIndex) {
        setState(() => _currentIndex = idx);
      }
    }).catchError((_) {});
    return StreamBuilder<int>(
      stream: ProjectService.instance.watchUnreadNotificationCount(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return Scaffold(
          backgroundColor: AppTheme.darkBackground,
          body: SizedBox.expand(
            child: IndexedStack(index: _currentIndex, children: _screens),
          ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              selectedItemColor: Theme.of(context).colorScheme.primary,
              unselectedItemColor: Colors.grey.shade500,
              backgroundColor: Theme.of(context).colorScheme.surface,
              type: BottomNavigationBarType.fixed,
              elevation: 8,
              onTap: (i) async {
                setState(() => _currentIndex = i);
                try {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt(_prefKey, _currentIndex);
                } catch (_) {}
              },
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.folder_outlined),
                  activeIcon: Icon(Icons.folder),
                  label: 'Dashboard',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.explore_outlined),
                  activeIcon: Icon(Icons.explore),
                  label: 'Discover',
                ),
                BottomNavigationBarItem(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.notifications_outlined),
                      if (unreadCount > 0)
                        Positioned(
                          right: -6,
                          top: -6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: const BoxDecoration(
                              color: Color(0xFFDC2626),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : '$unreadCount',
                              style: const TextStyle(fontSize: 8, color: AppColors.kWhite, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                    ],
                  ),
                  activeIcon: const Icon(Icons.notifications),
                  label: 'Alerts',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    // Start listening for incoming call notifications when user is available
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _inviteSub?.cancel();
      _incomingCallSub?.cancel();
      _seenInvites.clear();
      WebRtcSocketService.instance.unbindUser();
      if (user == null) return;

      WebRtcSocketService.instance.bindUser(user.uid);

      _incomingCallSub = WebRtcSocketService.instance.incomingCalls.listen((payload) {
        final targetUserId = payload['targetUserId']?.toString() ?? '';
        final targetUids = List<String>.from(payload['targetUids'] ?? []);
        if (targetUserId.isNotEmpty && targetUserId != user.uid) {
          return;
        }
        if (targetUids.isNotEmpty && !targetUids.contains(user.uid)) {
          return;
        }
        final callId = payload['callId']?.toString() ?? '';
        final roomId = payload['roomId']?.toString() ?? '';
        final projectId = payload['projectId']?.toString() ?? '';
        final callerId = payload['callerId']?.toString() ?? payload['senderId']?.toString() ?? '';
        final callerName = payload['callerName']?.toString() ?? 'Someone';
        final projectTitle = payload['projectName']?.toString() ?? payload['projectTitle']?.toString() ?? 'Incoming call';

        if (!mounted) return;

        showGeneralDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black.withOpacity(0.8),
          pageBuilder: (ctx, anim1, anim2) => IncomingCallOverlayScreen(
            callerName: callerName,
            projectTitle: projectTitle,
            onDecline: () {
              Navigator.of(ctx).pop();
              if (roomId.isNotEmpty && callerId.isNotEmpty) {
                WebRtcSocketService.instance.declineCall(roomId, callerId);
              }
            },
            onAccept: () {
              Navigator.of(ctx).pop();
              if (!context.mounted || projectId.isEmpty || callId.isEmpty) {
                return;
              }
              Navigator.of(context).pushNamed('/project/$projectId/workspace/calls');
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => InCallScreen(projectId: projectId, callId: callId),
                ),
              );
            },
          ),
        );
      });

      _inviteSub = FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('read', isEqualTo: false)
          .where('type', whereIn: ['call_started', 'call_scheduled'])
          .limit(30)
          .snapshots()
          .listen((snap) {
        for (final doc in snap.docs) {
          if (_seenInvites.contains(doc.id)) continue;
          _seenInvites.add(doc.id);
          // Call overlays are driven by the Socket.io stream to avoid duplicate prompts.
        }
      });
    });
  }

  @override
  void dispose() {
    _inviteSub?.cancel();
    _incomingCallSub?.cancel();
    WebRtcSocketService.instance.unbindUser();
    super.dispose();
  }
}
