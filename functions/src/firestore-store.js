'use strict';

const { openResumable, deleteDriveFile } = require('./drive');

class FirestoreView {
  constructor(adminApp, tx) {
    this.admin = adminApp;
    this.db = adminApp.firestore();
    this.tx = tx;
    this._bucket = null;
  }

  get bucket() {
    if (!this._bucket) this._bucket = this.admin.storage().bucket();
    return this._bucket;
  }

  col(name) {
    return this.db.collection(name);
  }

  async _one(name, id) {
    const snap = await this.tx.get(this.col(name).doc(id));
    return snap.exists ? snap.data() : null;
  }

  async getUser(uid) { return this._one('users', uid); }
  async setUser(user) {
    const next = { ...user };
    delete next.managementId;
    delete next.admin;
    delete next.password;
    this.tx.set(this.col('users').doc(user.uid), next);
  }
  async deleteUser(uid) { this.tx.delete(this.col('users').doc(uid)); }
  async getPrivate(uid) { return this._one('privateProfiles', uid); }
  async setPrivate(doc) { this.tx.set(this.col('privateProfiles').doc(doc.uid), doc); }
  async deletePrivate(uid) { this.tx.delete(this.col('privateProfiles').doc(uid)); }
  async getBox(id) { return this._one('boxes', id); }
  async setBox(box) { this.tx.set(this.col('boxes').doc(box.boxId), box); }
  async deleteBox(id) { this.tx.delete(this.col('boxes').doc(id)); }

  async boxesForMember(uid) {
    const snap = await this.tx.get(this.col('boxes').where('memberUids', 'array-contains', uid));
    return snap.docs.map((doc) => doc.data());
  }

  async getSecret(boxId) { return this._one('boxSecrets', boxId); }
  async setSecret(boxId, doc) { this.tx.set(this.col('boxSecrets').doc(boxId), doc); }
  async deleteSecret(boxId) { this.tx.delete(this.col('boxSecrets').doc(boxId)); }

  async findBoxIdByHash(hash) {
    const snap = await this.tx.get(this.col('boxSecrets').where('pairingCodeHash', '==', hash).limit(1));
    return snap.empty ? null : snap.docs[0].id;
  }

  async getItem(id) { return this._one('items', id); }
  async setItem(item) { this.tx.set(this.col('items').doc(item.itemId), item); }
  async deleteItem(id) { this.tx.delete(this.col('items').doc(id)); }

  async itemsForBox(boxId) {
    const snap = await this.tx.get(this.col('items').where('boxId', '==', boxId));
    return snap.docs.map((doc) => doc.data()).sort((a, b) => a.createdAt - b.createdAt);
  }

  async allItems() {
    const snap = await this.tx.get(this.col('items'));
    return snap.docs.map((doc) => doc.data());
  }

  async countItems(boxId) {
    return (await this.itemsForBox(boxId)).length;
  }

  async sumFirebaseBytes() {
    const snap = await this.tx.get(this.col('items').where('backend', '==', 'firebase'));
    return snap.docs.reduce((sum, doc) => sum + (doc.data().bytes || 0), 0);
  }

  async expiredItems(now) {
    const snap = await this.tx.get(this.col('items').where('expiresAt', '<=', now));
    return snap.docs.map((doc) => doc.data());
  }

  async getUpload(id) { return this._one('uploads', id); }
  async setUpload(upload) { this.tx.set(this.col('uploads').doc(upload.uploadId), upload); }
  async deleteUpload(id) { this.tx.delete(this.col('uploads').doc(id)); }

  async uploadsForBox(boxId) {
    const snap = await this.tx.get(this.col('uploads').where('boxId', '==', boxId));
    return snap.docs.map((doc) => doc.data()).filter((upload) => !upload.completed);
  }

  async orphanUploads(before) {
    const snap = await this.tx.get(this.col('uploads').where('completed', '==', false).where('createdAt', '<=', before));
    return snap.docs.map((doc) => doc.data());
  }

  async getStat(day) { return this._one('stats', day); }
  async setStat(day, stat) { this.tx.set(this.col('stats').doc(day), stat); }
  async hasCounted(key) {
    const snap = await this.tx.get(this.col('counted').doc(key));
    return snap.exists;
  }
  async setCounted(key) { this.tx.set(this.col('counted').doc(key), { at: Date.now() }); }
  async getRequest(id) { return this._one('requests', id); }
  async setRequest(id, value) { this.tx.set(this.col('requests').doc(id), value); }

  async addAudit(entry) {
    this.tx.set(this.col('auditLogs').doc(), entry);
  }

  async listAudit(limit) {
    const snap = await this.tx.get(this.col('auditLogs').orderBy('at', 'desc').limit(limit));
    return snap.docs.map((doc) => doc.data());
  }

  async getAttempts(uid) {
    const doc = await this._one('pairingAttempts', uid);
    return doc?.stamps || [];
  }
  async setAttempts(uid, stamps) { this.tx.set(this.col('pairingAttempts').doc(uid), { stamps }); }

  async listUsers() {
    const snap = await this.tx.get(this.col('users'));
    return snap.docs.map((doc) => ({ ...doc.data(), uid: doc.id }));
  }

  async getClaim(uid) {
    const doc = await this._one('adminClaims', uid);
    return doc?.admin === true;
  }
  async setClaim(uid, adminFlag) {
    if (adminFlag) this.tx.set(this.col('adminClaims').doc(uid), { admin: true });
    else this.tx.delete(this.col('adminClaims').doc(uid));
    await this.admin.auth().setCustomUserClaims(uid, { admin: adminFlag === true });
  }
  async adminCount() {
    const snap = await this.tx.get(this.col('adminClaims'));
    return snap.size;
  }

  async putBlob(key, buffer) {
    if (String(key).startsWith('drive/')) return;
    await this.bucket.file(key).save(Buffer.from(buffer), { resumable: false, metadata: { cacheControl: 'private, no-store' } });
  }
  async getBlob(key) {
    if (String(key).startsWith('drive/')) return null;
    const [buf] = await this.bucket.file(key).download();
    return buf;
  }
  async delBlob(key) {
    if (String(key).startsWith('drive/')) {
      await deleteDriveFile(key.slice('drive/'.length));
      return;
    }
    await this.bucket.file(key).delete({ ignoreNotFound: true });
  }
  async blobSize(key) {
    if (String(key).startsWith('drive/')) return 0;
    const [meta] = await this.bucket.file(key).getMetadata();
    return Number(meta.size || 0);
  }

  async putTicket() {}
  async getTicket() { return null; }
  async deleteTicketsForItem() {}

  async signedReadUrl(filePath, item) {
    const [url] = await this.bucket.file(filePath).getSignedUrl({
      action: 'read',
      expires: Date.now() + 10 * 60 * 1000,
      responseDisposition: `attachment; filename="${item.fileName || 'file'}"`,
    });
    return url;
  }

  async openDriveUpload(info) {
    const priv = await this.getPrivate(info.ownerUid);
    if (!priv?.driveRefreshToken) return null;
    try {
      return await openResumable({ refreshToken: priv.driveRefreshToken, fileName: info.fileName, mime: info.mime, uploadId: info.uploadId });
    } catch (_) {
      return null;
    }
  }
}

class FirestoreStore {
  constructor(adminApp) {
    this.admin = adminApp;
  }

  transact(fn) {
    return this.admin.firestore().runTransaction((tx) => fn(new FirestoreView(this.admin, tx)));
  }
}

module.exports = { FirestoreStore };
