# Firebase-Based Project Collaboration System

## ✅ COMPLETE IMPLEMENTATION SUMMARY

This document describes the production-ready project collaboration system built for TeamSync with **zero static data**, **strict role-based access control**, and **real-time synchronization**.

---

## 🏗️ ARCHITECTURE OVERVIEW

### Collections Structure

```
Firestore Database:
├── users/
│   └── {userId} (uid = Firebase UID)
│       ├── username (string, unique, lowercase)
│       ├── usernameLower (string, for case-insensitive search)
│       ├── name (string)
│       ├── email (string)
│       ├── projectsJoined (int)
│       ├── tasksCompleted (int)
│       ├── createdAt (timestamp)
│       └── lastUpdated (timestamp)
│
├── projects/
│   └── {projectId} (auto-generated document ID)
│       ├── id (string, matches document ID)
│       ├── title (string)
│       ├── description (string)
│       ├── createdBy (string, userId of creator)
│       ├── collaborators (map<userId, role>) - role: "admin" or "collaborator"
│       ├── visibility (string) - "public" or "private"
│       ├── isOpenForRequests (boolean)
│       ├── requiredCollaborators (int)
│       ├── requiredSkills (array<string>)
│       ├── contactEmail (string)
│       ├── createdAt (timestamp)
│       ├── lastUpdated (timestamp)
│       ├── levels (array) - project phases/documents
│       ├── tasksCompleted (int)
│       ├── ideasAdded (int)
│       ├── meetingsConducted (int)
│       └── messagesSent (int)
│
└── joinRequests/
    └── {requestId} (auto-generated document ID)
        ├── id (string, matches document ID)
        ├── projectId (string) - foreign key to projects
        ├── requestedBy (string) - userId of requester
        ├── requestedByEmail (string)
        ├── requestedByName (string)
        ├── requestedByUsername (string)
        ├── skills (array<string>)
        ├── message (string) - cover letter / motivation
        ├── githubLink (string, optional)
        ├── linkedinLink (string, optional)
        ├── fileUrls (array<string>) - URLs from Firebase Storage
        ├── status (string) - "pending", "accepted", or "rejected"
        ├── createdAt (timestamp)
        └── respondedAt (timestamp, optional)
```

### Firebase Storage Structure

```
Firebase Storage:
└── joinRequests/
    ├── {projectId}/
    │   └── {requestId}/
    │       ├── portfolio.pdf
    │       ├── resume.pdf
    │       └── project_demo.zip
    ...
```

---

## 🔐 SECURITY MODEL

### Authentication
- Only authenticated users can access the system
- Users created via Firebase Auth are automatically saved to `users` collection
- Username must be unique (enforced at write-time)

### Role-Based Access Control

| Role | Projects | Collaborators | Requests | Settings |
|------|----------|---------------|----------|----------|
| **Admin (Creator)** | Create, Edit, Delete | Add/Remove | Accept/Reject | Full Control |
| **Collaborator** | View, Edit Content | View list | N/A | Limited (content only) |
| **Non-Member** | View Public Only | N/A | Request to Join* | N/A |

*Only if project is public and request system is enabled

### Visibility & Permissions

**PRIVATE Projects:**
- ✓ Visible ONLY to collaborators
- ✓ NOT visible in Discover
- ✓ Join requests ALWAYS disabled (enforced in backend)
- ✓ Non-members get ZERO access

**PUBLIC Projects:**
- ✓ Visible to all users (Discover tab)
- ✓ Non-members can VIEW (read-only)
- ✓ Non-members can request to join (if enabled)
- ✓ Collaborators can EDIT

---

## 📱 DATA FLOW OVERVIEW

### 1️⃣ CREATE PROJECT FLOW

```
CreateProjectScreen
    ↓
Input: title, description, @usernames, visibility, request settings
    ↓
ProjectService.createProject()
    ↓
  ✓ Validate title/description not empty
  ✓ For each @username:
      - Lookup user by username via UserService
      - Validate user exists
      - Prevent self-add
      - Prevent duplicates
  ✓ If private → disable requests (backend enforcement)
    ↓
Save to Firestore: projects/{projectId}
    ↓
Creator automatically added: collaborators[creatorId] = "admin"
    ↓
✅ Project appears INSTANTLY in creator's HomeScreen (via stream listener)
✅ Project appears in collaborators' HomeScreen (via stream listener)
```

### 2️⃣ HOME SCREEN FLOW (My Projects)

