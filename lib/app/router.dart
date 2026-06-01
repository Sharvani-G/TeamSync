import 'package:flutter/material.dart';
import '../app/main_shell.dart';
import '../screens/auth_gate_screen.dart';
import '../screens/create_project_screen.dart';
import '../screens/project_overview_screen.dart';
import '../screens/idea_board_screen.dart';
import '../screens/idea_board_document_screen.dart';
import '../screens/project_workspace_screen.dart';
import '../screens/demo_workspace_screen.dart';
import '../screens/track_screen.dart';
import '../screens/ai_report_screen.dart';
import '../screens/chat_home_screen.dart';
import '../screens/chat_channel_screen.dart';
import '../screens/project_call_screen.dart';
import '../screens/notifications/notifications_page.dart';
import '../screens/profile/my_profile_page.dart';
import '../screens/settings/settings_page.dart';
import '../screens/settings/privacy_settings_page.dart';
import '../screens/transactions/transaction_history_page.dart';
import '../screens/faq/faq_page.dart';
import '../screens/about/about_page.dart';
import '../screens/learning_app_ui_screen.dart';
// entry_screen is referenced indirectly by the auth gate route
import '../screens/forgot_password_screen.dart';
import '../screens/check_email_screen.dart';
import '../widgets/slide_route.dart';

Route<dynamic> generateRoute(RouteSettings settings) {
  final name = settings.name ?? '/';

  // /project/:id/idea-board/:levelId
  final ideaBoardDocMatch =
      RegExp(r'^/project/(\w+)/idea-board/(\w+)$').firstMatch(name);
  if (ideaBoardDocMatch != null) {
    return slideRoute(
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
    return slideRoute(IdeaBoardScreen(projectId: ideaBoardMatch.group(1)!), settings);
  }

  // /project/:id/workspace or /project/:id/workspace/:tab
  final workspaceMatch =
      RegExp(r'^/project/(\w+)/workspace(?:/(idea-board|chat|calls))?$')
          .firstMatch(name);
  if (workspaceMatch != null) {
    final tab = workspaceMatch.group(2);
    final initialTabIndex = switch (tab) {
      'chat' => 1,
      'calls' => 2,
      _ => 0,
    };

    return slideRoute(
        ProjectWorkspaceScreen(
          projectId: workspaceMatch.group(1)!,
          initialTabIndex: initialTabIndex,
        ),
        settings);
  }

  // /project/:id/track
  final trackMatch = RegExp(r'^/project/(\w+)/track$').firstMatch(name);
  if (trackMatch != null) {
    return slideRoute(TrackScreen(projectId: trackMatch.group(1)!), settings);
  }

  // /project/:id/ai-report
  final aiMatch = RegExp(r'^/project/(\w+)/ai-report$').firstMatch(name);
  if (aiMatch != null) {
    return slideRoute(const AIReportScreen(), settings);
  }

  // /project/:id/chat/:channelId and /projects/:id/chat/:channelId
  final chatChannelMatch =
      RegExp(r'^/projects?/(\w+)/chat/([\w-]+)$').firstMatch(name);
  if (chatChannelMatch != null) {
    return slideRoute(
        ChatChannelScreen(
          projectId: chatChannelMatch.group(1)!,
          channelId: chatChannelMatch.group(2)!,
        ),
        settings);
  }

  // /project/:id/call
  final callMatch = RegExp(r'^/project/(\w+)/call$').firstMatch(name);
  if (callMatch != null) {
    return slideRoute(ProjectCallScreen(projectId: callMatch.group(1)!), settings);
  }

  // /project/:id/chat
  final chatMatch = RegExp(r'^/projects?/(\w+)/chat$').firstMatch(name);
  if (chatMatch != null) {
    return slideRoute(ChatHomeScreen(projectId: chatMatch.group(1)!), settings);
  }

  // /project/:id
  final projectMatch = RegExp(r'^/project/(\w+)$').firstMatch(name);
  if (projectMatch != null) {
    return slideRoute(
        ProjectOverviewScreen(projectId: projectMatch.group(1)!), settings);
  }

  switch (name) {
    case '/':
      return fadeRoute(const AuthGateScreen(), settings);
    case '/main':
      return fadeRoute(const MainShell(), settings);
    case '/forgot-password':
      return slideRoute(const ForgotPasswordScreen(), settings);
    case '/check-email':
      final email = settings.arguments as String? ?? '';
      return slideRoute(CheckEmailScreen(email: email), settings);
    case '/create-project':
      return slideRoute(const CreateProjectScreen(), settings);
    case '/debug/workspace':
      return slideRoute(const DemoWorkspaceScreen(), settings);
    case '/notifications':
      return slideRoute(const NotificationsPage(), settings);
    case '/profile':
      return slideRoute(const MyProfilePage(), settings);
    case '/settings':
      return slideRoute(const SettingsPage(), settings);
    case '/settings/privacy':
      return slideRoute(const PrivacySettingsPage(), settings);
    case '/transactions':
      return slideRoute(const TransactionHistoryPage(), settings);
    case '/faq':
      return slideRoute(const FaqPage(), settings);
    case '/about':
      return slideRoute(const AboutPage(), settings);
    case '/learning-ui':
      return fadeRoute(const LearningAppUiScreen(), settings);
    default:
      return fadeRoute(const MainShell(), settings);
  }
}
