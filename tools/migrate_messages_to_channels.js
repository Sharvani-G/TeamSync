/*
Migration script: moves documents from projects/{projectId}/messages/{messageId}
into projects/{projectId}/channels/general/messages/{messageId}.

Usage:
  1. Install dependencies: `npm install firebase-admin`.
  2. Provide a service account JSON and set GOOGLE_APPLICATION_CREDENTIALS env var,
     or edit the admin.initializeApp call below with credentials.
  3. Run: `node tools/migrate_messages_to_channels.js --projectId=<projectId> [--deleteOld=true]`

This script copies messages preserving fields, sets `channelId: 'general'`,
updates channel metadata (lastMessageAt, messageCount), and optionally deletes old docs.
*/

const admin = require('firebase-admin');
const argv = require('yargs').argv;

if (!argv.projectId) {
  console.error('Missing --projectId');
  process.exit(1);
}

const PROJECT_ID = argv.projectId;
const DELETE_OLD = argv.deleteOld === 'true' || argv.deleteOld === true;

admin.initializeApp({});
const db = admin.firestore();

async function ensureGeneralChannel(projectId) {
  const channelRef = db.collection('projects').doc(projectId).collection('channels').doc('general');
  const doc = await channelRef.get();
  if (!doc.exists) {
    await channelRef.set({
      id: 'general',
      projectId,
      name: 'general',
      createdBy: 'migration-script',
      members: [],
      isPrivate: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      lastMessageAt: null,
      messageCount: 0,
    });
    console.log('Created general channel');
  } else {
    console.log('general channel exists');
  }
  return channelRef;
}

async function migrate(projectId) {
  const projectRef = db.collection('projects').doc(projectId);
  const messagesRef = projectRef.collection('messages');
  const snapshot = await messagesRef.get();
  console.log(`Found ${snapshot.size} messages to migrate`);

  if (snapshot.empty) return;

  const channelRef = await ensureGeneralChannel(projectId);

  const batches = [];
  let batch = db.batch();
  let ops = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const newRef = channelRef.collection('messages').doc(doc.id);
    // preserve fields and add channelId
    const newData = Object.assign({}, data, { channelId: 'general' });
    batch.set(newRef, newData);
    ops++;

    if (DELETE_OLD) {
      batch.delete(doc.ref);
    }

    if (ops >= 400) {
      batches.push(batch.commit());
      batch = db.batch();
      ops = 0;
    }
  }

  if (ops > 0) {
    batches.push(batch.commit());
  }

  await Promise.all(batches);

  // Update channel metadata (messageCount and lastMessageAt)
  const latestSnap = await channelRef.collection('messages').orderBy('createdAt', 'desc').limit(1).get();
  const lastMessageAt = latestSnap.empty ? null : latestSnap.docs[0].data().createdAt || admin.firestore.FieldValue.serverTimestamp();
  const totalCount = (await channelRef.collection('messages').get()).size;

  await channelRef.update({
    lastMessageAt: lastMessageAt || null,
    messageCount: totalCount,
  });

  console.log('Migration complete');
}

migrate(PROJECT_ID).catch(err => {
  console.error('Migration error', err);
  process.exit(1);
});
