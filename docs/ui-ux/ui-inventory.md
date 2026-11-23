# TeamSync — Complete UI & Route Inventory

This inventory documents all existing screens, modal dialogs, bottom sheets, navigation patterns, and reusable components currently present in the TeamSync codebase.

---

## 1. Top-Level Routes & Screens

| Route / Path | Screen Class | Purpose | Data Dependencies | Key Actions |
|---|---|---|---|---|
| `/` | `AuthGateScreen` (`auth_gate_screen.dart`) | Bootstrap gate, auth state listener, web OAuth fragment parser, deep-link router | `FirebaseAuth.instance`, `UserService`, `UserProfileService` | Redirect to `/main`, deep-links, or `EntryScreen` |
| `/` (unauthenticated) | `EntryScreen` (`entry_screen.dart`) | Onboarding showcase, Sign In pane, Sign Up registration pane | `FirebaseAuth`, `UserService`, `FirebaseFirestore` | Onboarding carousel, Login with email/pass, Register new user |
| `/main` | `MainShell` (`main_shell.dart`) | Application shell, bottom nav bar, incoming call overlay listener, unread count badge | `ProjectService.watchUnreadNotificationCount()`, `WebRtcSocketService` | Switch tabs: Dashboard (0), Discover (1), Alerts (2), Profile (3) |
| Tab 0 | `HomeDashboardScreen` (`home_dashboard_screen.dart`) | Personal project bucket, upcoming scheduled meetings list, new project button | `ProjectService.watchMyProjects()`, `ProjectService.watchMyScheduledMeetings()` | Open project workspace, create project, join scheduled meeting |
| Tab 1 | `DiscoverScreen` (`discover_screen.dart`) | Public project search, filter by title, request to join projects | `ProjectService.watchPublicProjects()`, `ProjectService.watchMyJoinRequests()` | Search query, submit join request with contact note |
| Tab 2 | `NotificationsPage` (`notifications/notifications_page.dart`) | Personal notification inbox, filter all/unread, mark all as read | `NotificationService.watchMyNotifications()`, `NotificationService.markAllNotificationsRead()` | Mark all read, tap notification to navigate to target project/call |
| Tab 3 | `MyProfilePage` (`profile/my_profile_page.dart`) | Current user profile, display name editor, project stats, sign out, settings link | `UserProfileService.watchCurrentUser()`, `AuthService.signOutAndClearSession()` | Edit display name dialog, sign out, navigate to `/settings` |

---

## 2. Project-Scoped Workspaces & Sub-Features

| Route / Path | Screen Class | Purpose | Data Dependencies | Key Actions |
|---|---|---|---|---|
| `/create-project` | `CreateProjectScreen` (`create_project_screen.dart`) | Multi-field project builder with collaborator email/username lookup, skill chips, custom sections | `ProjectService.createProject()`, `UserService.getUserByUsername()` | Add skills, custom levels, add collaborator by username, submit form |
| `/project/:id` | `ProjectOverviewScreen` (`project_overview_screen.dart`) | Project metadata card, collaborator roster, admin settings entry | `ProjectService.watchProject(id)`, `UserService.getUsersByIds()` | View info, navigate to Admin Screen (if admin) |
| `/project/:id/workspace` | `ProjectWorkspaceScreen` (`project_workspace_screen.dart`) | Hub for project workspace features with navigation tiles for Idea Board, Chat, Calls | `ProjectService.watchProject(id)` | Navigate to Idea Board, Channel Chat, Calls, or Project Admin |
| `/project/:id/idea-board` | `IdeaBoardScreen` (`idea_board_screen.dart`) | Section cards list for idea board (Problem Statement, Research, Design, Dev, etc.) | `ProjectService.watchProject(id)` | Tap section card to open section block document |
| `/project/:id/idea-board/:levelId` | `IdeaBoardDocumentScreen` (`idea_board_document_screen.dart`) | Block-based idea editor (Title, Paragraph, File attachments) | `ProjectService.watchIdeaBoardBlocks()`, `AttachmentService` | Add block, edit content in place, attach files via Cloudinary/Storage, delete block |
| `/project/:id/chat` | `ChatHomeScreen` (`chat_home_screen.dart`) | Project channels list, create new channel (admin only) | `ProjectService.watchProjectChannels(id)` | Select channel to open chat, open create channel modal sheet |
| `/project/:id/chat/:channelId` | `ChatChannelScreen` (`chat_channel_screen.dart`) | Real-time chat timeline, message bubble list, text input, file attachments, load more | `ProjectService.watchChannelMessages()`, `AttachmentService` | Send text message, attach image/file, reply to message, load older messages |
| `/project/:id/workspace/calls` / `/project/:id/call` | `CallsScreen` (`calls_screen.dart`) & `ProjectCallScreen` | Instant video call trigger, call scheduling form, upcoming meetings list, call history | `ProjectService.watchProjectCallSchedules()`, `watchProjectCallHistory()`, `JitsiMeet` / `WebRTC` | Instant start call, schedule call with time/agenda, join active call (active 5 min prior) |
| `/project/:id/track` | `TrackScreen` (`track_screen.dart`) | Visual progress tracker, task/idea/meeting metrics, level completion percentage | `ProjectService.watchProject(id)` | View metric cards, observe overall project progress bar |
| `/project/:id/ai-report` | `AIReportScreen` (`ai_report_screen.dart`) | AI generated weekly summary, key milestone highlights | Static / service-generated weekly summary model | Copy summary, view milestone bullet points |
| Modal / Push | `ProjectAdminScreen` (`project_admin_screen.dart`) | Tabbed administration screen: Edit Project, Collaborators, Join Requests, Settings | `ProjectService.updateProject()`, `watchJoinRequests()`, `acceptJoinRequest()`, `rejectJoinRequest()` | Update project info, remove collaborator, accept/reject join requests, delete project |
| Modal / Push | `JoinRequestScreen` (`join_request_screen.dart`) | Detailed join request review modal | `ProjectService.watchJoinRequests()` | Accept request, reject request |

