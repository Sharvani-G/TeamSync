# Project Retrieval Testing & Verification

## Change Summary

Fixed `watchMyProjects()` stream in `ProjectService` to properly handle:
1. ✅ Projects created by user
2. ✅ Projects where user is a collaborator  
3. ✅ Real-time updates for both types
4. ✅ Deduplication of projects

## Technical Fix

**File**: `/workspaces/TeamSync/lib/services/project_service.dart`

**Issue**: Previous implementation used `.asyncMap()` which only triggered once when created projects changed, missing real-time updates for collaborator projects.

**Solution**: 
- Implemented dual stream listening using `StreamController`
- Both "created projects" and "all projects" streams are now monitored simultaneously
- Combined results emit whenever either stream updates
- Proper cleanup on stream cancellation

## How to Test

### 1. Requirements Met ✅
- [x] Listens to projects created by user in real-time
- [x] Listens to all projects and filters for collaborators in real-time
- [x] Combines both streams properly
- [x] Emits deduplicated list when either stream updates
- [x] Handles errors gracefully
- [x] Cleans up subscriptions on stream cancel

### 2. End-to-End Test Steps

#### Test Case 1: View Own Projects
1. Login as User A
2. Create 2 projects (Project 1, Project 2)
3. Go to "My Projects" screen
4. ✅ Both projects should appear immediately

#### Test Case 2: View Shared Projects
1. Login as User A
2. Create Project 3
3. Add User B as collaborator to Project 3
4. Save Project 3
5. Login as User B
6. Go to "My Projects"
7. ✅ Project 3 should appear (even though User B is not the creator)

#### Test Case 3: Real-Time Updates
1. User A and User B both logged in on separate browsers
2. User A creates Project 4
3. User A navigates to "My Projects"
4. ✅ Project 4 appears immediately
5. User A adds User B as collaborator to Project 4
6. User B's "My Projects" screen updates automatically
7. ✅ Project 4 now appears in User B's screen without refreshing

#### Test Case 4: Current Issue - 3 Projects Not Showing
Your scenario: You have 3 projects but they don't appear in home screen.

**Diagnostic Steps**:
```dart
// Add this helper to check status:
Future<void> debugProjectRetrieval() async {
  final authUser = FirebaseAuth.instance.currentUser;
  if (authUser == null) {
    print('❌ Not logged in');
    return;
  }
  
  print('📋 Debugging project retrieval for: ${authUser.uid}');
  
  // Check created projects
  final created = await FirebaseFirestore.instance
      .collection('projects')
      .where('createdBy', isEqualTo: authUser.uid)
      .get();
  print('✅ Created by me: ${created.docs.length} projects');
  
  // Check all projects
  final all = await FirebaseFirestore.instance
      .collection('projects')
      .get();
  print('✅ Total projects in DB: ${all.docs.length}');
  
  // Check where I'm a collaborator
  int collaboratingCount = 0;
  for (final doc in all.docs) {
    final data = doc.data();
    final collaborators = data['collaborators'] as Map<String, dynamic>? ?? {};
    if (collaborators.containsKey(authUser.uid)) {
      collaboratingCount++;
      print('  - Collaborator on: ${data['title']}');
    }
  }
  print('✅ Collaborating on: $collaboratingCount projects');
}
```

### 3. Expected Data Structure

Projects in Firebase should have:
```json
{
  "id": "project-id-123",
  "title": "Project Name",
  "description": "Project description",
  "createdBy": "user-id-of-creator",
  "collaborators": {
    "user-id-2": "collaborator",
    "user-id-3": "collaborator"
  },
  "visibility": "public",
  "isOpenForRequests": false,
  "levels": [...],
  "createdAt": Timestamp,
  "lastUpdated": Timestamp
}
```

### 4. Possible Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| 3 projects don't show | createdBy field missing | Ensure projects have `createdBy` field set to creator's uid |
| 3 projects don't show | Data type mismatch | Verify `createdBy` is a string, not an object |
| 3 projects don't show | collaborators is wrong type | Ensure `collaborators` is a Map<string, dynamic>, not an array |
| Stream never emits | Auth not initialized | Check FirebaseAuth is initialized before stream subscribes |
| Stream emits empty | Parse error | Check `_parseProject()` doesn't throw exceptions |

## Code Changes Made

### Before (Broken):
```dart
Stream<List<Project>> watchMyProjects() {
  return _auth.authStateChanges().asyncExpand((authUser) {
    if (authUser == null) return Stream.value([]);
    
    // Only listens to created projects stream
    // colaborator projects only checked ONCE
    return createdByStream.asyncMap((createdSnapshot) async {
      final allProjectsSnapshot = await _firestore.collection('projects').get();
      // ... parsing ...
    });
  });
}
```

### After (Fixed):
```dart
Stream<List<Project>> watchMyProjects() {
  return _auth.authStateChanges().asyncExpand((authUser) {
    if (authUser == null) return Stream.value([]);
    
    final controller = StreamController<List<Project>>();
    
    // BOTH streams listened continuously
    final createdByStream = _firestore
        .collection('projects')
        .where('createdBy', isEqualTo: authUser.uid)
        .snapshots();
    
    final allProjectsStream = _firestore
        .collection('projects')
        .snapshots();
    
    // Emit combined results whenever either updates
    createdByStream.listen(...);
    allProjectsStream.listen(...);
    
    return controller.stream;
  });
}
```

## Verification Checklist

After deploying, verify:
- [ ] Home screen loads without errors
- [ ] "My Projects" shows all created projects
- [ ] "My Projects" shows all projects where user is collaborator
- [ ] New projects appear in real-time when created
- [ ] New collaborators appear without page refresh
- [ ] Projects properly sync across multiple open instances

## Support

If you still don't see projects after this fix:
1. Check Firebase Firestore for the 3 projects
2. Verify `createdBy` field matches current user's uid OR user appears in `collaborators` map
3. Check browser console for any error messages
4. Try logging out and back in
5. Clear browser cache: DevTools → Application → Clear Storage

