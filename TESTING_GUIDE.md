# TeamSync - TESTING GUIDE

## 🎯 COMPREHENSIVE END-TO-END TEST

This guide walks through testing all 14 completed features. Run these tests **before deployment**.

---

## SETUP: Prerequisites

✅ Firebase project: `teamsync-6a35e`  
✅ Web app registered in Firebase Console  
✅ Firestore database deployed  
✅ Security rules deployed  
✅ Flutter web build complete  

**Start the app:**
```bash
cd /workspaces/TeamSync
flutter run -d web
# Opens http://localhost:PORT automatically
```

---

## TEST 1: Remove Static Data ✅

**Objective:** Verify no hardcoded mock data is used; all data comes from Firebase.

**Steps:**
1. Open app in browser
2. Open DevTools (F12) → Network tab
3. Observe that **no** local assets load for hardcoded project data
4. All project data comes from Firestore collection

**Expected:**
- Network shows requests to `firestore.googleapis.com`
- No cached mock data in browser storage

**Pass:** ✅ / ❌

---

## TEST 2: Firebase Collections Setup ✅

**Objective:** Verify all three collections exist and are writable.

**Steps:**
1. Go to Firebase Console → Firestore Database
2. Check collections:
   - [ ] `users` - Shows user documents
   - [ ] `projects` - Currently empty (will fill in TEST 4)
   - [ ] `joinRequests` - Currently empty (will fill in TEST 7)

**Expected:**
- All three collections exist
- Each has proper security rules applied

**Pass:** ✅ / ❌

---

## TEST 3: Project Schema Definition ✅

**Objective:** Verify project documents have complete schema.

**Steps:**
1. After TEST 4, go to Firebase Console
2. Click on a project document
3. Verify fields exist:
   - [ ] `id`
   - [ ] `title`
   - [ ] `description`
   - [ ] `createdBy` (uid)
   - [ ] `collaborators` (map)
   - [ ] `visibility` ("public" | "private")
   - [ ] `isOpenForRequests` (boolean)
   - [ ] `requiredCollaborators` (number)
   - [ ] `requiredSkills` (array)
   - [ ] `contactEmail` (string)
   - [ ] `createdAt` (timestamp)

**Expected:**
- All fields present with correct types

**Pass:** ✅ / ❌

---

## TEST 4: Create Project Flow ✅

**Objective:** Test complete project creation form with validation.

**Steps:**

1. **Navigate to Create Project:**
   - Click "Create Project" button on Home screen
   - OR from any screen: `/create-project` route

2. **Test Form Validation:**
   - [ ] Leave title empty → Click Create → Error: "Please enter project title"
   - [ ] Clear form, fill title but leave description empty → Error: "Please enter project description"
   - [ ] Fill both fields → No error

3. **Fill Complete Form:**
   - Title: `"React Native Mobile App"`
   - Description: `"Building an iOS and Android app using React Native"`
   - Contact Email: `your-email@example.com`
   - Visibility: **Public**
   - Open for Requests: **Checked**
   - Required Collaborators: `4`
   - Required Skills: Add `React Native`, `TypeScript`, `Firebase`
   - Collaborators: Empty (for now)

4. **Submit:**
   - Click "Create Project"
   - Should show loading spinner
   - After 2-3 seconds: Success snackbar "Project created successfully"
   - Auto-navigates back to Home

5. **Verify in Firebase:**
   - Go to Firebase Console → Firestore
   - Open `projects` collection
   - New document should exist with all entered data

6. **Verify in App:**
   - Go to Home screen
   - New project appears in "Your Projects" section
   - Stats updated: Total Projects = 1

**Expected:**
- Form validates correctly
- Project creates in Firebase
- UI updates in real-time
- Success message shown

**Pass:** ✅ / ❌

---

## TEST 5: Collaborator Addition by Username ✅

**Objective:** Test adding collaborators by email lookup.

**Steps:**

1. **Create second test account:**
   - Open incognito/private browser window
   - Go to app login
   - Create new account: `collaborator@example.com`
   - Note the UID (check Firebase Console → Authentication)

2. **Back to first account:**
   - Stay logged in as original creator
   - Go to Create Project → Create new project:
     - Title: `"Team Chat App"`
     - Description: `"Real-time chat application"`
     - Make it Public
   - At "Add Collaborators" step:
     - Type: `collaborator@example.com`
     - Click "Add"

3. **Verify Collaborator Added:**
   - Should see chip/tag with collaborator email
   - Can click X to remove if needed

