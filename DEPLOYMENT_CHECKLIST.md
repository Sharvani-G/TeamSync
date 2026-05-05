# TeamSync - DEPLOYMENT CHECKLIST

## 🚀 PRE-DEPLOYMENT VERIFICATION

Complete this checklist before deploying to production.

---

## ✅ CODE QUALITY

- [ ] `flutter analyze` runs with no critical errors
- [ ] No null-safety violations
- [ ] All imports resolved
- [ ] No unused imports
- [ ] Code formatted: `flutter format lib/`

**Verify:**
```bash
cd /workspaces/TeamSync
flutter analyze
flutter format lib/ -l 100
```

---

## ✅ BUILD VERIFICATION

- [ ] Web build completes without errors
- [ ] No warnings in build output
- [ ] Build artifacts exist: `build/web/`

**Verify:**
```bash
cd /workspaces/TeamSync
flutter clean
flutter pub get
flutter build web --release
```

**Expected Output:**
```
✓ Built build/web
```

---

## ✅ FIREBASE CONFIGURATION

### In Firebase Console (teamsync-6a35e):

- [ ] **Web App Registered**
  - Settings → Project settings → Apps → Web app exists
  - Has valid API keys

- [ ] **Firestore Database**
  - Database created and active
  - Region: `us-central1` (or your choice)
  - Mode: Production

- [ ] **Authentication**
  - Email/Password enabled
  - (Optional) Google Sign-in enabled
  - (Optional) Other providers configured

- [ ] **Security Rules Deployed**
  - Go to Firestore → Rules tab
  - Current rules exactly match [firestore.rules](firestore.rules)
  - Published (not in draft)

**Verify Rules:**
```
- Collections: users, projects, joinRequests, exist
- Read/Write checks present for each
- Admin-only operations protected
- All paths covered with "deny all other access"
```

- [ ] **Storage (if needed)**
  - If using file uploads later, configure
  - Create bucket: `gs://teamsync-6a35e.appspot.com`

---

## ✅ CONFIG FILES

- [ ] **firebase_options.dart** exists and correct
  - Located: `lib/firebase_options.dart`
  - Project ID: `teamsync-6a35e`
  - Web config present
  - Android config present (with placeholders OK)
  - iOS config present (with placeholders OK)

- [ ] **pubspec.yaml** has all dependencies
  ```yaml
  firebase_core: ^4.7.0
  firebase_auth: ^6.4.0
  cloud_firestore: ^6.3.0
  ```

- [ ] **.env** (if using environment variables)
  - Not uploaded to repo
  - Secrets not in code
  - Only in environment

---

## ✅ SECURITY

- [ ] **No hardcoded secrets in code**
  - Search codebase: No API keys visible
  - Search codebase: No passwords

- [ ] **Firebase Security Rules deployed**
  - Authenticate-only access
  - Role-based enforcement
  - Field-level validation
  - Delete operations protected

- [ ] **Web App authenticated only**
  - Anonymous access disabled
  - Emulator disabled in production

- [ ] **CORS configured** (if needed)
  - Firebase default CORS OK for web

---

## ✅ DATABASE SETUP

### Firestore Collections Created (auto-created):

- [ ] **users**
  - Created first time user data is written
  - Security rule: User can only read/write own doc

- [ ] **projects**
  - Created first time project is created
  - Security rule: Admin can write, auth can read public

- [ ] **joinRequests**
  - Created first time request sent
  - Security rule: Requester can create, admin can update

**Test:** Create a test project in app to ensure collections auto-create correctly.

---

## ✅ TESTING BEFORE DEPLOY

**Run TESTING_GUIDE.md checklist:**

- [ ] All 14 feature tests pass
- [ ] Real-time sync verified (TEST 11)
- [ ] Security rules tested (TEST 10)
- [ ] Edge cases handled (TEST 12)
- [ ] UI states correct (TEST 13)
- [ ] No console errors (F12)

---

## 🔧 DEPLOYMENT OPTIONS

### Option 1: Firebase Hosting (Recommended)

**Setup Firebase CLI:**
```bash
npm install -g firebase-tools
firebase login
cd /workspaces/TeamSync
firebase init hosting  # Follow prompts
```

