'use strict';

const fs = require('fs');
const path = require('path');
const test = require('node:test');
const assert = require('node:assert/strict');
const { initializeTestEnvironment, assertFails } = require('@firebase/rules-unit-testing');

const root = path.join(__dirname, '..', '..');
const projectId = 'tempbox-rules';

let env;

test.before(async () => {
  env = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: fs.readFileSync(path.join(root, 'firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
    storage: {
      rules: fs.readFileSync(path.join(root, 'storage.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 9199,
    },
  });
});

test.after(async () => {
  if (env) await env.cleanup();
});

test('rules reject the closed operations', async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc('boxes/box-a').set({
      ownerUid: 'owner',
      kind: 'guest',
      memberUids: ['owner'],
      createdAt: 1,
    });
    await db.doc('items/item-a').set({
      boxId: 'box-a',
      ownerUid: 'owner',
      kind: 'message',
      text: 'secret',
      status: 'available',
      expiresAt: 1,
    });
    await db.doc('privateProfiles/owner').set({ managementId: 'A123456789012345' });
    await db.doc('boxSecrets/box-a').set({ pairingCodeHash: 'hash' });
    await db.doc('users/owner').set({
      nickname: 'owner',
      nicknameLower: 'owner',
      provider: 'anonymous',
      email: null,
      phoneE164: null,
      storageBackend: 'firebase',
      createdAt: 1,
      lastLoginAt: 1,
      disabled: false,
    });
    await db.doc('stats/20261011').set({ createdGuest: 1 });
  });

  const stranger = env.authenticatedContext('stranger').firestore();
  await assertFails(stranger.doc('boxes/box-a').get());
  await assertFails(stranger.doc('items/item-a').set({ text: 'nope' }));
  await assertFails(stranger.doc('privateProfiles/owner').get());
  await assertFails(stranger.doc('boxSecrets/box-a').get());
  await assertFails(stranger.doc('stats/20261011').set({ createdGuest: 2 }));

  const owner = env.authenticatedContext('owner').firestore();
  await assertFails(owner.doc('items/item-a').update({ expiresAt: 9 }));
  await assertFails(owner.doc('users/owner').update({ admin: true, managementId: 'A123456789012345' }));

  const storage = env.unauthenticatedContext().storage();
  await assertFails(storage.ref('uploads/owner/file.bin').getDownloadURL());
});
