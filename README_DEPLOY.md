# Deployment & E2E Upload Test

Steps to deploy the Cloud Function locally or via CI and validate uploads.

Local deploy (requires Firebase CLI authenticated):

```bash
cd functions
npm install
firebase deploy --only functions --project <PROJECT_ID>
```

Set bucket CORS (if you prefer direct client uploads instead of server proxy):

```bash
# Requires gsutil
./scripts/set_bucket_cors.sh <BUCKET_NAME>
```

CI deploy using GitHub Actions:

- Add repo secrets: `FIREBASE_SERVICE_ACCOUNT` (service account JSON), `FIREBASE_PROJECT`, optional `FIREBASE_REGION`.
- Trigger the workflow `Deploy Functions and Run E2E Upload Test` by pushing to `main` or via the Actions UI.

After deploy:
- Set `lib/config.dart` `serverUploadUrl` to the deployed function URL (e.g. `https://<region>-<project>.cloudfunctions.net/app/upload`).
- Rebuild the Flutter web app and verify file uploads.
