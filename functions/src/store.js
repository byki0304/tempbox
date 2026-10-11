'use strict';

const fs = require('fs');
const path = require('path');

function emptyStat() {
  const cell = () => ({ guest: 0, signed: 0 });
  return {
    created: cell(),
    claimed: cell(),
    deleted: cell(),
    expired: cell(),
    rejected: cell(),
  };
}

class MemoryView {
  constructor(data, blobs, blobDir) {
    this.data = data;
    this.blobs = blobs;
    this.blobDir = blobDir;
  }

  async getUser(uid) { return this.data.users[uid] || null; }
  async setUser(user) { this.data.users[user.uid] = user; }
  async deleteUser(uid) { delete this.data.users[uid]; }
  async getPrivate(uid) { return this.data.privateProfiles[uid] || null; }
  async setPrivate(doc) { this.data.privateProfiles[doc.uid] = doc; }
  async deletePrivate(uid) { delete this.data.privateProfiles[uid]; }
  async getBox(id) { return this.data.boxes[id] || null; }
  async setBox(box) { this.data.boxes[box.boxId] = box; }
  async deleteBox(id) { delete this.data.boxes[id]; }

  async boxesForMember(uid) {
    return Object.values(this.data.boxes).filter((box) => box.memberUids.includes(uid));
  }

  async getSecret(boxId) { return this.data.boxSecrets[boxId] || null; }
  async setSecret(boxId, doc) { this.data.boxSecrets[boxId] = doc; }
  async deleteSecret(boxId) { delete this.data.boxSecrets[boxId]; }

  async findBoxIdByHash(hash) {
    const found = Object.entries(this.data.boxSecrets).find(([, doc]) => doc.pairingCodeHash === hash);
    return found ? found[0] : null;
  }

  async getItem(id) { return this.data.items[id] || null; }
  async setItem(item) { this.data.items[item.itemId] = item; }
  async deleteItem(id) { delete this.data.items[id]; }

  async itemsForBox(boxId) {
    return Object.values(this.data.items)
      .filter((item) => item.boxId === boxId)
      .sort((a, b) => a.createdAt - b.createdAt || a.itemId.localeCompare(b.itemId));
  }

  async allItems() {
    return Object.values(this.data.items);
  }

  async openDriveUpload() {
    return { driveFileId: require('crypto').randomBytes(12).toString('hex') };
  }

  async countItems(boxId) {
    return Object.values(this.data.items).filter((item) => item.boxId === boxId).length;
  }

  async sumFirebaseBytes() {
    return Object.values(this.data.items).reduce((sum, item) => {
      if (item.backend === 'firebase') return sum + (item.bytes || 0);
      return sum;
    }, 0);
  }

  async expiredItems(now) {
    return Object.values(this.data.items).filter((item) => item.expiresAt <= now);
  }

  async getUpload(id) { return this.data.uploads[id] || null; }
  async setUpload(upload) { this.data.uploads[upload.uploadId] = upload; }
  async deleteUpload(id) { delete this.data.uploads[id]; }

  async uploadsForBox(boxId) {
    return Object.values(this.data.uploads).filter((upload) => upload.boxId === boxId && !upload.completed);
  }

  async orphanUploads(before) {
    return Object.values(this.data.uploads).filter((upload) => !upload.completed && upload.createdAt <= before);
  }

  async getStat(day) { return this.data.stats[day] ? structuredClone(this.data.stats[day]) : null; }
  async setStat(day, stat) { this.data.stats[day] = stat; }
  async hasCounted(key) { return Boolean(this.data.counted[key]); }
  async setCounted(key) { this.data.counted[key] = true; }
  async getRequest(id) { return this.data.requests[id] || null; }
  async setRequest(id, value) { this.data.requests[id] = value; }

  async addAudit(entry) { this.data.auditLogs.push(entry); }
  async listAudit(limit) {
    return this.data.auditLogs.slice(-limit).reverse();
  }

  async getAttempts(uid) { return (this.data.attempts[uid] || []).slice(); }
  async setAttempts(uid, stamps) { this.data.attempts[uid] = stamps; }
  async listUsers() { return Object.values(this.data.users); }
  async getClaim(uid) { return this.data.claims[uid] === true; }
  async setClaim(uid, admin) {
    if (admin) this.data.claims[uid] = true;
    else delete this.data.claims[uid];
  }
  async adminCount() { return Object.keys(this.data.claims).length; }

