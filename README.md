# TeamSync - Team Collaboration Platform

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-blue.svg)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Latest-orange.svg)](https://firebase.google.com)

A comprehensive mobile and web team collaboration platform built with Flutter and Firebase. TeamSync enables teams to **manage projects**, **collaborate in real-time**, **communicate via channels**, and **conduct instant video calls** — all in one integrated application.

## 🎯 Key Features

### Project Management
- Create and manage multiple projects
- Assign collaborators with role-based permissions
- Track project progress with visual indicators
- Level system for achievement tracking

### Real-Time Chat System
- **Channel-based communication** (public/private channels)
- **Default #general channel** for every project
- **Instant message sync** across all devices
- Rich message attachments (files, images, documents)
- Typing indicators
- Read receipts

### Video Calling
- **In-app audio/video calling** (no external redirects)
- Instant calls with one-click dialing
- Scheduled calls with reminders
- Participant management
- Call history tracking

### User & Profile Management
- Unique usernames with validation
- Profile customization with avatar
- Change password securely
- Account settings and preferences
- Dark mode support

### Notifications
- Real-time notification system
- Call alerts and reminders
- Message notifications
- Unread message badges

## 🏗️ System Architecture

### Technology Stack

**Frontend:**
- **Flutter 3.x** - Cross-platform mobile/web UI framework
- **Dart 3.x** - Type-safe programming language
- **Material 3 Design** - Modern design system

**Backend & Infrastructure:**
- **Firebase Authentication** - Secure user authentication
- **Firestore** - Real-time NoSQL database with scalability
- **Firebase Storage** - File and media storage
- **Firebase Cloud Messaging** - Push notifications
- **Firebase Real-time Database** (optional) - For presence/status

**Architecture Patterns:**
- **StreamBuilder Pattern** - Reactive real-time updates
- **BLoC/Provider Pattern** - State management
- **Repository Pattern** - Data abstraction layer
- **Responsive Design** - Mobile-first, adaptive layouts

### Database Schema

```
projects/{projectId}
├── basic metadata (name, description, owner)
├── collaborators/ (member management)
├── channels/{channelId}
│   ├── metadata
│   ├── members/
│   └── messages/{messageId}
├── calls/{callId}
├── attachments/{attachmentId}
└── notifications/{notificationId}

users/{userId}
├── profile data
├── preferences
├── notifications/{notificationId}
└── devices/ (push notification tokens)
```

### Scalability Features

✅ **Pagination** - Load messages/content in chunks
✅ **Lazy Loading** - Defer non-critical data loading
✅ **Indexed Queries** - Optimized Firestore indexes for common queries
✅ **Batched Writes** - Combine multiple operations for efficiency
✅ **Scoped Listeners** - Only listen to relevant subcollections
✅ **In-Memory Caching** - Reduce database reads
✅ **Debounced Updates** - Prevent excessive writes

Optimized to support:
- 100+ projects per user
- 1000+ messages per channel
- Many concurrent collaborators
- Heavy attachment usage
- Simultaneous voice/video calls

## 🚀 Getting Started

### Prerequisites

- **Flutter SDK** 3.0+ ([Install](https://flutter.dev/docs/get-started/install))
- **Dart SDK** 3.0+ (comes with Flutter)
- **Android SDK** (for Android development)
- **Xcode** (for iOS development on macOS)
- **Firebase Project** ([Create Project](https://console.firebase.google.com))

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/teamsync.git
   cd teamsync
   ```

2. **Install dependencies:**
   ```bash
   flutter clean
   flutter pub get
   ```

3. **Configure Firebase:**
   - Download `google-services.json` from Firebase Console
   - Place in `android/app/` directory
   - For iOS: Download `GoogleService-Info.plist` and add to Xcode project
   - Update `lib/firebase_options.dart` with your Firebase config

4. **Run the app:**
   ```bash
   # Mobile (Android)
   flutter run -d android

   # Web
   flutter run -d chrome

   # iOS
   flutter run -d ios
   ```

## 🔧 Firebase Setup

### 1. Authentication
Enable these providers in Firebase:
- Email/Password
- Google Sign-In (optional)

### 2. Firestore Database
Create database with rules:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // See firestore.rules for full rule set
  }
}
```

### 3. Firestore Indexes
Import indexes from `firestore.indexes.json` via Firebase Console.

### 4. Storage
Create buckets:
- `teamsync-media` - for attachments, avatars, etc.

### 5. Security Rules
Apply rules from:
- `firestore.rules` - Firestore security
- `storage.rules` - Storage access control

## 📁 Project Structure

```
lib/
├── app/
│   ├── main_shell.dart       # App shell with bottom navigation
│   └── router.dart            # Navigation routing
├── screens/                   # Screen components
│   ├── home_dashboard_screen.dart
│   ├── chat_home_screen.dart
│   ├── chat_channel_screen.dart
│   ├── project_workspace_screen.dart
│   ├── profile/               # Profile module
│   ├── settings/              # Settings module
│   └── ...
├── widgets/                   # Reusable widgets
├── models/                    # Data models
├── services/                  # Firebase/business logic
│   ├── auth_service.dart
│   ├── project_service.dart
│   ├── user_profile_service.dart
│   └── ...
├── theme/                     # App theming
└── main.dart

pubspec.yaml                  # Dependencies
firestore.rules               # Firestore security
firestore.indexes.json        # Database indexes
```

## 📊 Key Services

### AuthService
- Firebase Authentication
- Login/Register
- Password reset
- Sign out

### ProjectService
- Project CRUD operations
- Collaborator management
- Real-time project updates
- Stream-based project queries

### UserProfileService
- User profile management
- Avatar upload to Firebase Storage
- Preference persistence

### File/AttachmentService
- File uploads to Firebase Storage
- Attachment metadata in Firestore
- Download/view support

## 🔄 Real-Time Systems

### Message Streaming
```dart
projectService.getChannelMessages(projectId, channelId)
  .listen((messages) {
    // Update UI with new/updated messages
  });
```

### Presence & Typing Indicators
Real-time user activity via Firestore presence system.

### Unread Counts
Tracked efficiently via document counters to avoid N+1 queries.

## 📱 Mobile Responsiveness

All screens are optimized for:
- **Phones** (320dp - 600dp)
- **Tablets** (600dp+)
- **Web** (responsive)

Using:
- `LayoutBuilder` for adaptive layouts
- `MediaQuery` for screen metrics
- `Flexible`/`Expanded` for proper space distribution
- Responsive typography scaling
- Touch-friendly spacing (min 44x44dp)

## 🧪 Testing Checklist

Before production:
- [ ] Multi-account message sync verification
- [ ] Attachment upload and download
- [ ] Incoming call notifications
- [ ] Call quality on slow networks
- [ ] Offline message persistence
- [ ] Database consistency after app restart
- [ ] Mobile layout on various screen sizes
- [ ] Dark mode switching
- [ ] Profile image upload/update
- [ ] Settings persistence

## 📈 Performance Guidelines

**Do:**
- Use pagination for lists
- Implement lazy loading
- Stream only necessary data
- Cache frequently accessed data
- Debounce text input handlers

**Don't:**
- Load entire collections globally
- Rebuild entire screens on simple updates
- Keep realtime listeners active unnecessarily
- Perform heavy operations on UI thread

## 🔐 Security Features

- Authentication via Firebase Auth
- Firestore security rules for data access control
- Role-based authorization (admin/collaborator)
- HTTPS for all connections
- Password strength validation
- Session management

## 📝 Development Workflow

1. **Create feature branch:**
   ```bash
   git checkout -b feature/your-feature
   ```

2. **Code and test locally:**
   ```bash
   flutter analyze        # Check code
   flutter test          # Run tests
   flutter run           # Test on device/emulator
   ```

3. **Commit and push:**
   ```bash
   git commit -am "Add feature description"
   git push origin feature/your-feature
   ```

4. **Create Pull Request**

## 🚨 Known Limitations & Future Work

- [ ] Complete Profile & Settings module
- [ ] Implement proper RTC (LiveKit/Agora) for video calls
- [ ] Advanced search across messages
- [ ] Message reactions and replies
- [ ] Channel permissions refinement
- [ ] Performance monitoring
- [ ] Analytics integration

## 📄 License

[Add your license here]

## 💬 Support

For issues and questions, please open an issue on GitHub.

---

**TeamSync** - Making team collaboration effortless. Built with ❤️ using Flutter.