**Deploy:**
```bash
flutter build web --release
firebase deploy
```

**Verify:** Visit `https://teamsync-6a35e.web.app`

**DNS (Optional):** Add custom domain in Firebase Console → Hosting → Add custom domain

---

### Option 2: Other Hosting Providers

#### Netlify:
```bash
npm install -g netlify-cli
flutter build web --release
netlify deploy --prod --dir build/web
```

#### GitHub Pages:
```bash
cd build/web
git add .
git commit -m "Build for deployment"
git push origin deploy-branch
# Enable GitHub Pages in repo settings
```

#### Traditional Server:
```bash
# Copy build/web contents to server
scp -r build/web/* user@server:/var/www/teamsync
```

---

## 📊 POST-DEPLOYMENT

### Day 1 Checks:

- [ ] **App loads without errors**
  - Visit `https://teamsync-6a35e.web.app`
  - F12 Console: No red errors
  - Login works

- [ ] **Firebase connection active**
  - Network tab shows `firestore.googleapis.com` requests
  - Status code: 200 (all requests successful)

- [ ] **Real-time sync works**
  - Create project → Appears in Firestore
  - Edit in Firebase Console → See instant update in app
  - No refresh needed

- [ ] **Admin features work**
  - Create project, accept join request
  - Admin panel accessible

---

### Ongoing Monitoring:

**Firebase Console → Monitoring:**

- [ ] **Firestore Usage**
  - Monitor read/write operations
  - Check quota usage
  - Set up billing alerts

- [ ] **Authentication**
  - Monitor new user signups
  - Check for blocked IPs/suspicious activity

- [ ] **Performance**
  - Monitor latency
  - Check for timeouts
  - Review error rates

**Set up Alerts:**
```
Firebase Console → Project settings → Integrations
Enable: Email alerts for quota usage
```

---

## 🐛 ROLLBACK PLAN

If deployment fails:

1. **Stop traffic to new version**
   - Firebase Hosting: Revert to previous version
   - GitHub Pages: Revert commit
   - Server: Restore previous build

2. **Investigate error**
   - Check Firebase Console logs
   - Check browser console (F12)
   - Review deployment logs

3. **Fix and redeploy**
   - Fix issue locally
   - Test thoroughly
   - Deploy again

---

## 📝 DEPLOYMENT LOG

Record your deployment details:

```
Deployment Date: _________________
Deployed To: _________________
Build Version: _________________
Firebase Project: teamsync-6a35e
App URL: _________________

Issues Encountered: _________________

Approved By: _________________
Deployed By: _________________
```

---

## ✨ SUCCESS CRITERIA

Deployment is **successful** when:

✅ App loads in browser  
✅ No console errors (F12)  
✅ Login works  
✅ Create project works  
✅ Data appears in Firestore immediately  
✅ Real-time updates work (no refresh needed)  
✅ Join requests work end-to-end  
✅ Admin controls accessible to creator only  
✅ Security rules block unauthorized access  

---

## 🎓 MONITORING & MAINTENANCE

### Weekly:
- [ ] Check Firebase usage dashboard
- [ ] Review new user signups
- [ ] Monitor error rates in console

### Monthly:
- [ ] Review security rules for any needed updates
- [ ] Analyze user feedback
- [ ] Plan feature updates

### Quarterly:
- [ ] Full security audit
- [ ] Performance optimization review
- [ ] Dependency updates

---

## 📞 SUPPORT & TROUBLESHOOTING

**If app doesn't load:**
1. Check Firebase Hosting status: https://status.firebase.google.com
2. Verify `firebase_options.dart` has correct project ID
3. Check browser console for errors

**If data isn't syncing:**
1. Verify Firestore database is active
2. Check security rules are deployed
3. Verify user is authenticated
4. Check network tab for errors

**If users can't login:**
1. Verify Firebase Authentication enabled
2. Check email/password provider enabled
3. Verify security rules allow reads on users collection

---

**🎉 READY FOR PRODUCTION!**

After completing this checklist, your TeamSync app is ready for production deployment.

For questions: Check [IMPLEMENTATION_COMPLETE.md](IMPLEMENTATION_COMPLETE.md) or [TESTING_GUIDE.md](TESTING_GUIDE.md)