---

## 3. Account, Settings, and Utility Screens

| Route / Path | Screen Class | Purpose | Data Dependencies |
|---|---|---|---|
| `/settings` | `SettingsPage` (`settings/settings_page.dart`) | Notification preferences, toggle push alerts, toggle join request alerts | `SettingsService.instance` |
| `/settings/privacy` | `PrivacySettingsPage` (`settings/privacy_settings_page.dart`) | Privacy preferences, profile visibility controls | `SettingsService.instance` |
| `/transactions` | `TransactionHistoryPage` (`transactions/transaction_history_page.dart`) | Transaction and activity logs | Activity log models |
| `/faq` | `FaqPage` (`faq/faq_page.dart`) | Frequently asked questions accordion | Static FAQ items |
| `/about` | `AboutPage` (`about/about_page.dart`) | App version info, licenses, about TeamSync | App metadata |
| `/forgot-password` | `ForgotPasswordScreen` (`forgot_password_screen.dart`) | Password reset request form via email | `FirebaseAuth.sendPasswordResetEmail()` |
| `/check-email` | `CheckEmailScreen` (`check_email_screen.dart`) | Email dispatch confirmation screen | Nav arguments |
| Overlay Dialog | `IncomingCallOverlayScreen` (`incoming_call_overlay_screen.dart`) | Full-screen incoming call invitation dialog | `WebRtcSocketService` stream |
| Active Call | `InCallScreen` (`in_call_screen.dart`) | Active video/audio call view | WebRTC / Jitsi meet stream |
| Modal | `UsernameRepairScreen` (`username_repair_screen.dart`) | On-the-fly username setup for accounts missing username | `UserService.updateUsername()` |

---

## 4. Reusable Components & Sub-Views

| Component Name | Source File | Existing Purpose | Redesign Strategy |
|---|---|---|---|
| `SimpleAppBar` | `widgets/shared_widgets.dart` | Header bar with back button and title | Redesign with white surface, hairline border, Host Grotesk title |
| `ProjectCard` | `widgets/shared_widgets.dart` | Project summary card with metadata & visibility badge | White panel, 12px radius, hairline border, Electric blue accent on tap |
| `UserAvatar` | `widgets/shared_widgets.dart` | User avatar circle with initial fallback or image | Muted circle background, bold initials, clean border |
| `SectionHeader` | `widgets/shared_widgets.dart` | Uppercase section header label | Host Grotesk, 12px tracking, `--dp-color-ink-secondary` |
| `EmptyState` | `widgets/shared_widgets.dart` | Visual empty state with circular icon, title, subtitle | Subtle pale icon circle (`--dp-color-ground-muted`), Host Grotesk title |
| `NotificationItemWidget` | `widgets/notification_item_widget.dart` | Single notification row with unread dot & timestamp | White panel or subtle row, bold unread indicator, timestamp formatting |
| `_WorkspaceButton` | `screens/project_workspace_screen.dart` | Large navigation card for Idea Board, Chat, Calls | White panel with subtle border, 12px radius, icon with blue accent |
| `_ScheduledMeetingCard`| `screens/home_dashboard_screen.dart` | Meeting card with dynamic 'Join' countdown | White panel, time badge, electric-blue Join button when active |
| `_DiscoverCard` | `screens/discover_screen.dart` | Public project card with skills chips and Join Request button | White card, skills chips in pale-grey ground, secondary action button |

