# TeamSync — Android APK Manual Testing Guide

**Document Purpose**: Step-by-step manual device testing guide for validating the redesigned TeamSync Android application on physical Android devices.  
**Target Package**: `com.example.teamsync`  
**Application Title**: TeamSync  
**Design System**: Light SaaS Design System (`docs/ui-ux/design-system.md`)

---

## 1. Prerequisites & Device Configuration

### 1.1 Device Requirements
- Android Version: **Android 8.0 (API level 26) or higher** (Targeted for Android 14 / API level 34-36).
- Device Architecture: ARM64 (`arm64-v8a`) or ARM32 (`armeabi-v7a`).
- Network Connectivity: Active Wi-Fi or Mobile Data connection (required for Firebase Authentication, Firestore real-time streams, Cloudinary file uploads, and WebRTC / Jitsi Meet conferencing).

### 1.2 Android System Permissions Required
When prompted on your device, please grant the following permissions:
- **Camera**: Required for active video calls and live video streaming (`InCallScreen`).
- **Microphone / Record Audio**: Required for voice communication in WebRTC calls and meetings.
- **Notifications**: Required on Android 13+ to receive join request alerts and call invites in real-time.
- **Storage / Photos / Media**: Required for picking and uploading image attachments, project documents, and portfolio files.

---

## 2. Installation Instructions

### Method A: Direct Device Install (via Browser / File Manager)
1. Transfer the `.apk` file (`TeamSync-Android-Testing.apk`) to your phone via USB, Google Drive, or direct download.
2. Open your phone's **Files** or **Downloads** app.
3. Tap on `TeamSync-Android-Testing.apk`.
4. If prompted with *"Install unknown apps"*, tap **Settings** and toggle **"Allow from this source"**.
5. Tap **Install**, then tap **Open** once installation completes.

### Method B: Installation via ADB (Android Debug Bridge on PC)
1. Enable **Developer Options** and **USB Debugging** on your phone.
2. Connect your phone to your PC via USB.
3. Open a terminal and run:
   ```bash
   adb install -r dist/android/TeamSync-Android-Testing.apk
   ```
4. Once `Success` is returned, the app will appear in your device launcher.

---

## 3. End-to-End Manual Testing Checklist

Use the checklist below to record test results during your manual device walkthrough.

### Test Legend
- **[ PASS ]**: Feature behaved exactly as expected.
- **[ FAIL ]**: Feature malfunctioned, threw an error, or froze.
- **[ BLOCKED / UNTESTED ]**: Could not test due to missing test account or external network restriction.

---

### Section 1: Launch, Onboarding & Visual Identity

| Test ID | Test Scenario | Action to Perform | Expected Result | Result | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-01** | Cold App Launch | Tap the TeamSync launcher icon on phone. | Splash transitions cleanly into the onboarding screen on a crisp, light canvas (`#fcfcfd`). No dark flash. | `[   ]` | |
| **TC-02** | Onboarding Carousel | Swipe through all 3 onboarding slides. | Slides transition smoothly (160ms ease-out). Indicators update. Host Grotesk titles and Instrument Sans subtitles render crisply. | `[   ]` | |
| **TC-03** | Skip to Sign In | Tap "Sign In" text button in top header on any onboarding slide. | Direct animated transition to Slide 4 (`_SignInPane`). | `[   ]` | |

---

### Section 2: Authentication & Account Creation

