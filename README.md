# TeamSync

## Channel Migration

We migrated chat to a channel-scoped architecture. To migrate existing project-wide messages
into the new `channels/{channelId}/messages` layout, use the Node.js migration tool located at `tools/migrate_messages_to_channels.js`.

Quick steps:

1. Install dependencies:

```bash
cd tools
npm install firebase-admin yargs
```

2. Provide service account credentials via the `GOOGLE_APPLICATION_CREDENTIALS` env var.

3. Run migration for a project:

```bash
node migrate_messages_to_channels.js --projectId=<PROJECT_ID> --deleteOld=true
```

This will copy existing `projects/{projectId}/messages/*` documents into
`projects/{projectId}/channels/general/messages/*` and optionally delete the old docs.

## Security rules and validation

Firestore security rules are provided in `firestore.rules` following the channel-based model.
A unit test harness using the Firestore emulator is included under `tools/` to validate common
access patterns (collaborator vs outsider, private channel isolation, unread/member doc access).

## Firestore Quota Warning

**Firestore Spark (free) plan limits:**
- 50,000 reads/day
- 20,000 writes/day
- 20,000 deletes/day
- Quota resets at midnight Pacific Time (UTC-8)
- If quota is hit: wait until midnight PST for it to reset
- During presentation: avoid rapid repeated block creation/deletion tests

To run the rules tests locally:

1. Install Firebase CLI (for emulator) if not installed:

```bash
npm install -g firebase-tools
```

2. Install test dependencies:

```bash
cd tools
npm install
```

3. Start the emulator and run the test script (this will automatically provide emulator host/port):

```bash
firebase emulators:exec "node firestore_rules_test.js"
```

The test script will run assertions for expected allowed and denied operations. If you prefer to run
the emulator separately, start it with `firebase emulators:start --only firestore`, then run
`node firestore_rules_test.js` in the `tools` folder.