4. **Test Duplicate Prevention:**
   - Type same email again
   - Click "Add"
   - Should see error: "User already added" or "User is already a collaborator"

5. **Test Non-existent User:**
   - Type: `nonexistent@example.com`
   - Click "Add"
   - Error: "User with email 'nonexistent@example.com' not found"

6. **Create Project:**
   - Remove the test collaborator for now
   - Create project

7. **Verify in Firebase:**
   - Open project document
   - `collaborators` field should exist (even if empty after we removed them)
   - Type: `Map<String, String>` with userId keys and role values

**Expected:**
- Collaborators lookup works
- Duplicates prevented
- Non-existent users rejected with error
- Collaborators stored in Firestore correctly

**Pass:** ✅ / ❌

---

## TEST 6: Home Screen (My Projects) & Discover Screen ✅

**Objective:** Test real-time project streaming on Home and Discover screens.

**Steps:**

### Home Screen Test:
1. **Login to first account**
2. **Go to Home → "Your Projects"**
   - Should see all projects where:
     - User is creator OR
     - User is collaborator
   - Should see stats: Total, Completed, Running, Pending

3. **Real-Time Sync Test:**
   - Open Home on two tabs/windows
   - Go to Firebase Console → Firestore → projects
   - Edit one project's title (e.g., "React Native Mobile App" → "React Native App - Updated")
   - **RESULT:** Project title updates on BOTH Home tabs automatically (no refresh needed) ✅

4. **Empty State:**
   - Create new account
   - Go to Home
   - Should see empty state: "No projects yet" with "Create Project" button

### Discover Screen Test:
1. **Go to Discover**
   - Should show all PUBLIC projects where current user is NOT a collaborator
   - Should NOT show:
     - Private projects
     - Projects user already created
     - Projects user already collaborates on

2. **Search/Filter Test:**
   - Type search term in search box
   - Projects filter by title/description in real-time

3. **Real-Time Sync:**
   - Create new public project in first account
   - Go to Discover in second account
   - New project should appear in real-time (within 1-2 seconds)

**Expected:**
- Home shows correct projects (creator + collaborator)
- Discover shows only available projects
- Real-time updates on both screens
- Search works
- Empty states show correctly

**Pass:** ✅ / ❌

---

## TEST 7: Join Request System ✅

**Objective:** Test join request creation, validation, and workflow.

**Steps:**

### Create Request:
1. **Second account:** Go to Discover screen
2. Find a public project with "Open for Requests" enabled
3. Click "Request to Join"
4. Should show: "Join request sent to [Project Name]"

5. **Verify in Firebase:**
   - Go to Firebase Console → Firestore
   - Open `joinRequests` collection
   - New document with:
     - `status`: "pending"
     - `requestedBy`: uid of second account
     - `projectId`: project id
     - `requestedByEmail` & `requestedByName`

### Test Request Validation:
1. **Second account:** Click "Request to Join" again
   - Error: "You already have a pending join request for this project"

2. **First account:** Add second account as collaborator manually (via Firebase)
3. **Second account:** Try to request again
   - Error: "You are already a collaborator on this project"

4. **Private Project:** Create private project
5. **Second account:** Try to find it in Discover
   - Should NOT appear

### Test Duplicate Prevention:
- Done above: Can't submit duplicate pending requests

**Expected:**
- Requests create in Firestore
- Validation prevents duplicates
- Validation prevents requesting own projects
- Validation prevents requesting private projects
- Status field shows "pending"

**Pass:** ✅ / ❌

---

## TEST 8: Admin Controls (Accept/Reject Manage) ✅

**Objective:** Test admin panel with join request management.

**Steps:**

### Access Admin Panel:
1. **First account (creator):** Go to Home → "Your Projects"
2. Click on a project
3. At top of screen, should see **settings icon button** (gear icon)
4. Click it → Opens ProjectAdminScreen

### Join Requests Tab:
1. Should see pending join requests (from TEST 7)
2. Each request shows:
   - User name
   - User email
   - "Accept" and "Reject" buttons

3. **Click Accept:**
   - Snackbar: "Request accepted"
   - Request disappears from list
   - Go to Firebase: Request status changed to "accepted"
   - Go to Firestore project: Second account added to `collaborators`

4. **New Request:** Second account sends new request
5. **Click Reject:**
   - Snackbar: "Request rejected"
   - Go to Firebase: Request status changed to "rejected"
   - Second account is still NOT a collaborator