  _blobFile(key) {
    const safe = Buffer.from(key).toString('hex');
    return path.join(this.blobDir, safe);
  }

  async putBlob(key, buffer) {
    const buf = Buffer.from(buffer);
    this.blobs.set(key, buf);
    if (this.blobDir) {
      fs.mkdirSync(this.blobDir, { recursive: true });
      fs.writeFileSync(this._blobFile(key), buf);
    }
  }

  async getBlob(key) {
    if (this.blobs.has(key)) return this.blobs.get(key);
    if (this.blobDir && fs.existsSync(this._blobFile(key))) {
      const buf = fs.readFileSync(this._blobFile(key));
      this.blobs.set(key, buf);
      return buf;
    }
    return null;
  }

  async delBlob(key) {
    this.blobs.delete(key);
    if (this.blobDir && fs.existsSync(this._blobFile(key))) fs.unlinkSync(this._blobFile(key));
  }

  async blobSize(key) {
    const buf = await this.getBlob(key);
    return buf ? buf.length : 0;
  }

  async putTicket(ticket) { this.data.tickets[ticket.token] = ticket; }
  async getTicket(token) { return this.data.tickets[token] || null; }
  async deleteTicketsForItem(itemId) {
    for (const [token, ticket] of Object.entries(this.data.tickets)) {
      if (ticket.itemId === itemId) delete this.data.tickets[token];
    }
  }

  async getCredential(email) { return this.data.credentials[email] || null; }
  async setCredential(email, record) { this.data.credentials[email] = record; }
  async deleteCredential(email) { delete this.data.credentials[email]; }
  async credentialsByUid(uid) {
    return Object.entries(this.data.credentials)
      .filter(([, record]) => record.uid === uid)
      .map(([email, record]) => ({ email, ...record }));
  }
  async getSession(token) { return this.data.sessions[token] || null; }
  async setSession(token, session) { this.data.sessions[token] = session; }
  async deleteSession(token) { delete this.data.sessions[token]; }
  async deleteSessionsForUid(uid) {
    for (const [token, session] of Object.entries(this.data.sessions)) {
      if (session.uid === uid) delete this.data.sessions[token];
    }
  }
  async getLocalGoogleUid() { return this.data.localGoogleUid; }
  async setLocalGoogleUid(uid) { this.data.localGoogleUid = uid; }
}

class MemoryStore {
  constructor(options = {}) {
    this.blobDir = options.blobDir || null;
    this.data = {
      users: {},
      privateProfiles: {},
      boxes: {},
      boxSecrets: {},
      items: {},
      uploads: {},
      stats: {},
      counted: {},
      requests: {},
      auditLogs: [],
      attempts: {},
      claims: {},
      sessions: {},
      credentials: {},
      tickets: {},
      localGoogleUid: null,
    };
    this.blobs = new Map();
    this._chain = Promise.resolve();
  }

  view() {
    return new MemoryView(this.data, this.blobs, this.blobDir);
  }

  transact(fn) {
    const run = this._chain.then(() => fn(this.view()));
    this._chain = run.then(() => undefined, () => undefined);
    return run;
  }

  toJSON() {
    return structuredClone(this.data);
  }

  loadJSON(raw) {
    if (!raw) return;
    const parsed = typeof raw === 'string' ? JSON.parse(raw) : raw;
    this.data = {
      ...this.data,
      ...parsed,
      users: parsed.users || {},
      privateProfiles: parsed.privateProfiles || {},
      boxes: parsed.boxes || {},
      boxSecrets: parsed.boxSecrets || {},
      items: parsed.items || {},
      uploads: parsed.uploads || {},
      stats: parsed.stats || {},
      counted: parsed.counted || {},
      requests: parsed.requests || {},
      auditLogs: parsed.auditLogs || [],
      attempts: parsed.attempts || {},
      claims: parsed.claims || {},
      sessions: parsed.sessions || {},
      credentials: parsed.credentials || {},
      tickets: parsed.tickets || {},
      localGoogleUid: parsed.localGoogleUid || null,
    };
  }
}

module.exports = { MemoryStore, emptyStat };
