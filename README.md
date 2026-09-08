# TeamSync

![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)
![Firebase](https://img.shields.io/badge/Firebase-Firestore%20%7C%20Auth%20%7C%20Storage-orange?logo=firebase)
![Dart](https://img.shields.io/badge/Dart-3.5.0-blue?logo=dart)
![Node.js](https://img.shields.io/badge/Node.js-18-green?logo=node.js)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Web-lightgrey)

TeamSync is a real-time team collaboration platform built with Flutter and Firebase. It gives
student and professional teams a single workspace to manage projects, communicate through
channel-based chat, share files, track progress, and conduct video meetings - without switching
between multiple tools.

## Features

- **Authentication** - Email/password login, password recovery, and email verification
- **Project Management** - Create public or private projects with configurable roles, levels, and
	idea-board sections
- **Team Discovery** - Browse and request to join public projects
- **Channel Chat** - Real-time messaging in project channels with file attachments
- **Idea Board** - Structured levels and blocks with file and document support
- **Scheduled Meetings** - Schedule calls with collaborators; join button activates 5 minutes before
	meeting time
- **Instant Calls** - Start a live call instantly; all collaborators see a Join button in real time
- **Video Meetings** - Powered by Jitsi Meet; all collaborators join the same meeting room via a
	shared link stored in Firestore
- **Push Notifications** - In-app and push alerts for meetings, messages, and project activity
- **Progress Tracking** - Tasks completed, ideas added, meetings conducted, messages sent
- **Role-based Access** - Admin, collaborator, and non-member roles enforced by Firestore rules
- **File Uploads** - Firebase Storage and Cloudinary-backed upload paths
- **AI Report Entry** - Integrated AI report generation entry point per project

The project targets Flutter web and Android today and contains generated/native scaffolding for
iOS, macOS, Linux, and Windows. The primary product code lives in `lib/`; Firebase configuration,
security rules, hosting configuration, and the optional Node.js service live at the repository
root and in `functions/`.

## Contents

- [Product overview](#product-overview)
- [Architecture](#architecture)
- [Repository layout](#repository-layout)
- [Prerequisites](#prerequisites)
- [Local setup](#local-setup)
- [Running the application](#running-the-application)
- [How the main workflows work](#how-the-main-workflows-work)
- [Firebase data model](#firebase-data-model)
- [Security model](#security-model)
- [Files and uploads](#files-and-uploads)
- [Calls and real-time signaling](#calls-and-real-time-signaling)
- [Testing and validation](#testing-and-validation)
- [Build and deployment](#build-and-deployment)
- [Environment configuration](#environment-configuration)
- [Common issues](#common-issues)
- [Development guidelines](#development-guidelines)
- [Future Enhancements](#future-enhancements)

## Product overview

### Authentication and profiles

The app starts through an authentication gate and initializes Firebase before rendering the main
application. Authenticated users have profiles with names, usernames, and contact information.
Username lookup is used when adding collaborators, so project owners do not need to manually enter
Firebase user IDs.

The app also includes password recovery, email verification, profile settings, privacy settings,
notifications, FAQ, About, and transaction-history screens.

### Projects and discovery

An authenticated user can create a project with:

- A title and description
- Public or private visibility
- An optional list of collaborators identified by username
- Required collaborator count and skills
- Contact email
- Configurable project levels
- Idea-board sections
- A setting that controls whether public users may submit join requests

The home dashboard watches projects owned by or assigned to the current user. The Discover screen
watches public projects. Both use Firestore streams, so project changes are reflected without a
manual page refresh.

### Project workspace

Each project can contain:

- An overview with project metadata and progress
- A structured idea board with levels, blocks, and attachments
- Project documents
- Channel-based chat
- Scheduled or active calls
- Progress and activity tracking
- An AI report entry point
- Admin controls for requests, collaborators, and project settings

Project roles are represented as `admin`, `collaborator`, or `nonMember`. The creator is the
project administrator. Administrators can manage membership and project settings; collaborators
can contribute to collaborative content; non-members have only the access allowed by the project's
visibility and the security rules.

### Join requests

Public projects can accept join requests. A user submits a request only when the project is public,
the owner has enabled requests, and the user is not already a collaborator. The project admin can
accept or reject pending requests. Firestore rules enforce these conditions server-side; hiding a
button in the UI is not the security boundary.

### Chat

Chat is channel-scoped. Messages belong to:

```text
projects/{projectId}/channels/{channelId}/messages/{messageId}
```

Channels also contain member documents for membership and unread state. Legacy project-level
messages under `projects/{projectId}/messages` are explicitly denied by the current rules and
should not be used for new features.

### Calls

TeamSync supports both scheduled and instant video meetings powered by Jitsi Meet.

**Scheduled meetings** are created with a title, collaborators, time, duration, and agenda. A unique
Jitsi meeting link is generated at creation time and stored in Firestore. All collaborators see the
same meeting card on their dashboard. The Join button is disabled until five minutes before the
scheduled time and opens the shared Jitsi room directly in the browser.

**Instant calls** let any project member start a live call immediately. Tapping Start Meet generates
a Jitsi link, writes an active session to Firestore, and notifies all collaborators. Every
collaborator sees a live call banner with a Join button that opens the same Jitsi room. The session
expires automatically after one hour.

Meeting links are generated once per session from the Firestore document ID, stored immediately, and
never regenerated - guaranteeing that all collaborators always join the same room.

## Architecture

```text
Flutter application (lib/)
	Screens, widgets, routing, theme
					|
					+--> Firebase Authentication
					+--> Cloud Firestore
					|      Users, projects, channels, messages, requests,
					|      notifications, calls, documents
					+--> Firebase Storage
					|      Project and chat files
					+--> Functions/HTTP upload service
					|      Signed uploads and attachment persistence
					+--> Jitsi Meet (external)
												 Shared video meeting rooms via browser links
```

### Flutter client

The application entry point is `lib/main.dart`. Startup resolves the TeamSync environment profile,
initializes Firebase, configures web auth persistence and file-picker behavior, initializes push
notifications, and then renders `ProjectSyncApp`.

The client is organized into:

- `lib/app/`: application shell and route generation
- `lib/screens/`: feature screens and pages
- `lib/services/`: Firebase access, uploads, notifications, calls, WebRTC, and settings
- `lib/models/`: domain models and role helpers
- `lib/widgets/`: reusable UI components and transitions
- `lib/theme/`: colors and Material theme configuration
- `lib/config/`: environment profile selection

`ProjectService` is the main project-domain service. It exposes real-time streams such as
`watchMyProjects`, `watchPublicProjects`, and `watchProject`, plus project creation, collaborator,
join-request, and admin operations.

### Firebase

Firebase is the system of record for authentication, Firestore data, and Storage objects. The
repository includes:

- `firebase.json` for Hosting, Functions, Firestore, Storage, and emulator settings
- `firestore.rules` for database authorization
- `firestore.indexes.json` for Firestore indexes
- `storage.rules` for file authorization
- `lib/firebase_options.dart` for platform Firebase initialization options

Hosting serves `build/web` and rewrites application routes to `index.html`, which allows Flutter
web routes to work on direct navigation.

### Node.js service

`functions/index.js` creates an Express upload app and attaches a Socket.IO server. It contains:

- A multipart `/upload` endpoint that writes files to Firebase Storage and persists attachment
	metadata in Firestore
- `/api/storage/cloudinary-signature`, protected by Firebase ID-token verification, for signed
	Cloudinary uploads
- Socket.IO events used by WebRTC and call features

`functions/server.js` runs the same Express and Socket.IO stack as a local HTTP server. The default
local port is `8080`; set `PORT` to override it.

## Repository layout

```text
.
|-- lib/                    Flutter application source
|   |-- app/                Shell and route generation
|   |-- config/             Environment profile selection
|   |-- models/             Firestore/domain models
|   |-- screens/            Product screens
|   |-- services/           Data and integration services
|   |-- theme/              Theme and colors
|   `-- widgets/            Shared widgets
|-- assets/images/          Logos and onboarding assets
|-- functions/              Node.js HTTP and Socket.IO service
|-- android/                Android project and Firebase integration
|-- ios/                    iOS project
|-- macos/                  macOS project
|-- linux/                  Linux project
|-- windows/                Windows project
|-- web/                    Flutter web shell and PWA assets
|-- test/                   Flutter unit/widget tests
|-- integration_test/       Flutter integration tests
|-- e2e/                    Node-based deployed upload test
|-- .github/workflows/      CI build and deployment workflows
|-- firebase.json           Firebase CLI configuration
|-- firestore.rules         Firestore authorization rules
|-- storage.rules           Storage authorization rules
|-- pubspec.yaml            Flutter dependencies and assets
|-- build_apk.sh            Local Android release build helper
`-- apply_cors.js           Root-level CORS utility
```

## Quick Demo Guide

This section is for evaluators and reviewers. Follow these steps to see all major features:

1. **Sign up and log in** - Create two accounts on two devices to simulate collaborators
2. **Create a project** - Add the second account as a collaborator by username
3. **Explore the workspace** - View the idea board, documents tab, and progress overview
4. **Send a chat message** - Open a channel, send a message and a file attachment; confirm both
	devices see it in real time
5. **Schedule a meeting** - Go to Calls, schedule a meeting 5 minutes from now; confirm both
	devices see the card and the Join button activates at the right time
6. **Start an instant call** - Tap Start Meet; confirm the second device sees the live call banner
	and Join button immediately; both devices join the same Jitsi room
7. **Manage the project** - Accept a join request, update project settings, and view notifications

## Prerequisites

Install the following before working on the project:

- Flutter SDK compatible with Dart `^3.5.0`
- Java 17 for Android builds
- Android Studio and Android SDK for Android development
- Node.js 18 for `functions/` and deployment workflows
- Firebase CLI for emulator and Firebase deployment work
- A Firebase project with Authentication, Firestore, Storage, and any required messaging or
	hosting services enabled

Useful checks:

```bash
flutter --version
dart --version
node --version
npm --version
firebase --version
flutter doctor
```

## Local setup

From the repository root:

```bash
flutter pub get
```

Install the Node.js service dependencies separately:

```bash
cd functions
npm ci
cd ..
```

If the root Node package is needed for the upload test or root utilities, install it as well:

```bash
npm ci
```

### Firebase project setup

1. Create or select the Firebase project used by the app.
2. Enable the authentication providers required by the login screens.
3. Create a Firestore database.
4. Create a Storage bucket.
5. Enable Cloud Messaging if push notifications are required.
6. Confirm that `lib/firebase_options.dart` contains valid options for the target platform.
7. Review `firestore.rules` and `storage.rules` before deploying them.
8. Deploy indexes and rules when working against a shared Firebase project:

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
```

Do not place service-account JSON files, private keys, Cloudinary secrets, or other credentials in
source control. Use local environment variables or your CI secret store.

## Running the application

### Flutter web

```bash
flutter run -d chrome
```

For a release build:

```bash
flutter build web --release --pwa-strategy=none
```

The output is `build/web`. This is the directory used by Firebase Hosting and the Pages workflow.

### Android

List available devices and run the app:

```bash
flutter devices
flutter run -d <device-id>
```

Build a release APK:

```bash
flutter build apk --release
```

The repository also provides `build_apk.sh`, which checks Flutter and Android SDK availability,
runs cleanup, dependency installation, tests, analysis, and the APK build:

```bash
./build_apk.sh
```

The current Android release Gradle configuration uses the debug signing configuration as a
development fallback. Configure a real release keystore before distributing an APK or App Bundle.

### Local Functions and signaling server

Run the local Node service from the repository root:

```bash
cd functions
npm ci
node server.js
```

It listens on `http://127.0.0.1:8080` by default. To use a different port:

```bash
PORT=9090 node server.js
```

The local server requires Firebase Admin credentials. For local development, use Application
Default Credentials or set `GOOGLE_APPLICATION_CREDENTIALS` to a service-account file stored
outside the repository. The code also supports `functions/serviceAccountKey.json` when present,
but that file must remain untracked and protected.

### Firebase emulators

The repository configures emulator ports in `firebase.json`:

| Service | Port |
| --- | ---: |
| Functions | 5001 |
| Firestore | 8083 |
| Storage | 9199 |
| Emulator UI | 4000 |

Start the local Firebase services with:

```bash
firebase emulators:start
```

The Flutter client must be explicitly pointed at the emulator services if emulator-backed client
testing is desired. Starting the emulators alone does not automatically redirect every Firebase
SDK call made by the app.

## How the main workflows work

### Create a project

1. The user authenticates through the auth gate.
2. The create-project form validates required fields and visibility settings.
3. Collaborator usernames are resolved through `UserService`.
4. `ProjectService` creates the project with the creator as `admin`.
5. A default `general` channel and collaborator records are created in the same batch where the
	 current implementation supports them.
6. Firestore streams update the dashboard and project views.

Private projects cannot accept public join requests. Public projects may opt in to requests.

### Join a project

1. Discover queries public projects.
2. The user selects a project that is accepting requests.
3. The client writes a pending document to `joinRequests`.
4. The project admin sees the request in the admin screen.
5. Accepting a request adds the user as a collaborator and updates the request status.
6. The user's project stream reflects membership in real time.

The Firestore rules repeat the important checks so a client cannot bypass the workflow by issuing
direct SDK writes.

### Send a chat message

1. The user opens a project channel.
2. The client reads channel membership and the channel's message subcollection.
3. New messages are written with the authenticated sender, project ID, and channel ID.
4. Firestore snapshots update every authorized participant.
5. Notification services can create unread notification records for other users.

Private channels require a member document. Public channels are available according to the project
visibility and collaborator rules.

### Add an idea-board attachment

The client associates the attachment with a project, level, and block. Depending on the active file
path, the upload is handled by Firebase Storage or the Functions/Cloudinary integration. Metadata
is then represented in the corresponding idea-board block or attachment record. The UI should only
display a file after upload and metadata persistence have completed.

### Start an instant call

1. A project member taps Start Meet on the Calls screen.
2. A unique Jitsi Meet link is generated from the Firestore session document ID.
3. The session is written to `projects/{projectId}/callSessions` with status: active, the meet
	link, caller details, and a one-hour expiry timestamp.
4. All collaborators receive a push notification.
5. The Calls screen StreamBuilder detects the active session and displays a live call banner with a
	Join button.
6. Every collaborator who taps Join is opened to the same Jitsi room in their browser.
7. The caller can tap End to mark the session as ended. The session also expires automatically after
	one hour.

### Join a scheduled meeting

1. A project admin schedules a meeting with title, collaborators, time, duration, and agenda.
2. A unique Jitsi link is generated and stored in the `callSchedules` document at creation time.
3. All collaborators see the meeting card on their dashboard immediately via Firestore streams.
4. The Join button is disabled until five minutes before the scheduled time.
5. When enabled, tapping Join opens the shared Jitsi room directly in the browser.
6. All collaborators who tap Join land in the same meeting room.

## Firebase data model

The following are the principal collections and subcollections used by the application. Individual
feature services may add fields for compatibility or migration, so update this section when the
schema changes.

```text
users/{userId}
	uid, username, name, email, profile fields

projects/{projectId}
	id, title, description, createdBy
	collaborators: { userId: "admin" | "collaborator" }
	visibility: "public" | "private"
	isOpenForRequests
	requiredCollaborators, requiredSkills, contactEmail
	levels, ideaBoardSections, ideaBoardBlocks
	tasksCompleted, ideasAdded, meetingsConducted, messagesSent
	createdAt, lastUpdated

projects/{projectId}/collaborators/{userId}
	uid, role, addedAt

projects/{projectId}/members/{userId}
	project membership data used by project features

projects/{projectId}/channels/{channelId}
	name, isPrivate, createdBy, channel metadata

projects/{projectId}/channels/{channelId}/members/{userId}
	channel membership and unread state

projects/{projectId}/channels/{channelId}/messages/{messageId}
	senderId, projectId, channelId, message content, timestamps, attachments

projects/{projectId}/documents/{documentId}
	project document content and attachment references

projects/{projectId}/ideaBoard/{levelId}/{blockId}/{fileName}
	project-scoped file records where this path is used

projects/{projectId}/callSessions/{callId}
	sessionId, meetLink, callerUid, callerName,
	status ('active' | 'ended'), startedAt,
	expiresAt (1 hour after creation), projectId

projects/{projectId}/callSchedules/{scheduleId}
	title, scheduledAt, durationMinutes, agenda,
	collaborators, meet_link, createdBy, projectId

joinRequests/{requestId}
	projectId, requestedBy, status, request details, timestamps

users/{userId}/notifications/{notificationId}
	notification data and read state

attachments/{attachmentId}
	server-persisted attachment metadata for upload flows that use Functions
```

The exact field names are defined by the Dart models and services plus the security rules. When
adding a field, update the writer, parser, rules, indexes, and tests together.

## Security model

Authorization is enforced by Firebase rules and should not rely on UI visibility alone.

### Firestore

- Authentication is required for protected operations.
- Users can manage their own profile; public profile fields may be readable for lookup purposes.
- Public projects are readable according to their visibility; private projects are limited to
	collaborators.
- Only a project admin can delete a project or manage administrative fields.
- Collaborators can update only the collaborative fields explicitly listed in the update rule.
- Channel messages require the correct project/channel relationship and authenticated sender.
- Private channel messages require channel membership.
- Join requests can be created by eligible authenticated users and resolved by project admins.
- A deny-all wildcard rule protects paths that are not explicitly defined.

### Storage

Storage paths are project-scoped. Project collaborators can write and delete project files, while
read access follows project visibility and membership. Unsupported paths are denied by the catch-all
rule.

### HTTP uploads

The `/api/storage/cloudinary-signature` route verifies a Firebase ID token before returning a signed
Cloudinary upload configuration. The legacy `/upload` route in `functions/index.js` accepts
multipart uploads and currently identifies the uploader from the `x-user-id` header; review and
harden this endpoint before exposing it to untrusted production clients.

## Files and uploads

The repository contains more than one upload path because the app has evolved across Firebase
Storage, server-proxied uploads, and Cloudinary-backed signed uploads.

### Firebase Storage paths

The current Storage rules cover paths including:

```text
project_files/{projectId}/{blockId}/{fileId}
project_chat_files/{projectId}/{messageId}/{fileId}
joinRequests/{projectId}/{requestId}/{fileName}
```

### Functions upload endpoint

The Express app accepts `multipart/form-data` at `/upload` with one or more `files` fields. Optional
metadata fields include `projectId`, `channelId`, `blockId`, `levelId`, `messageId`, and
`storagePathPrefix`. The service stores objects in the configured Firebase Storage bucket,
generates signed read URLs, and attempts to persist metadata in the `attachments` collection.

### Cloudinary signature endpoint

`POST /api/storage/cloudinary-signature` requires a Firebase Bearer token and accepts file metadata
plus a project context. It validates supported MIME types and limits files to 10 MB before returning
an upload URL, timestamp, signature, API key, and folder. Cloudinary credentials must be supplied
through protected environment variables in a production deployment.

The client-side upload URL is currently defined in `lib/config.dart`. Change it per environment;
do not rely on a temporary tunnel URL for a release build.

## Testing and validation

### Flutter tests

Run the unit and widget test suite:

```bash
flutter test
```

Run static analysis:

```bash
flutter analyze
```

Run the integration test target on a configured device or browser:

```bash
flutter test integration_test/chat_echo_test.dart
```

The integration test checks that a sender does not receive an incorrect self-echo notification.
It may require Firebase authentication and platform setup to be available in the test environment.

### Upload end-to-end test

The Node test posts `e2e/test_upload.txt` to a deployed Functions endpoint:

```bash
FIREBASE_REGION=us-central1 \
FIREBASE_PROJECT=<PROJECT_ID> \
node e2e/upload_test.js
```

The script expects the deployed URL to follow the Firebase Functions naming convention and sends
the test request with the current legacy `x-user-id` header behavior.

### Security-rule testing

Use the Firebase emulator when testing rule changes:

```bash
firebase emulators:exec "flutter test"
```

For focused rules tests, add or run a test harness that uses the Firestore emulator and asserts
both permitted and denied operations. Always test at least: outsider access to private projects,
private channel isolation, admin-only request resolution, collaborator updates, and unauthorized
Storage paths.

### Quota awareness

If the project is on the Firebase Spark plan, repeated reads, writes, deletes, or attachment tests
can consume daily quotas quickly. Prefer emulator tests for destructive or high-volume scenarios.

## Build and deployment

### Firebase Hosting

Build and deploy the Flutter web client:

```bash
flutter pub get
flutter build web --release --pwa-strategy=none
firebase deploy --only hosting
```

The Hosting configuration in `firebase.json` serves `build/web` and rewrites all routes to
`index.html`.

### Firebase Functions

Deploy the Node service after installing its dependencies:

```bash
cd functions
npm ci
firebase deploy --only functions --project <PROJECT_ID>
```

The deployment workflow uses Node 18 and expects the `FIREBASE_SERVICE_ACCOUNT` and
`FIREBASE_PROJECT` GitHub secrets. The combined deploy-and-E2E workflow also uses the optional
`FIREBASE_REGION` secret, defaulting to `us-central1`.

### Android APK and App Bundle

```bash
flutter build apk --release
flutter build appbundle --release
```

The APK workflow runs on pushes to `main` and `develop` and on pull requests targeting `main`. It
uploads the generated APK as a GitHub Actions artifact. Configure production signing before store
distribution.

### GitHub Pages

The Pages workflow builds Flutter web with `--pwa-strategy=none`, uploads `build/web`, and deploys
it through GitHub Pages on pushes to `main`. Firebase Hosting remains configured separately and can
be deployed with the Firebase CLI.

### CORS

If browser uploads fail because of bucket CORS, review `cors.json`, `functions/cors.json`, and
`scripts/set_bucket_cors.sh`. Apply CORS using the correct bucket and cloud tooling for the active
Firebase project. CORS does not replace Firebase authorization rules.

## Environment configuration

`TeamSyncEnvConfig` reads the compile-time `TEAMSYNC_PROFILE` value:

```bash
flutter run -d chrome --dart-define=TEAMSYNC_PROFILE=local
flutter build web --release --dart-define=TEAMSYNC_PROFILE=production
```

Supported values include `local`, `dev`, `development`, `production`, `prod`, and `release`. An
unknown or omitted value currently defaults to the production profile.

The profile changes the interpreted Storage bucket URI and the logged storage region label. It does
not automatically configure every Firebase SDK to use emulators. Keep Firebase project options,
server URLs, bucket configuration, and emulator settings aligned for each environment.

The current server upload base URL is in `lib/config.dart`:

```dart
static const String apiBaseUrl = '...';
```

Replace this with the correct local, staging, or deployed Functions URL as part of environment
configuration rather than editing it casually during feature work.

## Common issues

### Firebase fails during startup

- Run `flutter doctor` and confirm the target platform is configured.
- Verify `lib/firebase_options.dart` has options for the selected platform.
- Confirm Firebase services are enabled in the selected project.
- Inspect the boot logs emitted by `lib/main.dart` for the selected profile and Storage URI.

### A private project is not visible

Confirm that the authenticated UID is the creator or appears in the project's `collaborators` map.
The UI cannot make a private project visible if Firestore rules deny the read.

### Join requests cannot be submitted

The project must be public and `isOpenForRequests` must be true. The requester must not already
be a collaborator, and the request must contain the expected project and requester fields.

### Direct web routes return a blank page or 404

Use a server configuration that rewrites application routes to `index.html`. Firebase Hosting is
already configured for this behavior; verify that the deployed artifact is `build/web`.

### Uploads fail in the browser

Check the client base URL, deployed Functions availability, Firebase token handling, bucket CORS,
Storage rules, MIME type, and file-size limits. Check the browser network panel and Functions logs
together; a successful signature request does not guarantee that the subsequent upload succeeded.

### Meeting link does not open correctly

Ensure `url_launcher` is present in `pubspec.yaml` and that `launchUrl` is called with
`LaunchMode.externalApplication`. This opens the Jitsi room in the device browser rather than
attempting to open an app. If the Join button appears but does nothing, check that the `meetLink`
field is non-empty in the Firestore `callSessions` or `callSchedules` document.

### Collaborators see different meeting rooms

This means the meet link was generated at display time rather than at creation time. The link must
be generated once when the session or schedule document is created, stored in Firestore, and read by
all collaborators from the same document. Never generate a new link inside a widget build method or
StreamBuilder.

### Instant call section shows nothing

Check that the `callSessions` subcollection exists under the correct project document in Firestore.
If the collection is missing, Start Meet is not writing to Firestore successfully. Check Flutter
logs for write errors and confirm the Firestore composite index exists for status + startedAt on the
callSessions collection group.

## Development guidelines

- Keep project and access logic in services rather than duplicating Firestore queries in screens.
- Use Firestore streams for state that must update across users or tabs.
- Treat Firestore and Storage rules as part of every feature, not as deployment cleanup.
- Preserve the channel-scoped message path for new chat work.
- Validate upload completion before writing or displaying attachment metadata.
- Avoid optimistic UI state that can leak into the visible timeline when the server rejects a write.
- Add or update tests when changing role checks, request transitions, attachment behavior, or
	notification behavior.
- Keep secrets out of Dart source, JavaScript source, git history, and generated artifacts.
- Run `flutter analyze` and `flutter test` before opening a pull request.

## Future Enhancements

The following improvements are planned for production release:

- **Managed environment URLs** - Replace tunnel-based upload URLs with deployed Functions endpoints
	per environment
- **Production signing** - Configure a release keystore for Android APK and App Bundle distribution
- **Upload authentication hardening** - Derive uploader identity from verified Firebase tokens on all
	upload paths
- **Platform permissions** - Confirm notification, file, camera, and microphone permissions across
	iOS, desktop, and web
- **Emulator CI tests** - Add automated security-rule tests against the Firestore emulator in the CI
	pipeline
- **Offline support** - Improve error recovery and reconnect behavior for low-connectivity
	environments
- **File size and type expansion** - Extend supported MIME types and increase upload limits for
	production use cases
- **In-app video** - Explore native in-app video calling as an alternative to browser-based Jitsi
	rooms for a more seamless experience

## Related documentation

- [Deployment notes](README_DEPLOY.md)
- [Implementation history](README_IMPLEMENTATION.md)
- [Change history](CHANGELOG.md)
- [Flutter package manifest](pubspec.yaml)
- [Firebase CLI configuration](firebase.json)

## Team

TeamSync was built as a collaborative academic project.

| Name | Role |
|------|------|
| [Your Name] | Flutter, Firebase, Backend |
| [Teammate 2] | Flutter, UI/UX |
| [Teammate 3] | Backend, Node.js |
| [Teammate 4] | Firebase, Testing |