### Collaborators Tab:
1. Should see list of team members
2. For each: Shows userId and role
3. Creator has "Creator" tag (can't remove)
4. Collaborators have remove (X) icon
5. **Click Remove:** Collaborator removed from project
   - That user no longer sees project in Home
   - Firestore `collaborators` map updated

### Settings Tab:
1. Toggle "Visibility" → Public ↔ Private
   - Snackbar: "Project visibility updated"
   - Firestore updated
   - If changed to Private, disappears from Discover

2. Toggle "Open for Requests" (for public projects)
   - Snackbar: "Settings updated"
   - "Request to Join" button changes availability

**Expected:**
- Admin panel accessible only to creator
- Join requests show pending requests
- Accept/Reject works in real-time
- Collaborators list and removal works
- Settings toggle works
- All changes reflected in Firestore

**Pass:** ✅ / ❌

---

## TEST 9: Role-Based UI Visibility ✅

**Objective:** Verify different UI for admin vs collaborator vs external user.

**Steps:**

### Creator/Admin View:
1. First account (creator) → Project Overview
2. Should see:
   - Project title, description
   - **Settings icon (manage button)** at top
   - Number of collaborators

3. Click settings icon → Admin panel opens ✅

### Collaborator View:
1. Second account → Home (after accepting join request)
2. Find project (now in "Your Projects")
3. Click project
4. Should see:
   - Project info
   - **NO settings icon** ← Different from creator
   - Read-only view

### External User View:
1. Third account (or incognito)
2. Go to Discover
3. Find public project
4. Should see:
   - Project info
   - "Request to Join" button (if is open for requests)
   - "Not accepting requests" button (if closed)
   - **NO settings icon**
   - **NO collaborators list**

**Expected:**
- Creator sees "Manage" button
- Collaborator doesn't see "Manage" button
- External user sees "Request to Join" (if allowed)
- Different permission levels enforced in UI

**Pass:** ✅ / ❌

---

## TEST 10: Firebase Security Rules ✅

**Objective:** Verify security rules prevent unauthorized access.

**Steps:**

### Manual Firestore Write (Should FAIL):
1. Go to Firebase Console → Firestore
2. Click on `projects` collection → Click a document
3. Try to manually edit a project created by User A
4. **Expected:** Error - Rules prevent non-admin write

### Manual Update to Collaborators (Should FAIL):
1. In same project, try to manually edit `collaborators` map
2. Add a new user directly
3. **Expected:** Error - Only code (admin function) can properly add collaborators

### Unauthorized Read Attempt (Should FAIL):
1. User B (not collaborator): Try to read private project's chat messages
2. **Expected:** Error - Rules prevent read

### Authorized Read (Should WORK):
1. User A (creator): Can read own project ✅
2. User B (collaborator): Can read shared project ✅
3. User C: Can read PUBLIC projects ✅

**Testing via Code:**
1. Open browser Console (F12)
2. Request to join private project
3. Should get error in console

**Expected:**
- Security rules are enforced
- Unauthorized operations blocked
- Authorized operations allowed

**Pass:** ✅ / ❌

---

## TEST 11: Real-Time Sync with Listeners ✅

**Objective:** Verify Firestore `.snapshots()` streams work in real-time.

**Steps:**

### Setup Multi-Window Test:
1. Open app on two browser tabs
2. Tab 1: Login as User A (creator)
3. Tab 2: Login as User B (collaborator)

### Test 1: Project Update Sync:
1. **Tab 1:** Go to project overview
2. **Tab 2:** Go to Discover
3. **Firebase Console (3rd window):** Edit project description
4. **OBSERVE:**
   - Tab 1: Description updates in real-time ✅
   - Tab 2: Description updates in Discover card ✅

### Test 2: Collaborator Addition Sync:
1. **Tab 1:** Go to Admin → Collaborators
2. **Tab 2:** Go to Home
3. **Tab 1:** Add new collaborator
4. **OBSERVE:**
   - Tab 2: New project appears in "Your Projects" (real-time) ✅

### Test 3: Join Request Sync:
1. **Tab 1:** Admin screen → Join Requests tab
2. **Tab 2:** Go to Discover → Request to join
3. **OBSERVE:**
   - Tab 1: New request appears in real-time ✅

### Test 4: Settings Change Sync:
1. **Tab 1:** Admin → Settings → Toggle visibility
2. **Firebase Console:**  Observe visibility changed
3. **Tab 2:** Discover screen
4. **OBSERVE:**
   - If changed to Private: Project disappears from Discover ✅
   - If changed to Public: Project appears ✅

**Expected:**
- All real-time streams trigger immediately
- No manual refresh needed
- Changes propagate across tabs/instances
- `.snapshots()` listeners working

**Pass:** ✅ / ❌

---

## TEST 12: Edge Cases ✅

**Objective:** Verify error handling for edge cases.

**Steps:**

### Non-Existent User:
1. Create project form
2. Add Collaborators → Type fake email
3. **Expected:** Error "User with email 'X' not found"

### Duplicate Collaborator:
1. Create project, add User A as collaborator
2. Try to add User A again
3. **Expected:** Error "User is already a collaborator"

### Duplicate Join Request:
1. Second account requests to join
2. Try to request again
3. **Expected:** Error "You already have a pending join request"

### Request Own Project:
1. Creator tries to "Request to Join" own project
2. **Expected:** Error "You are already a collaborator"

### Unauthorized Admin Access:
1. Non-creator tries to access admin panel via URL
2. **Expected:** Error or no admin controls shown

### Delete Own Account:
1. User creates and manages project
2. Firebase: Delete user account
3. Project should still exist (only creator reference, not dependent)

**Expected:**
- All edge cases have clear error messages
- No crashes
- App remains stable

**Pass:** ✅ / ❌

---

## TEST 13: UI States ✅

**Objective:** Verify empty, loading, and error states render correctly.

**Steps:**

### Empty States:
1. **New Account:** Go to Home
   - **Expected:** "No projects yet" message with "Create Project" button

2. **Empty Discover:** Create private project only
   - **Expected:** "No public projects" in Discover

3. **Admin - No Requests:** Project with no pending requests
   - **Expected:** "No pending requests" message

### Loading States:
1. **Create Project:** Fill form, submit
   - **Expected:** Loading spinner in button while creating

2. **Join Request:** Click "Request to Join"
   - **Expected:** Button shows loading state

3. **Slow Network:** Go Home (on slow 3G)
   - **Expected:** Shows CircularProgressIndicator while loading projects

### Error States:
1. **Wrong Password:** Login fail
   - **Expected:** Error message shown

2. **Invalid Email:** Create request for non-existent collaborator
   - **Expected:** Clear error message in snackbar

3. **Network Error:** Go offline, try to create project
   - **Expected:** Error message "Check your connection"

**Expected:**
- Empty states show helpful messages
- Loading states don't freeze UI
- Error states are user-friendly

**Pass:** ✅ / ❌

---

## TEST 14: Code Review ✅

**Objective:** Verify code quality and no critical errors.

**Steps:**

```bash
cd /workspaces/TeamSync

# Check for errors
flutter analyze

# Should show: "No analysis issues found" (or only lint warnings)
# No critical errors
```

**Expected:**
- ✅ No compilation errors
- ✅ No null-safety violations
- ✅ No type errors
- ⚠️ Lint warnings OK (non-blocking)

**Pass:** ✅ / ❌

---

## 📊 FINAL CHECKLIST

Print this and check off as you go:

```
FEATURE TESTING
- [ ] Remove Static Data
- [ ] Firebase Collections
- [ ] Project Schema
- [ ] Create Project Flow
- [ ] Collaborator by Username
- [ ] Home Screen + Discover
- [ ] Join Request System
- [ ] Admin Controls
- [ ] Role-Based UI
- [ ] Security Rules
- [ ] Real-Time Sync
- [ ] Edge Cases
- [ ] UI States
- [ ] Code Quality

REAL-TIME TESTING
- [ ] Multi-tab sync
- [ ] Firebase Console edits reflect in app
- [ ] Instant project updates
- [ ] Instant join request notifications

BROWSER TESTING
- [ ] F12 Console: No reds
- [ ] Network tab: All firestore.googleapis.com ✅
- [ ] Application tab: Auth tokens stored
- [ ] Responsive: Mobile view works

FIREBASE TESTING
- [ ] users collection has docs
- [ ] projects collection populated
- [ ] joinRequests collection has docs
- [ ] Security rules applied
```

---

## 🎓 DEBUGGING TIPS

If something fails:

1. **Open DevTools (F12)**
2. **Go to Console tab**
3. Look for error messages
4. Search for "error", "exception", "failed"
5. **Check Network tab:**
   - Are requests going to firestore.googleapis.com?
   - Status: 200 = success, 403 = permission denied

6. **Check Firebase Console:**
   - Is data actually being written?
   - Do security rules match code expectations?

7. **Check app logs:**
   ```bash
   flutter logs  # In terminal
   ```

---

**🎉 If all tests pass: READY FOR DEPLOYMENT!**

