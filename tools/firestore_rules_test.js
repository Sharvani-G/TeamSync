const fs = require('fs');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');

const PROJECT_ID = 'teamsync-test';

async function runTests() {
  const testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync('../firestore.rules', 'utf8')
    }
  });

  // Helper: create an unauthenticated and authenticated contexts
  const alice = testEnv.authenticatedContext('alice', { uid: 'alice' });
  const bob = testEnv.authenticatedContext('bob', { uid: 'bob' });
  const unauth = testEnv.unauthenticatedContext();

  // Seed a project doc: private project with alice as creator and bob as collaborator
  const adminDb = testEnv.adminApp().firestore();
  await adminDb.collection('projects').doc('proj1').set({
    id: 'proj1',
    title: 'Test Project',
    description: 'desc',
    createdBy: 'alice',
    collaborators: { 'bob': 'collaborator' },
    visibility: 'private',
    isOpenForRequests: false
  });

  // Create a private channel under project
  await adminDb.collection('projects').doc('proj1').collection('channels').doc('private1').set({
    id: 'private1',
    projectId: 'proj1',
    name: 'secret',
    createdBy: 'alice',
    members: ['alice'],
    isPrivate: true,
    createdAt: adminDb.firestore.FieldValue.serverTimestamp()
  });

  // Create a public channel
  await adminDb.collection('projects').doc('proj1').collection('channels').doc('general').set({
    id: 'general',
    projectId: 'proj1',
    name: 'general',
    createdBy: 'alice',
    members: [],
    isPrivate: false,
    createdAt: adminDb.firestore.FieldValue.serverTimestamp()
  });

  // Test cases
  // 1. bob (collaborator) can read public channel
  await assertSucceeds(bob.firestore().collection('projects').doc('proj1').collection('channels').doc('general').get());

  // 2. unauthenticated cannot read private channel
  await assertFails(unauth.firestore().collection('projects').doc('proj1').collection('channels').doc('private1').get());

  // 3. alice (member) can create message in private channel
  await assertSucceeds(alice.firestore().collection('projects').doc('proj1').collection('channels').doc('private1').collection('messages').doc('m1').set({
    id: 'm1', projectId: 'proj1', channelId: 'private1', senderId: 'alice', text: 'hello', createdAt: adminDb.firestore.FieldValue.serverTimestamp()
  }));

  // 4. bob (not member) cannot create message in private channel
  await assertFails(bob.firestore().collection('projects').doc('proj1').collection('channels').doc('private1').collection('messages').doc('m2').set({
    id: 'm2', projectId: 'proj1', channelId: 'private1', senderId: 'bob', text: 'hi', createdAt: adminDb.firestore.FieldValue.serverTimestamp()
  }));

  // 5. bob (collaborator) can create message in public channel
  await assertSucceeds(bob.firestore().collection('projects').doc('proj1').collection('channels').doc('general').collection('messages').doc('m3').set({
    id: 'm3', projectId: 'proj1', channelId: 'general', senderId: 'bob', text: 'public msg', createdAt: adminDb.firestore.FieldValue.serverTimestamp()
  }));

  // 6. unread/member doc: alice can write her member doc
  await assertSucceeds(alice.firestore().collection('projects').doc('proj1').collection('channels').doc('private1').collection('members').doc('alice').set({ userId: 'alice', lastReadAt: adminDb.firestore.FieldValue.serverTimestamp() }));

  // 7. bob cannot write alice's member doc
  await assertFails(bob.firestore().collection('projects').doc('proj1').collection('channels').doc('private1').collection('members').doc('alice').set({ userId: 'alice', lastReadAt: adminDb.firestore.FieldValue.serverTimestamp() }));

  // 8. unauth cannot read public channel messages in private project
  await assertFails(unauth.firestore().collection('projects').doc('proj1').collection('channels').doc('general').collection('messages').get());

  console.log('All tests executed. See above for pass/fail assertions.');

  await testEnv.cleanup();
}

runTests().catch(err => {
  console.error('Test run failed', err);
  process.exit(1);
});