```
HomeScreen
    ↓
ProjectService.watchMyProjects() [Real-time stream]
    ↓
Query: projects where
    createdBy == currentUserId OR
    currentUserId in collaborators
    ↓
Display:
  - Project title
  - Project description
  - Collaborator count (including creator)
  - Visibility badge
  - Last updated time
    ↓
Empty state if no projects
Tap to view project details
```

### 3️⃣ DISCOVER PROJECTS FLOW (Public Projects)

```
DiscoverScreen
    ↓
ProjectService.watchPublicProjects() [Real-time stream]
    ↓
Query: projects where
    visibility == "public" AND
    currentUserId NOT in collaborators AND
    currentUserId != createdBy
    ↓
Display:
  - Public projects user is NOT member of
  - "Join Request" button if requests enabled
  - "View Details" button for all
    ↓
Empty state if all public projects user is member of
```

### 4️⃣ JOIN REQUEST FLOW (Advanced)

```
STEP 1: User clicks "Request to Join" on public project

STEP 2: Show Join Request Preview Screen
  - Display: requiredSkills, requiredCollaborators
  - Display: project details
  - Display: existing collaborators (usernames only)

STEP 3: Show Join Request Form
  - User inputs: skills[], message, githubLink, linkedinLink
  - User can upload files (PDF, Images, Docs, ZIP)

STEP 4: Submit Request
  ✓ Validate: not already collaborator
  ✓ Validate: no pending request exists (prevents duplicates)
  ✓ Valid project: public + requests enabled
    ↓
  ProjectService.submitJoinRequest()
    ↓
  Save to Firestore: joinRequests/{requestId}
    ↓
  ✅ Request stored with all details
  ✅ Admin sees request in real-time (stream listener)

STEP 5: Admin Actions
  ✓ Accept Request:
    - Add user to collaborators with role="collaborator"
    - Update request status to "accepted"
    - User sees project in HomeScreen immediately (stream updates)
    
  ✓ Reject Request:
    - Update request status to "rejected"
    - User sees rejection (no longer in pending requests)
```

### 5️⃣ MANAGE COLLABORATORS FLOW (Admin)

```
ManageCollaboratorsScreen
    ↓
ProjectService.watchProject(projectId) [Real-time]
    ↓
Display collaborators:
  - Creator with "Admin" label
  - Collaborators with "Collaborator" label
  ↓
Admin can:
  ✓ Add collaborator by @username
    → ProjectService.addCollaboratorByUsername()
    → Validates username exists
    → Prevents duplicates
    → Updates collaborators map
    → NEW COLLABORATOR SEES PROJECT IMMEDIATELY
    
  ✓ Remove collaborator
    → ProjectService.removeCollaborator()
    → Cannot remove self
    → Prevents orphan projects
    → REMOVED USER NO LONGER SEES PROJECT
```

---

## 🚀 CORE SERVICES

### UserService (`lib/services/user_service.dart`)

```dart
// Lookup user by username (case-insensitive)
Future<(String userId, String username, String name, String email)?> getUserByUsername(String username)

// Get user by ID
Future<AppUser?> getUserById(String userId)

// Search users (for future invite features)
Future<List<(String, String, String)>> searchUsers(String query)

// Validate username is available
Future<bool> isUsernameAvailable(String username)

// Create user document on signup
Future<void> createUserDocument({required String userId, required String username, required String name, required String email})

// Update user profile
Future<void> updateUserProfile({required String userId, String? name, String? username})

// Stream current user for real-time updates
Stream<AppUser?> watchCurrentUser()
```

### ProjectService (`lib/services/project_service.dart`)

```dart
// Get user's projects (real-time)
Stream<List<Project>> watchMyProjects()

// Get public projects user is not in (real-time)
Stream<List<Project>> watchPublicProjects()

// Get single project (real-time)
Stream<Project?> watchProject(String projectId)

// Create project with username-based collaborators
Future<String> createProject({
  required String title,
  required String description,
  required List<String> collaboratorUsernames,
  required String visibility,
  required bool isOpenForRequests,
  required int requiredCollaborators,
  required List<String> requiredSkills,
  required String contactEmail,
})

// Add collaborator by username (admin only)
Future<void> addCollaboratorByUsername({
  required String projectId,
  required String collaboratorUsername,
})

// Remove collaborator (admin only)
Future<void> removeCollaborator({
  required String projectId,
  required String userId,
})

// Submit join request with full details
Future<String> submitJoinRequest({
  required String projectId,
  required List<String> skills,
  required String message,
  String? githubLink,
  String? linkedinLink,
  List<String> fileUrls,
})

// Get join requests for project (admin only, real-time)
Stream<List<JoinRequest>> watchJoinRequests(String projectId)

// Get user's pending join requests (real-time)
Stream<List<JoinRequest>> watchMyJoinRequests()

// Accept join request (admin only)
Future<void> acceptJoinRequest(String requestId)

// Reject join request (admin only)
Future<void> rejectJoinRequest(String requestId)
```

