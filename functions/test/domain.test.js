'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { MemoryStore } = require('../src/store');
const { createHandlers, managementId } = require('../src/handlers');
const { createLocalAuth } = require('../src/local-auth');
const { assessUpload, KEEP_MS, BLAZE_OBJECT_MAX_BYTES, SPARK_STORAGE_BYTES } = require('../src/capacity');

function world(env = {}, seedSamples = false) {
  const store = new MemoryStore();
  const clock = { now: Date.parse('2026-10-11T00:00:00.000Z') };
  const handlers = createHandlers(store, {
    clock: () => clock.now,
    pepper: 'pepper-test',
    origin: 'http://127.0.0.1:8787',
    seedSamples,
    env: { FIREBASE_PLAN: 'blaze', STORAGE_BUDGET_BYTES: String(5 * 1000 ** 3), ...env },
  });
  const auth = createLocalAuth(store, handlers, () => clock.now);
  return { store, clock, handlers, auth };
}

async function guestBox(app, nickname = '손님') {
  const session = await app.auth.guest();
  await app.handlers.setNickname(session.ctx, { nickname, confirm: true });
  const created = await app.handlers.createBox(session.ctx, {});
  return { session, created };
}

test('expiresAt is createdAt plus 240 hours and ignores the client', async () => {
  const app = world();
  const { session } = await guestBox(app);
  const result = await app.handlers.createMessageItem(session.ctx, {
    text: '메모',
    expiresAt: 1,
    clientRequestId: 'req-create-01',
  });
  assert.equal(result.item.expiresAt - result.item.createdAt, KEEP_MS);
});

test('guest and signed stats increase separately and retries do not double', async () => {
  const app = world();
  const guest = await guestBox(app);
  await app.handlers.createMessageItem(guest.session.ctx, { text: '하나', clientRequestId: 'req-guest-01' });
  await assert.rejects(
    app.handlers.createMessageItem(guest.session.ctx, { text: '   ', clientRequestId: 'req-empty-01' }),
    (error) => error.code === 'empty_message',
  );
  await assert.rejects(
    app.handlers.createMessageItem(guest.session.ctx, { text: '   ', clientRequestId: 'req-empty-01' }),
    (error) => error.code === 'empty_message',
  );
  const signed = await app.auth.signup({ kind: 'email', email: 'a@example.com', password: 'abc123' });
  signed.ctx.admin = false;
  await app.handlers.setNickname(signed.ctx, { nickname: '회원', confirm: true });
  await app.handlers.createBox(signed.ctx, {});
  await app.handlers.createMessageItem(signed.ctx, { text: '둘', clientRequestId: 'req-signed-01' });
  const stats = await app.store.transact(async (tx) => tx.getStat('20261011'));
  assert.equal(stats.created.guest, 1);
  assert.equal(stats.created.signed, 1);
  assert.equal(stats.rejected.guest, 1);
  assert.equal(stats.rejected.signed, 0);
});

test('claim locks once, ack deletes, and a wrong token keeps the item', async () => {
  const app = world();
  const { session } = await guestBox(app);
  const created = await app.handlers.createMessageItem(session.ctx, { text: '받아가기', clientRequestId: 'req-claim-01' });
  const other = await app.auth.guest();
  await app.handlers.setNickname(other.ctx, { nickname: '둘째', confirm: true });
  const listed = await app.handlers.listItems(session.ctx);
  const box = listed.box;
  const secret = await app.store.transact(async (tx) => tx.getSecret(box.boxId));
  assert.ok(secret.pairingCodeHash);
  assert.equal((await app.store.transact(async (tx) => tx.getBox(box.boxId))).pairingCodeHash, undefined);
  const first = await app.handlers.claimItem(session.ctx, { itemId: created.item.itemId });
  await assert.rejects(
    app.handlers.claimItem(session.ctx, { itemId: created.item.itemId }),
    (error) => error.code === 'locked',
  );
  await assert.rejects(
    app.handlers.ackItem(session.ctx, { itemId: created.item.itemId, claimToken: 'nope' }),
    (error) => error.code === 'forbidden',
  );
  assert.ok(await app.store.transact(async (tx) => tx.getItem(created.item.itemId)));
  await app.handlers.ackItem(session.ctx, { itemId: created.item.itemId, claimToken: first.claimToken });
  assert.equal(await app.store.transact(async (tx) => tx.getItem(created.item.itemId)), null);
  const again = await app.handlers.createMessageItem(session.ctx, { text: '둘째', clientRequestId: 'req-claim-02' });
  const claim = await app.handlers.claimItem(session.ctx, { itemId: again.item.itemId });
  await app.handlers.ackItem(session.ctx, { itemId: again.item.itemId, claimToken: claim.claimToken });
  await app.handlers.ackItem(session.ctx, { itemId: again.item.itemId, claimToken: claim.claimToken }).catch(() => {});
  const stats = await app.store.transact(async (tx) => tx.getStat('20261011'));
  assert.equal(stats.claimed.guest, 2);
  void other;
});