| Test ID | Test Scenario | Action to Perform | Expected Result | Result | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-04** | Form Validation (Sign In) | Tap "Sign In" with empty email and password. | Inline red error text displayed: "Please enter your email" and "Please enter your password". | `[   ]` | |
| **TC-05** | Switch to Registration | Tap "Create one now" link at bottom of Sign In card. | Smooth transition to Slide 5 (`_RegisterPane`). | `[   ]` | |
| **TC-06** | Username Format Check | Enter an invalid username (e.g. `123_bad` or `ab`) and tap Create Account. | Error prompt: "Use 3-20 letters, numbers, or underscores" (must start with letter). | `[   ]` | |
| **TC-07** | Account Registration | Enter unique username, full name, valid email, phone, password, check Terms, and tap "Create Account". | Spinner shows; account created in Firebase Auth; Firestore user record created; navigates to `/main`. | `[   ]` | |
| **TC-08** | Password Reset Request | Tap "Forgot password?" from Sign In, enter registered email, tap "Send Reset Link". | Success snackbar displayed; screen navigates to `/check-email` showing user's email with Resend link. | `[   ]` | |
| **TC-09** | Sign In with Existing User | Enter registered email & password, tap "Sign In". | Authenticates against Firebase and opens Home Dashboard (`/main`). | `[   ]` | |

---

### Section 3: Navigation Shell & Home Dashboard

| Test ID | Test Scenario | Action to Perform | Expected Result | Result | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-10** | Bottom Navigation | Tap each tab: Projects, Discover, Notifications, Profile. | Solid white navigation bar (`#ffffff`) with 1px top hairline rule. Active tab highlights in electric blue (`#074ce0`). | `[   ]` | |
| **TC-11** | Unread Badge | Receive or generate a notification. | Red badge counter appears over the Notifications tab icon on the shell bar. | `[   ]` | |
| **TC-12** | Dashboard Metric Buckets | View My Projects on Dashboard tab. | White project cards display with Host Grotesk titles, collaborator counts, progress bars, and public/private badges. | `[   ]` | |
| **TC-13** | Upcoming Meetings List | Review upcoming meetings on dashboard. | Scheduled meetings render with live countdown / date and an electric blue "Join Meeting" pill button. | `[   ]` | |

---

### Section 4: Project Discovery & Join Requests

| Test ID | Test Scenario | Action to Perform | Expected Result | Result | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-14** | Project Search | In Discover tab, type a skill (e.g. `Flutter`) or project name. | Project list filters in real-time. Matching projects displayed with required skill chips. | `[   ]` | |
| **TC-15** | Request to Join Modal | Tap "Request to Join" on an open project. | White bottom sheet opens with project requirements, admin contact email, and application message field. | `[   ]` | |
| **TC-16** | Submit Join Request | Fill in skills and message, then tap "Submit Request". | Success snackbar; join request document created in Firestore root collection; status updates to "Request Pending". | `[   ]` | |

---

### Section 5: Project Creation & Administration

| Test ID | Test Scenario | Action to Perform | Expected Result | Result | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-17** | Open Project Creator | Tap the floating or header "+ New Project" button. | 4-card structured form displays: Basic Info, Idea Board Phases, Skills & Visibility, Collaborator Invites. | `[   ]` | |
| **TC-18** | Reorderable Phases | Add a new phase (e.g. `Deployment`) and drag reorder handle. | Phases reorder smoothly in list. Minimum 1 phase validation enforced. | `[   ]` | |
| **TC-19** | User Handle Search | In collaborator invites, type another registered `@username`. | User profile found and resolved from Firestore; card displays with user avatar and name. | `[   ]` | |
| **TC-20** | Project Creation Submit | Fill required fields and tap "Create Project Workspace". | Project document initialized in Firestore; immediate redirect into `/project/:id/workspace`. | `[   ]` | |
| **TC-21** | Project Admin Settings | In workspace, tap "Project Settings" (Admin only). | 4-tab admin interface opens: Project Details, Collaborators, Join Requests, Settings / Danger Zone. | `[   ]` | |
| **TC-22** | Manage Join Requests | In Admin tab, review pending join request. | Project admin can tap "Accept" (user immediately added to collaborators) or "Decline". | `[   ]` | |

---

### Section 6: Idea Board & Live Document Editing

