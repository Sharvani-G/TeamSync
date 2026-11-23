# TeamSync — Implementation & Consistency Checklist

Use this checklist to audit and verify that every screen, component, dialog, and interaction complies with the authoritative TeamSync UI/UX design system.

---

## 1. Global & Architectural Standards

- [ ] **Predominantly Light Identity**: Scaffold background uses `--dp-color-ground` (`#fcfcfd`). No leftover deep navy/black full-screen scaffolds.
- [ ] **Authoritative Colors Applied**: All colors reference centralized tokens (`--dp-color-ground`, `--dp-color-ink`, `--dp-color-ink-secondary`, `--dp-color-ground-muted`, `--dp-color-rule`, `--dp-color-accent`, `--dp-color-field`, `--dp-color-panel`).
- [ ] **Typography Loaded & Bound**:
  - Headings and displays use **Host Grotesk**.
  - Body, buttons, inputs, interface labels, and metadata use **Instrument Sans**.
- [ ] **Restrained Accent**: Electric blue (`#074ce0`) is strictly used for primary actions, active navigation, focus rings, and meaningful highlights.
- [ ] **Cards & Surfaces**:
  - All cards use white surface (`#ffffff`), 12px border radius (`--dp-radius-panel`), and 1px hairline border (`#dde0e6`).
  - No excessively rounded borders (e.g. 34px radii) or heavy dark shadows.
- [ ] **Backend Integrity**:
  - Zero mock data introduced.
  - All Firestore streams (`.snapshots()`), queries, and listeners are intact.
  - Firebase Authentication, user profiles, and session handling remain undisturbed.
  - File upload services (Cloudinary / Storage) and calling integrations (WebRTC / Jitsi) function without changes to contracts.

---

## 2. Screen-by-Screen Verification Checklist

### 2.1 Navigation & Shell
- [ ] `MainShell`: Clean light bottom nav bar with white background, subtle top hairline border (`#dde0e6`), active blue icons/labels, and high-contrast unread alert pill.

### 2.2 Authentication & Entry
- [ ] `EntryScreen`: Clean light onboarding/welcome view, elegant white card containers for Sign In and Sign Up, Host Grotesk titles, Instrument Sans form controls, electric blue submit button.
- [ ] `ForgotPasswordScreen` & `CheckEmailScreen`: Centered white card on light ground with clear instructions and primary button.

### 2.3 Home Dashboard
- [ ] `HomeDashboardScreen`:
  - Page header with 'TeamSync' in Host Grotesk Bold (`28px`).
  - Project Buckets section header with '+ New' primary button.
  - Real-time project cards with white surface, hairline border, visibility pill (Public/Private), collaborator count, and last-updated timestamp.
  - Scheduled meetings section with date/time block and active/countdown 'Join' button.
  - Polished empty states for projects and meetings.

### 2.4 Discover Screen
- [ ] `DiscoverScreen`:
  - Search field with white surface, search icon, and subtle border.
  - Public project cards with required skills tags, collaborator progress, and 'Request to Join' action.
  - Status handling: 'Pending' amber chip if already requested, 'Member' green chip if already joined.

### 2.5 Project Workspace & Overview
- [ ] `ProjectOverviewScreen`:
  - Clean app bar with project title and settings gear (for admins).
  - Project Info card and Collaborators roster with user avatars and roles.
- [ ] `ProjectWorkspaceScreen`:
  - Polished workspace cards for 'Idea Board', 'Chat', and 'Calls' with circular blue icon medallions and subtle borders.
  - Admin settings shortcut button.

### 2.6 Idea Board & Documents
- [ ] `IdeaBoardScreen`:
  - Clean list of project levels/sections with numbered avatar pills and chevron navigation.
- [ ] `IdeaBoardDocumentScreen`:
  - Toolbar with '+ Add Block' options (Title, Paragraph, File).
  - In-place editable blocks on white surfaces with hairline borders.
  - File attachment items with download buttons, file type icons, and upload progress.

### 2.7 Channel Chat
- [ ] `ChatHomeScreen`:
  - Clean channel list with hashtag icons, unread markers, and '+ Create Channel' button for admins.
- [ ] `ChatChannelScreen`:
  - Timeline on light canvas.
  - Received messages in pale grey bubbles (`#f3f4f6`), sent messages in electric blue bubbles (`#074ce0`).
  - File attachment previews and download action.
  - Clean input composer with attachment button and electric blue send button.

### 2.8 Calls & Meetings
- [ ] `CallsScreen` / `ProjectCallScreen`:
  - 'Start Instant Call' button with camera icon.
  - Schedule call form with date/time pickers and duration selector.
  - Upcoming scheduled calls list with dynamic 'Join Room' button.
  - Past call history list.

### 2.9 Project Administration
- [ ] `ProjectAdminScreen`:
  - Tab bar: Edit Project, Collaborators, Join Requests, Settings.
  - Full form editing with validation.
  - Join request management with Accept / Reject buttons.
  - Collaborator removal and danger zone.

### 2.10 User Profile, Settings, & Aux Screens
- [ ] `MyProfilePage`: User avatar, username `@handle`, full name editor dialog, project statistics, and quick navigation links.
- [ ] `SettingsPage`: Push notifications and join request alert switches.
- [ ] `PrivacySettingsPage`, `TransactionHistoryPage`, `FaqPage`, `AboutPage`: Consistent light styling, clean typography, and subtle borders.

---

## 3. Responsive & Quality Assurance

- [ ] Verified at Desktop (>1050px): Centered containers, multi-column grids where appropriate, max-width constraints.
- [ ] Verified at Tablet (760px - 1050px): 2-column grids, tightened spacing.
- [ ] Verified at Mobile (<760px): Single-column layouts, full-width touch-friendly buttons, bottom navigation.
- [ ] No horizontal scrolling on any page.
- [ ] Zero compile/runtime errors, missing assets, or unhandled exceptions.