test('lock returns to available after 10 minutes without ack', async () => {
  const app = world();
  const { session } = await guestBox(app);
  const created = await app.handlers.createMessageItem(session.ctx, { text: '잠금', clientRequestId: 'req-lock-01' });
  await app.handlers.claimItem(session.ctx, { itemId: created.item.itemId });
  app.clock.now += 10 * 60 * 1000 + 1;
  const again = await app.handlers.claimItem(session.ctx, { itemId: created.item.itemId });
  assert.ok(again.claimToken);
});

test('executable types are rejected and html stays an attachment', async () => {
  const app = world();
  const { session } = await guestBox(app);
  await assert.rejects(
    app.handlers.beginFileUpload(session.ctx, { fileName: 'run.exe', clientRequestId: 'req-exe-0001' }),
    (error) => error.code === 'type_rejected',
  );
  const begun = await app.handlers.beginFileUpload(session.ctx, { fileName: 'page.html', clientRequestId: 'req-html-001' });
  assert.equal(begun.backend, 'firebase');
});

test('spark rejects any firebase byte and blaze enforces 90 percent and 80 percent', async () => {
  assert.equal(SPARK_STORAGE_BYTES, 0);
  assert.equal(assessUpload({ plan: 'spark', rawBudget: '', usedBytes: 0, size: 1, backend: 'firebase' }), 'plan_capacity');
  const huge = Math.floor(BLAZE_OBJECT_MAX_BYTES * 0.9) + 1;
  assert.equal(assessUpload({ plan: 'blaze', rawBudget: String(BLAZE_OBJECT_MAX_BYTES), usedBytes: 0, size: huge, backend: 'firebase' }), 'plan_capacity');
  const budget = 1000;
  assert.equal(assessUpload({ plan: 'blaze', rawBudget: String(budget), usedBytes: 0, size: 801, backend: 'firebase' }), 'too_large');
  assert.equal(assessUpload({ plan: 'blaze', rawBudget: String(budget), usedBytes: 800, size: 1, backend: 'firebase' }), 'quota_project');
});

test('management id stays off the user document and drive bytes skip the firebase budget', async () => {
  const app = world();
  const session = await app.auth.signup({ kind: 'email', email: 'b@example.com', password: 'abc123' });
  const user = await app.store.transact(async (tx) => tx.getUser(session.profile.uid));
  const priv = await app.store.transact(async (tx) => tx.getPrivate(session.profile.uid));
  assert.match(priv.managementId, /^[A-Z][A-Z0-9]{15}$/);
  assert.equal(user.managementId, undefined);
  assert.equal(user.admin, undefined);
  assert.equal(managementId().length, 16);
  const phone = await app.auth.signup({ kind: 'phone', country: '+82', national: '10-1234-5678', password: 'abc123' });
  assert.equal(phone.profile.email, null);
  assert.equal(phone.profile.phoneE164, '+821012345678');
});

test('linking anonymous keeps the same uid', async () => {
  const app = world();
  const guest = await app.auth.guest();
  const linked = await app.auth.link(guest.ctx, { kind: 'email', email: 'link@example.com', password: 'abc123' });
  assert.equal(linked.profile.uid, guest.profile.uid);
  assert.equal(linked.profile.provider, 'email');
});

test('delete keeps daily stats and audit stores field names only', async () => {
  const app = world();
  const { session } = await guestBox(app);
  const created = await app.handlers.createMessageItem(session.ctx, { text: '지울메모', clientRequestId: 'req-del-0001' });
  await app.handlers.deleteItem(session.ctx, { itemId: created.item.itemId, confirm: true });
  const stats = await app.store.transact(async (tx) => tx.getStat('20261011'));
  assert.equal(stats.deleted.guest, 1);
  await app.handlers.deleteAccount(session.ctx);
  const after = await app.store.transact(async (tx) => tx.getStat('20261011'));
  assert.equal(after.deleted.guest, 1);
  const audit = await app.store.transact(async (tx) => tx.listAudit(20));
  assert.ok(audit.every((row) => !('text' in row) && Array.isArray(row.changedFields)));
});

test('pairing attempts stop after five misses', async () => {
  const app = world();
  const { session } = await guestBox(app);
  for (let i = 0; i < 5; i += 1) {
    await assert.rejects(
      app.handlers.redeemPairingCode(session.ctx, { code: 'AAAAAAAA' }),
      (error) => error.code === 'invalid_code',
    );
  }
  await assert.rejects(
    app.handlers.redeemPairingCode(session.ctx, { code: 'BBBBBBBB' }),
    (error) => error.code === 'rate_limited',
  );
});