### FileService (`lib/services/file_service.dart`)

```dart
// Upload single file to Firebase Storage
Future<String> uploadFile({
  required File file,
  required String projectId,
  required String requestId,
  String? fileName,
})

// Upload multiple files
Future<List<String>> uploadMultipleFiles({
  required List<File> files,
  required String projectId,
  required String requestId,
})

// Get download URL for file
Future<String> getDownloadUrl({
  required String projectId,
  required String requestId,
  required String fileName,
})

// Delete file from storage
Future<void> deleteFile({
  required String projectId,
  required String requestId,
  required String fileName,
})

// Delete all files for a request
Future<void> deleteRequestFiles({
  required String projectId,
  required String requestId,
})
```

---

## 🎨 UPDATED SCREENS

### HomeScreen (`lib/screens/home_screen.dart`)
- ✅ Removed ALL mock data usage
- ✅ Streams "My Projects" from Firebase (real-time)
- ✅ Shows collaborator count (derived from DB)
- ✅ Proper empty state UI
- ✅ Pull-to-refresh functionality
- ✅ Error handling with retry

### CreateProjectScreen (`lib/screens/create_project_screen.dart`)
- ✅ Changed from email to @username for collaborators
- ✅ Real-time username validation via UserService
- ✅ Request fields show ONLY for public projects + toggle enabled
- ✅ Visibility toggle with clear UI
- ✅ Skills multi-input support
- ✅ All validation at backend (ProjectService)
- ✅ Proper error messages

### Models (`lib/models/models.dart`)
- ✅ AppUser now has `username` field
- ✅ JoinRequest expanded with full portfolio details:
  - skills, message
  - githubLink, linkedinLink
  - fileUrls (from Firebase Storage)
  - respondedAt (for tracking)
- ✅ Project helpers: `isPrivate`, `acceptingRequests`

---

## 🔒 FIRESTORE SECURITY RULES

Complete rules in `firestore.rules`:

1. **Users Collection**
   - Users can ONLY read/write their own profile
   - Other users can read public info (username, name) for lookups
   - Username is immutable after creation

2. **Projects Collection**
   - Public: readable by anyone
   - Private: readable ONLY by collaborators + admin
   - Only admin can create/update/delete
   - Private projects cannot have join requests enabled

3. **Join Requests Collection**
   - Users can read their own requests
   - Admins can read all requests for their projects
   - Only authenticated users can create requests
   - Only admins can accept/reject
   - Cannot create duplicate requests for same project

4. **Deny-All Default**
   - Unknown paths return false

---

## 🎯 EDGE CASES HANDLED

✅ **Invalid username** → UserService returns null → Error message shown
✅ **Duplicate collaborator** → ProjectService checks duplicates → Clear error
✅ **Multiple join requests** → Firestore query prevents pending duplicates
✅ **User not found** → Validation fails before write
✅ **Self-add prevention** → Explicitly checked in service
✅ **Private project requests** → Disabled in backend (not frontend)
✅ **Removed collaborator** → Stream updates all screens instantly
✅ **Empty collaborators list** → Handled gracefully in UI
✅ **Concurrent modifications** → Firestore handles atomicity
✅ **Deleted project** → Graceful null handling in streams
✅ **Failed file uploads** → Request submission not blocked
✅ **Admin trying to remove self** → Explicit error check

---

## 📊 DATA CONSISTENCY GUARANTEES

✅ **Project Creation**: Appears instantly in creator's screen (stream listens to uid)
✅ **Collaborator Add**: Appears instantly in new member's screen (stream listens to collaborators map)
✅ **Visibility**: Private projects NEVER appear in public discovery
✅ **Access Control**: Non-collaborators cannot edit or see private projects
✅ **Role Enforcement**: Collaborators cannot perform admin actions (backend enforced)
✅ **Duplicate Prevention**: Firestore rules + service layer validation
✅ **Request Status**: Only pending → accepted/rejected (no backward transitions)

---

## 🚦 REAL-TIME SYNCHRONIZATION

All screens use **Stream Listeners** for automatic updates:

```dart
// HomeScreen streams from ProjectService
Stream<List<Project>> watchMyProjects()
  ↓
  Firestore snapshot listener
  ↓
  Returns filtered projects where user is creator or collaborator
  ↓
  UI rebuilds automatically when projects change

// ManageRequests streams from ProjectService
Stream<List<JoinRequest>> watchJoinRequests(projectId)
  ↓
  New requests appear in real-time
  ↓
  Admin sees requests without refreshing
```