| Test ID | Test Scenario | Action to Perform | Expected Result | Result | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-23** | Phase Navigation | Open Idea Board from workspace. | Horizontal phase pill bar renders numbered phases. Tapping a pill scrolls to that phase's card. | `[   ]` | |
| **TC-24** | Open Phase Document | Tap "Open Document" on a phase. | Document editor canvas opens displaying blocks for that specific phase level. | `[   ]` | |
| **TC-25** | Add Text / Heading Block | Tap "+ Text" or "+ Heading" in bottom action bar. | New editable block appears on canvas; tapping allows in-place text entry with auto-save to Firestore. | `[   ]` | |
| **TC-26** | Attach File to Document | Tap "+ Attachment" and pick a file. | File uploaded via Cloudinary attachment service; preview card with file name, type, and download icon rendered. | `[   ]` | |

---

### Section 7: Team Chat Channels & File Sharing

| Test ID | Test Scenario | Action to Perform | Expected Result | Result | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-27** | Channel List | Tap "Team Channels" from workspace. | Channel list renders with `#` hashtag icons and unread counts. | `[   ]` | |
| **TC-28** | Create Channel | Tap "+ Channel", enter channel name, tap Save. | New channel created in project subcollection and appears in list. | `[   ]` | |
| **TC-29** | Send Message | Open a channel, type message in floating pill input, tap Send. | Outgoing message renders in electric blue bubble (`#074ce0`) with white text and timestamp. | `[   ]` | |
| **TC-30** | Upload Chat Attachment | Tap paperclip icon in input bar, select an image/document. | Upload progress indicator displays; attachment card renders in chat stream with "Open" and "Download" buttons. | `[   ]` | |

---

### Section 8: Meetings & Video Calling

| Test ID | Test Scenario | Action to Perform | Expected Result | Result | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-31** | Instant Meeting (Jitsi) | Tap "Start Instant Meeting" from Calls workspace. | App invokes Jitsi Meet conference room URL (`https://meet.jit.si/teamsync-{projectId}`) in browser or Jitsi app. | `[   ]` | |
| **TC-32** | Schedule Meeting | Fill in meeting title, agenda, pick date/time, and tap Schedule. | Meeting record saved to Firestore; appears in Upcoming Meetings on Dashboard and Calls tab. | `[   ]` | |
| **TC-33** | WebRTC Video Room | Start a direct project call. | Active call stage opens; camera and microphone active; floating preview tile displays local stream; control bar has Mute, Video, Switch Camera, and End Call. | `[   ]` | |

---

### Section 9: Notifications, Profile & Settings

| Test ID | Test Scenario | Action to Perform | Expected Result | Result | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-34** | Notification Inbox | Open Notifications tab. | Real-time notification cards render with title, body, timestamp, and unread indicator dot. Filter chips (`All` / `Unread only`) filter correctly. | `[   ]` | |
| **TC-35** | Mark All Read | Tap "Mark all read" in header. | All unread indicators clear; badge count on shell tab bar resets to 0. | `[   ]` | |
| **TC-36** | Edit Profile Name | Open Profile tab, tap edit pencil next to name. | Dialog opens with current name; entering new name and tapping Save updates display name across app. | `[   ]` | |
| **TC-37** | Toggle Privacy & Alerts | Open Settings or Privacy Settings; toggle switches. | Toggles update smoothly with electric blue track; preferences persist in local storage. | `[   ]` | |
| **TC-38** | Logout & Session Clear | Tap "Log Out" on Profile tab; confirm dialog. | Session cleared locally via `AuthService`; user logged out of Firebase; app redirects to Entry screen. | `[   ]` | |

---

## 4. Test Summary & Defect Reporting

When completing your manual test pass, please record any bugs or observations below:

| Defect # | Screen / Area | Severity (Low/Med/High) | Description & Steps to Reproduce |
| :--- | :--- | :--- | :--- |
| **D-01** | | | |
| **D-02** | | | |
| **D-03** | | | |

---

**Report Completed By**: _____________________________  
**Date Tested**: _____________________________  
**Device Model & OS**: _____________________________