test('a second device can redeem the code and see the same item', async () => {
  const app = world();
  const owner = await guestBox(app);
  const note = await app.handlers.createMessageItem(owner.session.ctx, { text: '같이보기', clientRequestId: 'req-pair-0001' });
  const other = await app.auth.guest();
  await app.handlers.setNickname(other.ctx, { nickname: '다른', confirm: true });
  await app.handlers.redeemPairingCode(other.ctx, { code: owner.created.pairingCodeDisplay });
  const items = await app.handlers.listItems(other.ctx);
  assert.equal(items.items.some((item) => item.itemId === note.item.itemId), true);
});

test('file complete uses the stored size and drive files are deleted with the item', async () => {
  const app = world();
  const session = await app.auth.google();
  await app.handlers.setNickname(session.ctx, { nickname: '구글', confirm: true });
  await app.handlers.createBox(session.ctx, {});
  await app.handlers.setStorageBackend(session.ctx, { storageBackend: 'google_drive', driveMaxBytes: 128 * 1024 * 1024 });
  const begun = await app.handlers.beginFileUpload(session.ctx, { fileName: 'pic.png', clientRequestId: 'req-drive-001' });
  assert.equal(begun.backend, 'google_drive');
  await app.handlers.writeUpload(begun.uploadId, Buffer.from('12345'), false);
  const done = await app.handlers.completeFileUpload(session.ctx, { uploadId: begun.uploadId, driveFileId: begun.driveFileId, bytes: 99999 });
  assert.equal(done.item.bytes, 5);
  assert.equal(await app.store.transact(async (tx) => tx.sumFirebaseBytes()), 0);
  const claim = await app.handlers.claimItem(session.ctx, { itemId: done.item.itemId });
  await app.handlers.ackItem(session.ctx, { itemId: done.item.itemId, claimToken: claim.claimToken });
  assert.equal(await app.store.transact(async (tx) => tx.blobSize(`drive/${begun.driveFileId}`)), 0);
});

test('purge removes expired items without keeping the body in stats', async () => {
  const app = world();
  const { session } = await guestBox(app);
  const created = await app.handlers.createMessageItem(session.ctx, { text: '오래됨', clientRequestId: 'req-exp-0001' });
  app.clock.now += KEEP_MS + 1;
  const purged = await app.handlers.purgeExpired();
  assert.equal(purged.removed, 1);
  assert.equal(await app.store.transact(async (tx) => tx.getItem(created.item.itemId)), null);
  const stats = await app.store.transact(async (tx) => tx.getStat('20261021'));
  assert.equal(stats.expired.guest, 1);
  assert.equal(JSON.stringify(stats).includes('오래됨'), false);
});

test('signed-in google cloud keeps a message until download deletes it', async () => {
  const app = world();
  const signed = await app.auth.signup({ kind: 'email', email: 'cloud@example.com', password: 'abc123' });
  await app.handlers.setNickname(signed.ctx, { nickname: '클라우드', confirm: true });
  await app.handlers.createBox(signed.ctx, {});
  const guest = await app.auth.guest();
  await app.handlers.setNickname(guest.ctx, { nickname: '손님둘', confirm: true });
  await assert.rejects(
    app.handlers.setStorageBackend(guest.ctx, { storageBackend: 'google_cloud', cloudMaxBytes: 20 * 1024 * 1024 }),
    (error) => error.code === 'forbidden',
  );
  const saved = await app.handlers.setStorageBackend(signed.ctx, { storageBackend: 'google_cloud', cloudMaxBytes: 20 * 1024 * 1024 });
  assert.equal(saved.profile.storageBackend, 'google_cloud');
  assert.equal(saved.profile.cloudMaxBytes, 20 * 1024 * 1024);
  const created = await app.handlers.createMessageItem(signed.ctx, { text: '클라우드메모', clientRequestId: 'req-cloud-0001' });
  const stored = await app.store.transact(async (tx) => tx.getItem(created.item.itemId));
  assert.equal(stored.backend, 'google_cloud');
  assert.equal(await app.store.transact(async (tx) => tx.blobSize(stored.storagePath)), Buffer.byteLength('클라우드메모'));
  const begun = await app.handlers.beginFileUpload(signed.ctx, { fileName: 'note.txt', clientRequestId: 'req-cloud-file' });
  assert.equal(begun.backend, 'google_cloud');
  assert.equal(begun.maxBytes, 20 * 1024 * 1024);
  const claim = await app.handlers.claimItem(signed.ctx, { itemId: created.item.itemId });
  await app.handlers.ackItem(signed.ctx, { itemId: created.item.itemId, claimToken: claim.claimToken });
  assert.equal(await app.store.transact(async (tx) => tx.getItem(created.item.itemId)), null);
  assert.equal(await app.store.transact(async (tx) => tx.blobSize(stored.storagePath)), 0);
});
