# TeamSync — Page-Specific UI Specifications

This document defines the exact visual architecture, hierarchy, layout composition, and responsive behavior for every screen in the TeamSync application.

---

## 1. Application Shell & Global Navigation (`MainShell`)

### 1.1 Visual Architecture & Layout
- **Ground Background**: `--dp-color-ground` (`#fcfcfd`).
- **Navigation Bar**:
  - Surface: `--dp-color-panel` (`#ffffff`).
  - Top Border: 1px hairline solid `--dp-color-rule` (`#dde0e6`).
  - Active Item: `--dp-color-accent` (`#074ce0`) with bold label typography in Instrument Sans (`13px`, weight `600`).
  - Inactive Item: `--dp-color-ink-secondary` (`#454c58`) with medium typography (`12px`, weight `500`).
  - Notification Badge: Compact 18px circle in `--dp-color-accent` or semantic red (`#dc2626`), high-contrast white text (`10px`, weight `700`).
- **Responsive Adaptations**:
  - Mobile (<760px): Native bottom navigation bar with 4 items (Dashboard, Discover, Alerts, Profile). Height: `64px`.
  - Tablet/Desktop (>760px): Clean centered content container with max-width `1100px` for optimal reading and content density.

---

## 2. Authentication Screens (`EntryScreen`, `ForgotPasswordScreen`, `CheckEmailScreen`)

### 2.1 Visual Architecture & Layout
- **Ground Surface**: Clean light canvas (`#fcfcfd`) with subtle ambient tint.
- **Form Card**:
  - Elevated white panel (`#ffffff`), `16px` corner radius, hairline border (`#dde0e6`), subtle downward shadow.
  - Width: Max `440px` centered vertically and horizontally.
- **Typography & Hierarchy**:
  - Header: Host Grotesk Bold (`28px`), tracking `-0.015em`, color `--dp-color-ink` (`#16191f`).
  - Subtitle: Instrument Sans Regular (`15px`), color `--dp-color-ink-secondary` (`#454c58`).
  - Form Labels: Instrument Sans Medium (`13px`), color `--dp-color-ink` (`#16191f`).
- **Form Controls**:
  - Fill: `--dp-color-ground-muted` (`#f3f4f6`) or pure white with `--dp-color-rule` border.
  - Focused Border: 1.5px solid `--dp-color-accent` (`#074ce0`).
  - Error Border: 1px solid `--dp-color-danger` (`#dc2626`).
- **Actions**:
  - Primary Action (Sign In / Sign Up): Electric blue button (`#074ce0`), white text, height `48px`, radius `8px`.
  - Switch Action: Instrument Sans Medium (`14px`) linking to alternate pane.

---

## 3. Home Dashboard (`HomeDashboardScreen`)

### 3.1 Visual Architecture & Layout
- **Page Header**:
  - Title: 'TeamSync' in Host Grotesk Bold (`28px`), `--dp-color-ink` (`#16191f`).
  - Subtitle: 'Collaborative projects and scheduled sessions' in Instrument Sans (`14px`).
- **Section 1 — Project Buckets**:
  - Header Row: Folder icon in blue (`#074ce0`), section title 'Project Buckets' in Host Grotesk (`18px`, weight `600`), and a '+ New' primary CTA button.
  - Project Cards:
    - White surface (`#ffffff`), `12px` border radius, hairline border (`#dde0e6`).
    - Title: Host Grotesk SemiBold (`16px`), color `--dp-color-ink`.
    - Description: Instrument Sans Regular (`14px`), max 2 lines with ellipsis, color `--dp-color-ink-secondary`.
    - Badges: Pill badge for 'Public' (soft green ground `#dcfce7`, text `#15803d`) or 'Private' (soft grey ground `#f3f4f6`, text `#454c58`).
    - Collaborator Count & Timestamp: Instrument Sans (`13px`), muted icon with metadata text.
- **Section 2 — Scheduled Meetings**:
  - Header: 'Scheduled Meetings' in Host Grotesk SemiBold (`18px`).
  - Meeting Cards:
    - Left-hand date/time block: Pale grey box with bold month/day and time.
    - Center info: Meeting title, project title, duration pill.
    - Right-hand action: Electric-blue 'Join' button (active within window) or disabled countdown badge.
- **Empty States**:
  - 'No projects yet' / 'No meetings scheduled' featuring circular muted icon, clear message, and guidance.

---

## 4. Discover Screen (`DiscoverScreen`)

### 4.1 Visual Architecture & Layout
- **Search Header**:
  - App bar with title 'Discover' in Host Grotesk (`20px`, SemiBold).
  - Search Input: White panel with search icon, placeholder 'Search public projects...', radius `10px`, hairline border.
- **Project Stream List**:
  - Project Cards:
    - Title in Host Grotesk SemiBold (`16px`).
    - Description with clean line clamping.
    - Required skills displayed as compact horizontal chips (`#f3f4f6` background, `#454c58` text, `12px`).
    - Collaborator requirement indicator: '3 / 5 collaborators'.
    - Action Button:
      - 'Request to Join' -> Secondary outline or primary blue button based on request eligibility.
      - 'Requested' -> Soft warning pill badge ('Pending', `#fef3c7`, text `#b45309`).
      - 'Member' -> Soft success pill badge ('Member', `#dcfce7`, text `#15803d`).

---

## 5. Project Workspace Hub (`ProjectWorkspaceScreen`)

