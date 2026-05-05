# TeamSync Web Deployment & Manual Testing Guide

## Option 1: Local Development (Dev Mode)
This is the fastest way to test with live reload.

```bash
cd /workspaces/TeamSync
flutter run -d web
```

**What happens:**
- Opens http://localhost:56789 (or similar port) automatically
- You can edit code and see changes instantly (hot reload)
- Perfect for testing during development

---

## Option 2: Production Build (Release Mode)
This creates an optimized production build.

### Step 1: Build the Web App
```bash
cd /workspaces/TeamSync
flutter build web --release
```

**Output location:** `build/web/`
- `index.html` - Main entry point
- `main.dart.js` - Your app compiled to JavaScript
- Static assets (CSS, images, fonts)

### Step 2: Serve Locally

#### Using Python (Built-in):
```bash
cd build/web
python3 -m http.server 8080
```

#### Using Node.js `http-server`:
```bash
npm install -g http-server
cd build/web
http-server -p 8080
```

#### Using Firebase Hosting (Deploy):
```bash
firebase login
firebase deploy
```

---

## Manual Testing Checklist

### 1. **Verify Firebase Connection**
- [ ] Open browser DevTools (`F12`)
- [ ] Go to **Console** tab
- [ ] Look for "Firebase Initialized" message
- [ ] No red errors about Firebase credentials

### 2. **Test Authentication**
- [ ] Try logging in with an email
- [ ] Check if user appears in Firebase Console > Authentication
- [ ] Verify user UID matches

### 3. **Test Real-Time Data (Firestore)**
**In one window:**
1. Open your web app (http://localhost:8080)
2. Create a new project

**In another window:**
1. Open Firebase Console
2. Go to Firestore Database
3. Find your project document
4. Edit the project name
5. **Expected:** The name updates in your web app **instantly** (no page refresh)

### 4. **Browser Console Errors**
- [ ] Press `F12` → Console tab
- [ ] No CORS errors
- [ ] No "Failed to load Firebase" messages
- [ ] No undefined variable errors

### 5. **Responsive Design**
- [ ] Resize browser window (mobile view)
- [ ] Check if layout scales properly
- [ ] Test on different screen sizes

### 6. **Network Request Check**
- [ ] Open DevTools → Network tab
- [ ] Create/update a project
- [ ] You should see:
  - `firestore.googleapis.com` requests
  - Response status: **200** (success)
  - No **403** (permission denied) errors

---

## Debugging: Common Issues & Fixes

### Issue: "Firebase Initialization Failed"
**Solution:**
1. Verify `lib/firebase_options.dart` exists
2. Check project ID matches your Firebase project
3. In Firebase Console, verify Web App is registered
4. Check browser console for specific error message

### Issue: "Permission Denied" (403 error)
**Solution:**
1. Go to Firebase Console → Firestore Database
2. Click "Rules" tab
3. Ensure rules allow read/write for authenticated users
4. Current rules in `firestore.rules` already handle this

### Issue: "Cannot find 'chrome' device"
**Solution (Dev Container):**
Instead of `flutter run -d chrome`, use:
```bash
flutter run -d web
```
Then navigate to shown URL in your browser.

### Issue: "Port already in use"
**Solution:**
```bash
# Kill existing process using port 8080
lsof -i :8080
kill -9 <PID>

# Or use a different port
python3 -m http.server 9090
```

---

## Step-by-Step: First Time Running on Web

### Step 1: Clean Build
```bash
flutter clean
flutter pub get
```

### Step 2: Build for Web
```bash
flutter build web --release
```

### Step 3: Start Local Server
```bash
cd build/web
python3 -m http.server 8080
```

### Step 4: Open in Browser
```
http://localhost:8080
```

### Step 5: Open DevTools (F12)
- Console tab - check for Firebase initialization
- Network tab - verify Firestore requests
- Application tab - check localStorage for auth tokens

### Step 6: Test Real-Time Sync
1. In your app, create a project
2. In Firebase Console (Firestore), edit the project name
3. See if it updates **instantly** in your web app

---

## Deployment: Publishing to the Web

### Option A: Firebase Hosting (Recommended)
```bash
firebase login
firebase init hosting  # Select your project
firebase deploy
```

### Option B: Netlify
```bash
npm run build  # or flutter build web
netlify deploy --prod --dir build/web
```

### Option C: GitHub Pages
1. Push `build/web` to GitHub
2. Enable GitHub Pages in repository settings

---

## Advanced: Environment Variables for Web

If you need different configs for dev/prod, create:
```dart
// lib/config/environment.dart
class AppEnvironment {
  static const bool isProduction = bool.fromEnvironment('PRODUCTION', defaultValue: false);
  static const String apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8080');
}
```

Then build with:
```bash
flutter build web --dart-define=PRODUCTION=true --dart-define=API_URL=https://teamsync.app
```

---

## Monitoring: Check Build Artifacts

```bash
# Check what was generated
ls -lh build/web/

# Check total size
du -sh build/web/

# Count files
find build/web -type f | wc -l
```

---

## Quick Reference: Commands

| Task | Command |
|------|---------|
| **Run dev server** | `flutter run -d web` |
| **Build production** | `flutter build web --release` |
| **Serve build locally** | `cd build/web && python3 -m http.server 8080` |
| **Clean & rebuild** | `flutter clean && flutter pub get && flutter build web --release` |
| **Deploy to Firebase** | `firebase deploy` |
| **Check for errors** | `flutter analyze` |

---

## Video Demo: What Should Happen

1. **Load App**: You see TeamSync login screen
2. **Login**: Enter email/password
3. **Create Project**: Click "New Project" → Data appears in Firestore
4. **Real-Time Sync**: Edit project name in Firebase Console → See instant update
5. **Chat**: Messages appear in real-time for all users viewing the chat
6. **No Refresh Needed**: Everything updates without page reload

---

## Success Criteria ✅

Your web app is working correctly when:
- [ ] App loads without errors
- [ ] Firebase initializes (visible in console)
- [ ] Login/logout works
- [ ] Data appears instantly when edited in Firebase
- [ ] Network requests to `firestore.googleapis.com` succeed
- [ ] No CORS or permission errors
- [ ] Chat/notifications update in real-time
