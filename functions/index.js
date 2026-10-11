'use strict';

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { setGlobalOptions } = require('firebase-functions/v2');
const admin = require('firebase-admin');
const { createHandlers } = require('./src/handlers');
const { FirestoreStore } = require('./src/firestore-store');

setGlobalOptions({ region: 'asia-northeast3' });
admin.initializeApp({
  storageBucket: 'tempbox-c3fc8.firebasestorage.app',
});

const handlers = createHandlers(new FirestoreStore(admin), {
  clock: () => Date.now(),
  pepper: process.env.PAIRING_PEPPER || '',
  seedSamples: false,
  env: {
    FIREBASE_PLAN: process.env.FIREBASE_PLAN === 'blaze' ? 'blaze' : 'spark',
    STORAGE_BUDGET_BYTES: process.env.STORAGE_BUDGET_BYTES || '',
  },
});

const names = [
  'ensureAccount',
  'setNickname',
  'createBox',
  'redeemPairingCode',
  'listItems',
  'createMessageItem',
  'beginFileUpload',
  'completeFileUpload',
  'claimItem',
  'ackItem',
  'deleteItem',
  'setStorageBackend',
  'deleteAccount',
  'recordPasswordChange',
  'setAdminClaim',
  'adminListUsers',
  'adminSetDisabled',
  'adminPurgeGuest',
  'adminListAudit',
  'adminGetStats',
  'purgeExpired',
];

function wrap(name) {
  return onCall({ region: 'asia-northeast3' }, async (request) => {
    const uid = request.auth?.uid || null;
    const itemId = request.data?.itemId || null;
    try {
      if (!request.auth) {
        const error = new Error('unauthenticated');
        error.code = 'unauthenticated';
        throw error;
      }
      const ctx = {
        uid: request.auth.uid,
        admin: request.auth.token?.admin === true,
        email: request.auth.token?.email || null,
        signInProvider: request.auth.token?.firebase?.sign_in_provider || null,
      };
      const result = await handlers[name](ctx, request.data || {});
      if (name === 'deleteAccount') {
        await admin.auth().deleteUser(request.auth.uid);
      }
      return result;
    } catch (error) {
      const code = typeof error.code === 'string' && error.code ? error.code : 'invalid';
      console.log(JSON.stringify({
        uid,
        itemId,
        code,
        message: String(error.message || '').slice(0, 180),
        at: new Date().toISOString(),
      }));
      throw new HttpsError(code === 'unauthenticated' ? 'unauthenticated' : 'failed-precondition', code, { code });
    }
  });
}

for (const name of names) {
  exports[name] = wrap(name);
}

exports.purgeExpiredSchedule = onSchedule({ schedule: 'every 15 minutes', region: 'asia-northeast3', timeZone: 'Asia/Seoul' }, async () => {
  await handlers.purgeExpired();
});

exports.purgeOrphans = onSchedule({ schedule: 'every 60 minutes', region: 'asia-northeast3', timeZone: 'Asia/Seoul' }, async () => {
  await handlers.purgeOrphans();
});