### 5.1 Visual Architecture & Layout
- **Header**:
  - Back navigation button, Project Title in Host Grotesk SemiBold (`18px`), and Admin Settings gear icon (visible only to admins).
- **Workspace Navigation Cards**:
  - Replaces old dark boxes with clean, tactile white cards:
    - Height: `80px` to `88px`.
    - Border: 1px solid `--dp-color-rule` (`#dde0e6`).
    - Radius: 12px (`--dp-radius-panel`).
    - Icon Container: `44px` circular or rounded pale-blue container (`#eff6ff`) with electric blue icon (`#074ce0`).
    - Label: Host Grotesk SemiBold (`16px`), color `--dp-color-ink` (`#16191f`).
    - Subtitle: Supporting microcopy (e.g. 'Structured ideation & files', 'Channels & discussions', 'Live video & schedules').
    - Trailing Chevron: Arrow icon in `--dp-color-ink-secondary`.

---

## 6. Idea Board & Documents (`IdeaBoardScreen`, `IdeaBoardDocumentScreen`)

### 6.1 Visual Architecture & Layout
- **Idea Board Sections List**:
  - Linear list of project levels/phases (Problem Statement, Research, Design, Development, Testing).
  - Cards: White panel with order indicator pill (`1`, `2`, `3`), section title in Host Grotesk, chevron navigation.
- **Idea Board Document Editor**:
  - Action Toolbar: '+ Add Block' with options for Title, Paragraph, File Block.
  - Block Containers:
    - White cards with subtle border and clear visual separation.
    - Title Block: Editable Host Grotesk field (`20px`, weight `700`).
    - Paragraph Block: Instrument Sans multiline field (`15px`, line-height `1.6`).
    - File Block: Display attached files with file-type icons, file name, size metadata, download action, and delete button for owner.
    - Upload Progress: Linear electric blue progress indicator with percentage.

---

## 7. Collaborative Chat & Channels (`ChatHomeScreen`, `ChatChannelScreen`)

### 7.1 Visual Architecture & Layout
- **Channel List**:
  - White card container with dividers between channels.
  - Channel Item: Leading '#' symbol in electric blue, channel name in Instrument Sans Medium (`15px`).
  - Admin Action: '+ Create Channel' electric blue button at the bottom.
- **Chat Timeline**:
  - Background: Near-white ground (`#fcfcfd`).
  - Incoming Message (other members):
    - Avatar on left (`32px` circular).
    - Bubble: Pale grey ground (`#f3f4f6`), border `1px` solid `#dde0e6`, radius `12px`.
    - Text: Instrument Sans (`14.5px`), color `--dp-color-ink` (`#16191f`).
    - Timestamp: Instrument Sans (`12px`), color `--dp-color-ink-secondary`.
  - Outgoing Message (current user):
    - Aligned to right.
    - Bubble: Electric blue (`#074ce0`), radius `12px`.
    - Text: Instrument Sans (`14.5px`), color `#ffffff`.
    - Timestamp: Semi-transparent white (`12px`).
  - Attachments: Preview tile with thumbnail or file-type badge, name, download icon.
  - Composer Bar:
    - Fixed at bottom with white surface, top hairline border.
    - Attachment '+' button, text input with rounded pill shape, send icon button in electric blue.

---

## 8. Calls & Scheduling (`CallsScreen`, `ProjectCallScreen`)

### 8.1 Visual Architecture & Layout
- **Instant Call Banner**:
  - High-impact white card with electric blue accents:
    - 'Start Instant Call' button with camera/phone icon.
    - Displays active call session if one is currently live with pulsing green badge.
- **Schedule Call Form**:
  - Clean inputs for Meeting Title, Scheduled Time & Date Picker, Duration dropdown (15, 30, 45, 60 mins), and Collaborator multi-select checkboxes.
  - Action: 'Schedule Meeting' button.
- **Upcoming & Past Calls**:
  - Filter tabs or segmented control: 'Upcoming' vs 'Call History'.
  - Meeting cards showing date, duration, host, agenda, and dynamic 'Join Room' CTA.

---

## 9. Project Administration (`ProjectAdminScreen`)

### 9.1 Visual Architecture & Layout
- **Tab Bar**:
  - Clean tab navigation: Edit Project | Collaborators | Join Requests | Settings.
  - Tab Indicator: Electric blue underline or pill.
- **Edit Project**: Form with project title, description, required collaborators count, visibility toggle (Public/Private), and skill tags.
- **Collaborators**: List of current collaborators with avatars, usernames, roles (Admin / Collaborator), and remove action.
- **Join Requests**: List of incoming requests with applicant username, contact email, note, and 'Accept' (green/blue) / 'Reject' (danger outline) action buttons.
- **Settings**: Destructive actions (e.g. Delete Project) grouped in a designated Danger Zone with clear confirmation modal.

---

## 10. Notifications, Profile & Settings (`NotificationsPage`, `MyProfilePage`, `SettingsPage`)

### 10.1 Visual Architecture & Layout
- **Notifications**:
  - Segmented filter chips: 'All' and 'Unread only'.
  - 'Mark all read' action button.
  - Notification items in white cards with blue unread dot, clear type icon, message, and relative time.
- **Profile**:
  - Hero profile card with large user avatar, username `@handle`, full name, and edit name button.
  - Statistics row: Projects Joined, Tasks Completed.
  - Settings list links: Notification settings, Privacy, FAQ, About, Sign Out.
- **Settings**:
  - Clean switch tiles with Instrument Sans labels, subtle dividers, and electric blue toggle switches.