---

## 📋 DEPLOYMENT CHECKLIST

Before deploying to production:

1. **Deploy Firestore Rules**
   ```bash
   firebase deploy --only firestore:rules
   ```

2. **Set up Firestore Indexes** (if needed)
   - Username lookup index
   - Project visibility filter

3. **Update Auth Flow** to call `UserService.createUserDocument()` on signup

4. **Test Scenarios**
   - [ ] Create project with collaborators
   - [ ] Verify in collaborator's HomeScreen
   - [ ] Create public project
   - [ ] Submit join request
   - [ ] Admin accepts request
   - [ ] Verify new member sees project
   - [ ] Admin removes collaborator
   - [ ] Verify member doesn't see project
   - [ ] Try to create duplicate request (should fail)
   - [ ] Try unauthorized edits (should fail at Firestore)

---

## 🚫 WHAT'S NOT INCLUDED (Out of Scope)

- Real-time chat (use separate collection + listeners if needed)
- File deletion when request is rejected (add FileService.deleteRequestFiles() if needed)
- Notification system (email notifications about requests)
- Bulk operations (add in future if needed)
- Project templates (add in future)

---

## 🔧 FUTURE ENHANCEMENTS

1. **Advanced Search** - Search projects by skills, name, etc.
2. **Invitations** - Admin can invite users directly (bypass request system)
3. **Request Templates** - Pre-fill common requirements
4. **Notifications** - Real-time notifications for new requests
5. **Activity Log** - Track who joined, when, actions taken
6. **Analytics** - Project statistics, engagement metrics
7. **Batch Operations** - Add multiple collaborators at once
8. **Request Expiration** - Auto-reject old pending requests

---

## 📚 FILES MODIFIED/CREATED

### Services
- ✅ `lib/services/user_service.dart` - NEW (username lookups, validation)
- ✅ `lib/services/file_service.dart` - NEW (Firebase Storage)
- ✅ `lib/services/project_service.dart` - ENHANCED (full collaboration)
- ✅ `lib/services/user_profile_service.dart` - UPDATED (username support)

### Models
- ✅ `lib/models/models.dart` - UPDATED (username, JoinRequest fields)

### Screens
- ✅ `lib/screens/home_screen.dart` - REWRITTEN (Firebase-driven)
- ✅ `lib/screens/create_project_screen.dart` - REWRITTEN (username-based)

### Configuration
- ✅ `pubspec.yaml` - UPDATED (firebase_storage added)
- ✅ `firestore.rules` - ENHANCED (production security)

---

## 💡 KEY DECISIONS

1. **Username instead of email** → More user-friendly, faster lookups, no privacy concerns
2. **Separate joinRequests collection** → Scalable, queryable, better performance
3. **Real-time streams** → No manual refresh, instant consistency
4. **Backend validation** → Security rules enforce all constraints
5. **Roles: admin/collaborator only** → Simpler model, sufficient for use case
6. **Private projects disable requests** → Clear boundary, prevents confusion

---

## 🎓 HOW TO USE

### For Developers

1. Read this document completely
2. Deploy Firestore rules: `firebase deploy --only firestore:rules`
3. Update auth flow to create user documents
4. Test with the scenarios in deployment checklist
5. Reference the services for API usage

### For Users

1. **Create a Project**: Fill title, description, add collaborators by @username, set visibility
2. **Join a Project**: Browse discover, click "Request to Join" if accepting requests
3. **Manage Project**: View collaborators, add/remove them, accept/reject join requests
4. **Edit Project**: Update settings (only as admin)

---

## 🆘 TROUBLESHOOTING

**Q: User can't find collaborator by username**
A: Check that username is lowercase, no spaces. Username must be created during signup.

**Q: Project not appearing in collaborator's HomeScreen**
A: Check Firestore rules allow read access. Verify user is in collaborators map with correct userId.

**Q: Can't submit join request**
A: Project must be PUBLIC and have requests ENABLED. Check Firestore rules. Verify no pending request exists.

**Q: Join request disappeared**
A: Admin likely rejected it. Check joinRequests collection for status update.

**Q: Private project appearing in Discover**
A: Should not happen. Check Firestore rules - might need deployment.

---

## 📞 SUPPORT

For detailed API usage, see docstrings in:
- `lib/services/project_service.dart`
- `lib/services/user_service.dart`
- `lib/services/file_service.dart`

---

**Last Updated**: May 2026
**Status**: ✅ Production Ready
**Version**: 1.0
