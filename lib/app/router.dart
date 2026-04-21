import 'package:flutter/material.dart';
import '../app/main_shell.dart';
import '../screens/create_project_screen.dart';
import '../screens/project_overview_screen.dart';
import '../screens/idea_board_screen.dart';
import '../screens/idea_board_document_screen.dart';
import '../screens/track_screen.dart';
import '../screens/ai_report_screen.dart';
import '../screens/chat_home_screen.dart';
import '../screens/chat_channel_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/entry_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/reset_password_screen.dart';

Route<dynamic> generateRoute(RouteSettings settings) {
  final name = settings.name ?? '/';

  // /project/:id/idea-board/:levelId
  final ideaBoardDocMatch =
      RegExp(r'^/project/(\w+)/idea-board/(\w+)$').firstMatch(name);
  if (ideaBoardDocMatch != null) {
    return _slide(
        IdeaBoardDocumentScreen(
          projectId: ideaBoardDocMatch.group(1)!,
          levelId: ideaBoardDocMatch.group(2)!,
        ),
        settings);
  }

  // /project/:id/idea-board
  final ideaBoardMatch =
      RegExp(r'^/project/(\w+)/idea-board$').firstMatch(name);
  if (ideaBoardMatch != null) {
    return _slide(
        IdeaBoardScreen(projectId: ideaBoardMatch.group(1)!), settings);
  }

  // /project/:id/track
  final trackMatch = RegExp(r'^/project/(\w+)/track$').firstMatch(name);
  if (trackMatch != null) {
    return _slide(TrackScreen(projectId: trackMatch.group(1)!), settings);
  }

  // /project/:id/ai-report
  final aiMatch = RegExp(r'^/project/(\w+)/ai-report$').firstMatch(name);
  if (aiMatch != null) {
    return _slide(const AIReportScreen(), settings);
  }

  // /project/:id/chat/:channelId
  final chatChannelMatch =
      RegExp(r'^/project/(\w+)/chat/([\w-]+)$').firstMatch(name);
  if (chatChannelMatch != null) {
    return _slide(
        ChatChannelScreen(
          projectId: chatChannelMatch.group(1)!,
          channelId: chatChannelMatch.group(2)!,
        ),
        settings);
  }

  // /project/:id/chat
  final chatMatch = RegExp(r'^/project/(\w+)/chat$').firstMatch(name);
  if (chatMatch != null) {
    return _slide(ChatHomeScreen(projectId: chatMatch.group(1)!), settings);
  }

  // /project/:id
  final projectMatch = RegExp(r'^/project/(\w+)$').firstMatch(name);
  if (projectMatch != null) {
    return _slide(
        ProjectOverviewScreen(projectId: projectMatch.group(1)!), settings);
  }

  switch (name) {
    case '/':
      return _fade(const EntryScreen(), settings);
    case '/main':
      return _fade(const MainShell(), settings);
    case '/forgot-password':
      return _slide(const ForgotPasswordScreen(), settings);
    case '/reset-password':
      return _slide(const ResetPasswordScreen(), settings);
    case '/create-project':
      return _slide(const CreateProjectScreen(), settings);
    case '/notifications':
      return _slide(const NotificationsScreen(), settings);
    case '/profile':
      return _slide(const ProfileScreen(), settings);
    default:
      return _fade(const MainShell(), settings);
  }
}

PageRouteBuilder _slide(Widget page, RouteSettings settings) {
  return PageRouteBuilder(
    settings: settings,
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 220),
  );
}

PageRouteBuilder _fade(Widget page, RouteSettings settings) {
  return PageRouteBuilder(
    settings: settings,
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) =>
        FadeTransition(opacity: animation, child: child),
    transitionDuration: const Duration(milliseconds: 180),
  );
}
