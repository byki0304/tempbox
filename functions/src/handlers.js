'use strict';

const crypto = require('crypto');
const {
  DRIVE_CAP_OPTIONS,
  DRIVE_PRODUCT_MAX_BYTES,
  KEEP_MS,
  LOCK_MS,
  ORPHAN_MS,
  GUEST_ITEM_CAP,
  SIGNED_ITEM_CAP,
  assessUpload,
  limitsFor,
} = require('./capacity');
const { emptyStat } = require('./store');

const REJECTED_EXT = new Set(['exe', 'bat', 'cmd', 'com', 'msi', 'dll', 'scr', 'ps1', 'sh', 'jar']);
const ALLOWED_EXT = new Set([
  'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'heif', 'bmp',
  'mp4', 'mov', 'webm', 'mkv', 'm4v',
  'mp3', 'm4a', 'wav', 'ogg', 'aac', 'flac',
  'pdf', 'txt', 'md', 'csv', 'json', 'log', 'zip',
  'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
  'apk', 'html', 'htm', 'svg',
]);
const ATTACHMENT_ONLY = new Set(['html', 'htm', 'svg', 'apk']);
const EVENTS = ['created', 'claimed', 'deleted', 'expired', 'rejected'];

function fail(code) {
  const error = new Error(code);
  error.code = code;
  return error;
}

function id() {
  return crypto.randomBytes(12).toString('hex');
}

function sha256(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

function seoulDay(ms) {
  const shifted = new Date(ms + 9 * 60 * 60 * 1000);
  const p = (n) => String(n).padStart(2, '0');
  return `${shifted.getUTCFullYear()}${p(shifted.getUTCMonth() + 1)}${p(shifted.getUTCDate())}`;
}

function managementId() {
  const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  const alphabet = `${letters}0123456789`;
  const buf = crypto.randomBytes(16);
  let out = letters[buf[0] % letters.length];
  for (let i = 1; i < 16; i += 1) out += alphabet[buf[i] % alphabet.length];
  return out;
}

function pairingCode() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const buf = crypto.randomBytes(8);
  let out = '';
  for (let i = 0; i < 8; i += 1) out += alphabet[buf[i] % alphabet.length];
  return out;
}

function extOf(name) {
  const base = String(name || '').split(/[/\\]/).pop();
  const dot = base.lastIndexOf('.');
  if (dot <= 0) return '';
  return base.slice(dot + 1).toLowerCase();
}

function safeName(name) {
  const base = String(name || 'file').split(/[/\\]/).pop().replace(/[^\w.\-()\u3131-\uD79D ]+/g, '_');
  const trimmed = base.trim().slice(0, 180);
  return trimmed || 'file';
}

function meaningfulLength(text) {
  return Array.from(text || '').filter((ch) => !/\s/u.test(ch)).length;
}

function checkText(text, required) {
  if (text == null || text === '') return required ? 'empty_message' : null;
  if (Array.from(text).length > 8000 || meaningfulLength(text) > 8000) return 'invalid';
  if (meaningfulLength(text) < 1) return 'empty_message';
  return null;
}

function validNickname(value) {
  return /^[\p{L}\p{N}]{2,16}$/u.test(value || '');
}

function mimeFor(ext) {
  const map = {
    jpg: 'image/jpeg', jpeg: 'image/jpeg', png: 'image/png', gif: 'image/gif', webp: 'image/webp',
    heic: 'image/heic', heif: 'image/heif', bmp: 'image/bmp',
    mp4: 'video/mp4', mov: 'video/quicktime', webm: 'video/webm', mkv: 'video/x-matroska', m4v: 'video/mp4',
    mp3: 'audio/mpeg', m4a: 'audio/mp4', wav: 'audio/wav', ogg: 'audio/ogg', aac: 'audio/aac', flac: 'audio/flac',
    pdf: 'application/pdf', txt: 'text/plain', md: 'text/plain', csv: 'text/csv', json: 'application/json',
    log: 'text/plain', zip: 'application/zip',
    doc: 'application/msword',
    docx: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    xls: 'application/vnd.ms-excel',
    xlsx: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    ppt: 'application/vnd.ms-powerpoint',
    pptx: 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    apk: 'application/vnd.android.package-archive',
    html: 'application/octet-stream', htm: 'application/octet-stream', svg: 'application/octet-stream',
  };
  return map[ext] || 'application/octet-stream';
}

function publicItem(item, thumbnailUrl) {
  return {
    itemId: item.itemId,
    boxId: item.boxId,
    kind: item.kind,
    text: item.text || null,
    fileName: item.fileName || null,
    mime: item.mime || null,
    bytes: item.bytes || null,
    backend: item.backend || null,
    status: item.status,
    lockExpiresAt: item.lockExpiresAt || null,
    createdAt: item.createdAt,
    expiresAt: item.expiresAt,
    thumbnailUrl: thumbnailUrl || null,
  };
}

function publicProfile(user, admin) {
  return {
    uid: user.uid,
    nickname: user.nickname || null,
    provider: user.provider,
    email: user.email || null,
    phoneE164: user.phoneE164 || null,
    storageBackend: user.storageBackend,
    driveMaxBytes: user.driveMaxBytes || null,
    disabled: user.disabled === true,
    admin: admin === true,
    createdAt: user.createdAt,
    lastLoginAt: user.lastLoginAt,
  };
}

function maskEmail(email) {
  if (!email || !email.includes('@')) return null;
  const [name, domain] = email.split('@');
  return `${name.slice(0, 1)}***@${domain}`;
}

function maskPhone(phone) {
  if (!phone) return null;
  const digits = phone.replace(/\D/g, '');
  return `${phone.slice(0, 3)} **** ${digits.slice(-4)}`;
}

function createHandlers(store, options) {
  const clock = options.clock || (() => Date.now());
  const pepper = options.pepper || '';
  const origin = options.origin || 'http://127.0.0.1:8787';
  const seedSamples = options.seedSamples === true;
  const plan = options.env?.FIREBASE_PLAN === 'blaze' ? 'blaze' : 'spark';
  const rawBudget = options.env?.STORAGE_BUDGET_BYTES;

  function now() { return clock(); }

  async function bump(tx, event, guest, dedupeKey) {
    if (!EVENTS.includes(event)) return false;
    const day = seoulDay(now());
    const stat = (await tx.getStat(day)) || emptyStat();
    if (dedupeKey) {
      const key = `${event}:${dedupeKey}`;
      if (await tx.hasCounted(key)) return false;
      await tx.setCounted(key);
    }
    stat[event][guest ? 'guest' : 'signed'] += 1;
    await tx.setStat(day, stat);
    return true;
  }

  async function audit(tx, actorUid, action, targetUid, changedFields) {
    await tx.addAudit({
      actorUid,
      action,
      targetUid: targetUid || null,
      changedFields,
      at: now(),
    });
  }

  async function requireUser(tx, ctx) {
    if (!ctx?.uid) throw fail('unauthenticated');
    const user = await tx.getUser(ctx.uid);
    if (!user) throw fail('unauthenticated');
    return user;
  }

  async function membership(tx, uid) {
    const boxes = await tx.boxesForMember(uid);
    boxes.sort((a, b) => b.createdAt - a.createdAt);
    const owned = boxes.find((box) => box.ownerUid === uid);
    return owned || boxes[0] || null;
  }

  async function requireBox(tx, uid, boxId) {
    const box = boxId ? await tx.getBox(boxId) : await membership(tx, uid);
    if (!box || !box.memberUids.includes(uid)) throw fail('forbidden');
    return box;
  }

  function guestUser(user) {
    return user.provider === 'anonymous';
  }

  async function isAdmin(tx, ctx) {
    if (!ctx?.uid) return false;
    const stored = await tx.getClaim(ctx.uid);
    if (ctx.admin === true && !stored) await tx.setClaim(ctx.uid, true);
    return ctx.admin === true || stored;
  }

  async function rememberBegin(tx, requestId) {
    if (!requestId) return null;
    return tx.getRequest(requestId);
  }

  async function thumbUrl(tx, item) {
    if (!item.thumbnailPath) return null;
    return mintUrl(tx, item, 'thumb');
  }

  async function mintUrl(tx, item, kind) {
    const token = crypto.randomBytes(24).toString('hex');
    const path = kind === 'thumb' ? item.thumbnailPath : (item.backend === 'google_drive' ? `drive/${item.driveFileId}` : item.storagePath);
    if (!path) return null;
    if (typeof tx.signedReadUrl === 'function') return tx.signedReadUrl(path, item, kind);
    await tx.putTicket({
      token,
      itemId: item.itemId,
      kind,
      path,
      fileName: item.fileName || 'file',
      mime: kind === 'original' && ATTACHMENT_ONLY.has(extOf(item.fileName || '')) ? 'application/octet-stream' : (item.mime || 'application/octet-stream'),
      expiresAt: now() + LOCK_MS,
    });
    const route = kind === 'thumb' ? 'thumb' : 'storage';
    return `${origin}/${route}/${token}`;
  }

  async function releaseLock(tx, item) {
    if (item && item.status === 'locked' && item.lockExpiresAt && item.lockExpiresAt <= now()) {
      item.status = 'available';
      item.lockExpiresAt = null;
      item.claimTokenHash = null;
      await tx.setItem(item);
    }
    return item;
  }

  async function erase(tx, item) {
    if (item.storagePath) await tx.delBlob(item.storagePath);
    if (item.thumbnailPath) await tx.delBlob(item.thumbnailPath);
    if (item.driveFileId) await tx.delBlob(`drive/${item.driveFileId}`);
    await tx.deleteTicketsForItem(item.itemId);
    await tx.deleteItem(item.itemId);
  }

  async function ensureAccount(ctx) {
    return store.transact(async (tx) => {
      if (!ctx?.uid) throw fail('unauthenticated');
      let user = await tx.getUser(ctx.uid);
      const admin = ctx.admin === true || await tx.getClaim(ctx.uid);
      const provider = providerFrom(ctx);
      const email = provider === 'email' ? (ctx.email || null) : null;
      const phoneE164 = provider === 'phone' ? (ctx.phoneE164 || phoneFromEmail(ctx.email)) : (user?.phoneE164 || null);
      if (!user) {
        const usedIds = new Set();
        for (const existing of await tx.listUsers()) {
          const doc = await tx.getPrivate(existing.uid);
          if (doc?.managementId) usedIds.add(doc.managementId);
        }
        let management = managementId();
        while (usedIds.has(management)) management = managementId();
        user = {
          uid: ctx.uid,
          nickname: null,
          nicknameLower: null,
          provider,
          email,
          phoneE164,
          storageBackend: 'firebase',
          driveMaxBytes: null,
          createdAt: now(),
          lastLoginAt: now(),
          disabled: false,
        };
        await tx.setUser(user);
        await tx.setPrivate({ uid: ctx.uid, managementId: management });
        await audit(tx, ctx.uid, 'ensureAccount', ctx.uid, ['provider']);
      } else {
        user.provider = provider || user.provider;
        if (provider === 'email') user.email = email;
        if (provider === 'phone') {
          user.email = null;
          user.phoneE164 = phoneE164;
        }
        if (provider === 'google') user.provider = 'google';
        user.lastLoginAt = now();
        await tx.setUser(stripAdmin(user));
      }
      return { profile: publicProfile(user, admin) };
    });
  }

  function providerFrom(ctx) {
    if (ctx.signInProvider === 'anonymous') return 'anonymous';
    if (ctx.signInProvider === 'google.com' || ctx.signInProvider === 'google') return 'google';
    const email = ctx.email || '';
    if (email.endsWith('@phone.tempbox.invalid')) return 'phone';
    if (ctx.signInProvider === 'password' || ctx.signInProvider === 'email') return 'email';
    return ctx.signInProvider || 'email';
  }

  function phoneFromEmail(email) {
    if (!email || !email.endsWith('@phone.tempbox.invalid')) return null;
    return email.slice(0, -('@phone.tempbox.invalid'.length));
  }

  function stripAdmin(user) {
    const next = { ...user };
    delete next.managementId;
    delete next.admin;
    delete next.password;
    return next;
  }

  async function setNickname(ctx, data) {
    return store.transact(async (tx) => {
      const user = await requireUser(tx, ctx);
      if (user.disabled) throw fail('forbidden');
      const nickname = String(data.nickname || '').trim();
      if (!validNickname(nickname)) throw fail('invalid');
      if (data.confirm !== true) return { confirm: false, nickname };
      const admin = await tx.getClaim(ctx.uid);
      user.nickname = nickname;
      user.nicknameLower = nickname.toLowerCase();
      await tx.setUser(stripAdmin(user));
      await audit(tx, ctx.uid, 'setNickname', ctx.uid, ['nickname']);
      return { profile: publicProfile(user, admin) };
    });
  }

  async function createBox(ctx, data) {
    return store.transact(async (tx) => {
      const user = await requireUser(tx, ctx);
      if (user.disabled) throw fail('forbidden');
      if (!user.nickname) throw fail('invalid');
      const fresh = data?.fresh === true && user.provider === 'anonymous';
      if (!fresh) {
        const existing = await membership(tx, ctx.uid);
        if (existing) return { box: publicBox(existing), pairingCode: null };
      } else {
        const boxes = await tx.boxesForMember(ctx.uid);
        for (const box of boxes) {
          box.memberUids = box.memberUids.filter((uid) => uid !== ctx.uid);
          if (box.memberUids.length === 0 && box.ownerUid === ctx.uid) {
            await tx.deleteBox(box.boxId);
            await tx.deleteSecret(box.boxId);
          } else {
            await tx.setBox(box);
          }
        }
      }
      const boxId = id();
      const createdAt = now();
      const kind = user.provider === 'anonymous' ? 'guest' : 'account';
      const box = {
        boxId,
        ownerUid: ctx.uid,
        kind,
        memberUids: [ctx.uid],
        createdAt,
      };
      await tx.setBox(box);
      let code = null;
      if (kind === 'guest') {
        if (!pepper) throw fail('invalid');
        code = pairingCode();
        await tx.setSecret(boxId, { pairingCodeHash: sha256(`${pepper}:${code}`) });
      }
      if (seedSamples) await seedBox(tx, user, box);
      await audit(tx, ctx.uid, 'createBox', ctx.uid, ['boxId']);
      return {
        box: publicBox(box),
        pairingCode: code,
        pairingCodeDisplay: code ? `${code.slice(0, 4)}-${code.slice(4)}` : null,
      };
    });
  }

  function publicBox(box) {
    return {
      boxId: box.boxId,
      ownerUid: box.ownerUid,
      kind: box.kind,
      memberUids: box.memberUids.slice(),
      createdAt: box.createdAt,
    };
  }

  async function seedBox(tx, user, box) {
    const createdAt = now();
    const message = {
      itemId: id(),
      boxId: box.boxId,
      ownerUid: user.uid,
      kind: 'message',
      text: '다른 기기에서 한 번 받아 보세요.',
      fileName: null,
      mime: null,
      bytes: null,
      backend: null,
      storagePath: null,
      driveFileId: null,
      thumbnailPath: null,
      status: 'available',
      lockExpiresAt: null,
      claimTokenHash: null,
      createdAt,
      expiresAt: createdAt + KEEP_MS,
    };
    const fileId = id();
    const storagePath = `uploads/${user.uid}/${fileId}`;
    const body = Buffer.from('tempbox\n', 'utf8');
    await tx.putBlob(storagePath, body);
    const file = {
      itemId: fileId,
      boxId: box.boxId,
      ownerUid: user.uid,
      kind: 'file',
      text: null,
      fileName: 'note.txt',
      mime: 'text/plain',
      bytes: body.length,
      backend: 'firebase',
      storagePath,
      driveFileId: null,
      thumbnailPath: null,
      status: 'available',
      lockExpiresAt: null,
      claimTokenHash: null,
      createdAt: createdAt + 1,
      expiresAt: createdAt + 1 + KEEP_MS,
    };
    await tx.setItem(message);
    await tx.setItem(file);
  }

  async function redeemPairingCode(ctx, data) {
    return store.transact(async (tx) => {
      const user = await requireUser(tx, ctx);
      if (user.disabled) throw fail('forbidden');
      const raw = String(data.code || '').toUpperCase().replace(/[^A-Z0-9]/g, '');
      if (raw.length !== 8 || !pepper) throw fail('invalid_code');
      const since = now() - 15 * 60 * 1000;
      let attempts = (await tx.getAttempts(ctx.uid)).filter((stamp) => stamp >= since);
      if (attempts.length >= 5) throw fail('rate_limited');
      const boxId = await tx.findBoxIdByHash(sha256(`${pepper}:${raw}`));
      if (!boxId) {
        attempts.push(now());
        await tx.setAttempts(ctx.uid, attempts);
        throw fail('invalid_code');
      }
      const box = await tx.getBox(boxId);
      if (!box) throw fail('invalid_code');
      if (!box.memberUids.includes(ctx.uid)) {
        if (box.memberUids.length >= 5) throw fail('forbidden');
        box.memberUids.push(ctx.uid);
        await tx.setBox(box);
        await audit(tx, ctx.uid, 'redeemPairingCode', box.ownerUid, ['memberUids']);
      }
      await tx.setAttempts(ctx.uid, []);
      return { box: publicBox(box) };
    });
  }

  async function listItems(ctx) {
    return store.transact(async (tx) => {
      const user = await requireUser(tx, ctx);
      const admin = await tx.getClaim(ctx.uid);
      const box = await membership(tx, ctx.uid);
      if (!box) return { box: null, items: [], profile: publicProfile(user, admin) };
      const items = await tx.itemsForBox(box.boxId);
      const out = [];
      for (const item of items) {
        await releaseLock(tx, item);
        if (item.expiresAt <= now()) continue;
        out.push(publicItem(item, await thumbUrl(tx, item)));
      }
      return { box: publicBox(box), items: out, profile: publicProfile(user, admin) };
    });
  }

  async function assertCapacity(tx, user, box, size, backend, pendingAdjust = 0) {
    const pending = (await tx.uploadsForBox(box.boxId)).length + pendingAdjust;
    const count = (await tx.countItems(box.boxId)) + pending;
    const cap = guestUser(user) ? GUEST_ITEM_CAP : SIGNED_ITEM_CAP;
    if (count >= cap) {
      return 'quota_user';
    }
    const used = backend === 'google_drive' ? 0 : await tx.sumFirebaseBytes();
    return assessUpload({
      plan,
      rawBudget,
      usedBytes: used,
      size,
      backend,
      driveCap: user.driveMaxBytes || DRIVE_PRODUCT_MAX_BYTES,
    });
  }

  async function reject(tx, user, requestId, code) {
    if (requestId) {
      const prev = await tx.getRequest(requestId);
      if (prev?.status === 'error') throw fail(prev.code);
    }
    await bump(tx, 'rejected', guestUser(user), requestId || id());
    if (requestId) await tx.setRequest(requestId, { status: 'error', code });
    throw fail(code);
  }

  async function createMessageItem(ctx, data) {
    return store.transact(async (tx) => {
      const user = await requireUser(tx, ctx);
      if (user.disabled) throw fail('forbidden');
      const requestId = cleanRequestId(data.clientRequestId);
      const prev = await rememberBegin(tx, requestId);
      if (prev?.status === 'done') {
        const item = await tx.getItem(prev.itemId);
        if (item) return { item: publicItem(item, await thumbUrl(tx, item)) };
      }
      if (prev?.status === 'error') throw fail(prev.code);
      const problem = checkText(data.text, true);
      if (problem) await reject(tx, user, requestId, problem === 'invalid' ? 'empty_message' : problem);
      const box = await requireBox(tx, ctx.uid, data.boxId);
      const count = (await tx.countItems(box.boxId)) + (await tx.uploadsForBox(box.boxId)).length;
      const cap = guestUser(user) ? GUEST_ITEM_CAP : SIGNED_ITEM_CAP;
      if (count >= cap) await reject(tx, user, requestId, 'quota_user');
      const createdAt = now();
      const item = {
        itemId: id(),
        boxId: box.boxId,
        ownerUid: ctx.uid,
        kind: 'message',
        text: data.text,
        fileName: null,
        mime: null,
        bytes: null,
        backend: null,
        storagePath: null,
        driveFileId: null,
        thumbnailPath: null,
        status: 'available',
        lockExpiresAt: null,
        claimTokenHash: null,
        createdAt,
        expiresAt: createdAt + KEEP_MS,
      };
      await tx.setItem(item);
      await bump(tx, 'created', guestUser(user), item.itemId);
      if (requestId) await tx.setRequest(requestId, { status: 'done', itemId: item.itemId });
      await audit(tx, ctx.uid, 'createMessageItem', ctx.uid, ['text']);
      return { item: publicItem(item, null) };
    });
  }

  function cleanRequestId(value) {
    if (!value) return null;
    const text = String(value);
    if (!/^[A-Za-z0-9-]{8,80}$/.test(text)) return null;
    return text;
  }

  async function beginFileUpload(ctx, data) {
    return store.transact(async (tx) => {
      const user = await requireUser(tx, ctx);
      if (user.disabled) throw fail('forbidden');
      const requestId = cleanRequestId(data.clientRequestId);
      const prev = await rememberBegin(tx, requestId);
      if (prev?.status === 'done') {
        const item = await tx.getItem(prev.itemId);
        if (item) return { already: true, item: publicItem(item, await thumbUrl(tx, item)) };
      }
      if (prev?.status === 'error') throw fail(prev.code);
      if (prev?.status === 'reserved') {
        const upload = await tx.getUpload(prev.uploadId);
        if (upload && !upload.completed) return ticketFrom(upload);
      }
      const fileName = safeName(data.fileName);
      const ext = extOf(fileName);
      if (REJECTED_EXT.has(ext) || !ALLOWED_EXT.has(ext)) await reject(tx, user, requestId, 'type_rejected');
      const textProblem = checkText(data.text, false);
      if (textProblem === 'invalid') await reject(tx, user, requestId, 'empty_message');
      const text = textProblem ? null : (data.text || null);
      const box = await requireBox(tx, ctx.uid, data.boxId);
      const room = (await tx.countItems(box.boxId)) + (await tx.uploadsForBox(box.boxId)).length;
      const cap = guestUser(user) ? GUEST_ITEM_CAP : SIGNED_ITEM_CAP;
      if (room >= cap) await reject(tx, user, requestId, 'quota_user');
      let backend = user.storageBackend === 'google_drive' && user.provider === 'google' ? 'google_drive' : 'firebase';
      const declared = Number(data.declaredBytes);
      if (Number.isFinite(declared) && declared > 0) {
        const early = await assertCapacity(tx, user, box, declared, backend);
        if (early) await reject(tx, user, requestId, early);
      }
      const limits = limitsFor(plan, rawBudget);
      const driveCap = DRIVE_CAP_OPTIONS.includes(user.driveMaxBytes) ? user.driveMaxBytes : DRIVE_PRODUCT_MAX_BYTES;
      let maxBytes = backend === 'google_drive'
        ? Math.min(driveCap, Math.floor(limits.drivePlatformMax * 0.9))
        : Math.min(limits.perFileMax, limits.planFileMax);
      if (backend === 'firebase' && maxBytes <= 0) await reject(tx, user, requestId, 'plan_capacity');
      const uploadId = id();
      const upload = {
        uploadId,
        uid: ctx.uid,
        boxId: box.boxId,
        fileName,
        mime: mimeFor(ext),
        text,
        backend,
        maxBytes,
        storagePath: null,
        driveFileId: null,
        thumbnailPath: null,
        createdAt: now(),
        completed: false,
        clientRequestId: requestId,
        fellBack: false,
      };
      if (backend === 'google_drive') {
        const opened = await tx.openDriveUpload?.({
          uploadId,
          fileName,
          mime: upload.mime,
          ownerUid: ctx.uid,
        });
        if (!opened) {
          backend = 'firebase';
          upload.backend = 'firebase';
          upload.fellBack = true;
          maxBytes = Math.min(limits.perFileMax, limits.planFileMax);
          upload.maxBytes = maxBytes;
          if (maxBytes <= 0) await reject(tx, user, requestId, 'plan_capacity');
        } else {
          upload.driveFileId = opened.driveFileId || id();
          upload.uploadUrl = opened.uploadUrl || `${origin}/upload/${uploadId}`;
        }
      }
      if (upload.backend === 'firebase') {
        upload.storagePath = `uploads/${ctx.uid}/${uploadId}`;
        upload.uploadUrl = `${origin}/upload/${uploadId}`;
      }
      upload.thumbUrl = `${origin}/upload/${uploadId}/thumb`;
      await tx.setUpload(upload);
      if (requestId) await tx.setRequest(requestId, { status: 'reserved', uploadId });
      return ticketFrom(upload);
    });
  }

  function ticketFrom(upload) {
    return {
      uploadId: upload.uploadId,
      maxBytes: upload.maxBytes,
      backend: upload.backend,
      storagePath: upload.storagePath,
      uploadUrl: upload.uploadUrl,
      thumbUrl: upload.thumbUrl,
      driveFileId: upload.driveFileId,
      fellBack: upload.fellBack === true,
      fileName: upload.fileName,
      mime: upload.mime,
    };
  }

  async function writeUpload(uploadId, bytes, thumb) {
    return store.transact(async (tx) => {
      const upload = await tx.getUpload(uploadId);
      if (!upload || upload.completed) throw fail('forbidden');
      const buf = Buffer.from(bytes);
      if (buf.length <= 0) throw fail('empty_message');
      if (!thumb && buf.length > upload.maxBytes) {
        const owner = await tx.getUser(upload.uid);
        if (owner) await reject(tx, owner, upload.clientRequestId, 'too_large');
        throw fail('too_large');
      }
      if (thumb) {
        upload.thumbnailPath = `thumbs/${upload.uploadId}.webp`;
        await tx.putBlob(upload.thumbnailPath, buf);
      } else if (upload.backend === 'google_drive') {
        await tx.putBlob(`drive/${upload.driveFileId}`, buf);
      } else {
        await tx.putBlob(upload.storagePath, buf);
      }
      await tx.setUpload(upload);
      return { ok: true };
    });
  }

  async function completeFileUpload(ctx, data) {
    return store.transact(async (tx) => {
      const user = await requireUser(tx, ctx);
      if (user.disabled) throw fail('forbidden');
      const upload = await tx.getUpload(data.uploadId);
      if (!upload || upload.uid !== ctx.uid) throw fail('forbidden');
      const requestId = upload.clientRequestId;
      if (upload.completed && upload.itemId) {
        const existing = await tx.getItem(upload.itemId);
        if (existing) return { item: publicItem(existing, await thumbUrl(tx, existing)) };
      }
      const box = await requireBox(tx, ctx.uid, upload.boxId);
      if (upload.backend === 'google_drive' && data.driveFileId && data.driveFileId !== upload.driveFileId) {
        await reject(tx, user, requestId, 'forbidden');
      }
      const key = upload.backend === 'google_drive' ? `drive/${upload.driveFileId}` : upload.storagePath;
      const size = await tx.blobSize(key);
      const verdict = await assertCapacity(tx, user, box, size, upload.backend, -1);
      if (verdict) {
        await tx.delBlob(key);
        if (upload.thumbnailPath) await tx.delBlob(upload.thumbnailPath);
        upload.completed = true;
        await tx.setUpload(upload);
        await reject(tx, user, requestId, verdict);
      }
      const createdAt = now();
      const item = {
        itemId: id(),
        boxId: box.boxId,
        ownerUid: ctx.uid,
        kind: upload.text ? 'message_file' : 'file',
        text: upload.text || null,
        fileName: upload.fileName,
        mime: upload.mime,
        bytes: size,
        backend: upload.backend,
        storagePath: upload.backend === 'firebase' ? upload.storagePath : null,
        driveFileId: upload.backend === 'google_drive' ? upload.driveFileId : null,
        thumbnailPath: upload.thumbnailPath || null,
        status: 'available',
        lockExpiresAt: null,
        claimTokenHash: null,
        createdAt,
        expiresAt: createdAt + KEEP_MS,
      };
      await tx.setItem(item);
      upload.completed = true;
      upload.itemId = item.itemId;
      await tx.setUpload(upload);
      await bump(tx, 'created', guestUser(user), item.itemId);
      if (requestId) await tx.setRequest(requestId, { status: 'done', itemId: item.itemId });
      await audit(tx, ctx.uid, 'completeFileUpload', ctx.uid, ['fileName', 'bytes', 'backend']);
      return { item: publicItem(item, await thumbUrl(tx, item)) };
    });
  }

  async function claimItem(ctx, data) {
    return store.transact(async (tx) => {
      const user = await requireUser(tx, ctx);
      if (user.disabled) throw fail('forbidden');
      const item = await tx.getItem(data.itemId);
      if (!item) throw fail('already_taken');
      const box = await tx.getBox(item.boxId);
      if (!box || !box.memberUids.includes(ctx.uid)) throw fail('forbidden');
      if (item.expiresAt <= now()) throw fail('expired');
      await releaseLock(tx, item);
      if (item.status === 'locked' && item.lockExpiresAt > now()) throw fail('locked');
      if (item.status !== 'available') throw fail('already_taken');
      const claimToken = crypto.randomBytes(24).toString('hex');
      item.status = 'locked';
      item.lockExpiresAt = now() + LOCK_MS;
      item.claimTokenHash = sha256(claimToken);
      await tx.setItem(item);
      const downloadUrl = item.kind === 'message' ? null : await mintUrl(tx, item, 'original');
      return {
        claimToken,
        item: publicItem(item, await thumbUrl(tx, item)),
        downloadUrl,
        text: item.text || null,
        fileName: item.fileName || null,
        mime: item.mime || null,
      };
    });
  }

  async function ackItem(ctx, data) {
    return store.transact(async (tx) => {
      const user = await requireUser(tx, ctx);
      if (user.disabled) throw fail('forbidden');
      const item = await tx.getItem(data.itemId);
      if (!item) throw fail('already_taken');
      const box = await tx.getBox(item.boxId);
      if (!box || !box.memberUids.includes(ctx.uid)) throw fail('forbidden');
      if (!data.claimToken || sha256(String(data.claimToken)) !== item.claimTokenHash) throw fail('forbidden');
      if (!item.lockExpiresAt || item.lockExpiresAt <= now() || item.status !== 'locked') throw fail('expired');
      await bump(tx, 'claimed', guestUser(user), item.itemId);
      await erase(tx, item);
      await audit(tx, ctx.uid, 'ackItem', item.ownerUid, ['status']);
      return { ok: true };
    });
  }

  async function deleteItem(ctx, data) {
    return store.transact(async (tx) => {
      const user = await requireUser(tx, ctx);
      if (user.disabled) throw fail('forbidden');
      const item = await tx.getItem(data.itemId);
      if (!item) throw fail('already_taken');
      const box = await tx.getBox(item.boxId);
      if (!box || !box.memberUids.includes(ctx.uid)) throw fail('forbidden');
      if (data.confirm !== true) return { confirm: false };
      await bump(tx, 'deleted', guestUser(user), item.itemId);
      await erase(tx, item);
      await audit(tx, ctx.uid, 'deleteItem', item.ownerUid, ['status']);
      return { ok: true };
    });
  }

  async function setStorageBackend(ctx, data) {
    return store.transact(async (tx) => {
      const user = await requireUser(tx, ctx);
      if (user.disabled) throw fail('forbidden');
      if (user.provider !== 'google') throw fail('forbidden');
      const backend = data.storageBackend === 'google_drive' ? 'google_drive' : 'firebase';
      let driveMaxBytes = user.driveMaxBytes;
      if (backend === 'google_drive') {
        const picked = Number(data.driveMaxBytes);
        if (!DRIVE_CAP_OPTIONS.includes(picked)) throw fail('invalid');
        driveMaxBytes = picked;
      }
      const admin = await tx.getClaim(ctx.uid);
      let priv = null;
      if (data.authCode && tx.exchangeDriveCode) priv = (await tx.getPrivate(ctx.uid)) || { uid: ctx.uid };
      user.storageBackend = backend;
      user.driveMaxBytes = backend === 'google_drive' ? driveMaxBytes : user.driveMaxBytes;
      await tx.setUser(stripAdmin(user));
      if (priv && tx.exchangeDriveCode) {
        const token = await tx.exchangeDriveCode(data.authCode);
        if (token) {
          priv.driveRefreshToken = token;
          await tx.setPrivate(priv);
        }
      }
      await audit(tx, ctx.uid, 'setStorageBackend', ctx.uid, ['storageBackend', 'driveMaxBytes']);
      return { profile: publicProfile(user, admin), driveOptions: DRIVE_CAP_OPTIONS.slice() };
    });
  }

  async function purgeExpired() {
    return store.transact(async (tx) => {
      const items = await tx.expiredItems(now());
      let removed = 0;
      for (const item of items) {
        if (item.status !== 'available' && item.status !== 'locked') continue;
        const owner = await tx.getUser(item.ownerUid);
        await bump(tx, 'expired', !owner || owner.provider === 'anonymous', item.itemId);
        await erase(tx, item);
        removed += 1;
      }
      const open = await tx.itemsForBox ? null : null;
      void open;
      if (tx.allItems) {
        for (const item of await tx.allItems()) await releaseLock(tx, item);
      }
      return { removed };
    });
  }

  async function purgeOrphans() {
    return store.transact(async (tx) => {
      const stale = await tx.orphanUploads(now() - ORPHAN_MS);
      for (const upload of stale) {
        if (upload.storagePath) await tx.delBlob(upload.storagePath);
        if (upload.thumbnailPath) await tx.delBlob(upload.thumbnailPath);
        if (upload.driveFileId) await tx.delBlob(`drive/${upload.driveFileId}`);
        await tx.deleteUpload(upload.uploadId);
      }
      return { removed: stale.length };
    });
  }

  async function debugPurge() {
    return purgeExpired();
  }

  async function debugUnlock() {
    return store.transact(async (tx) => {
      const items = tx.allItems ? await tx.allItems() : [];
      let released = 0;
      for (const item of items) {
        if (item.status === 'locked') {
          item.lockExpiresAt = now() - 1;
          await releaseLock(tx, item);
          released += 1;
        }
      }
      return { released };
    });
  }

  async function recordPasswordChange(ctx) {
    return store.transact(async (tx) => {
      const user = await requireUser(tx, ctx);
      if (user.disabled) throw fail('forbidden');
      if (user.provider === 'google' || user.provider === 'anonymous') throw fail('forbidden');
      await audit(tx, ctx.uid, 'changePassword', ctx.uid, ['password']);
      return { ok: true };
    });
  }

  async function deleteAccount(ctx) {
    return store.transact(async (tx) => {
      const user = await requireUser(tx, ctx);
      const boxes = await tx.boxesForMember(ctx.uid);
      for (const box of boxes) {
        if (box.ownerUid === ctx.uid) {
          const items = await tx.itemsForBox(box.boxId);
          for (const item of items) await erase(tx, item);
          await tx.deleteSecret(box.boxId);
          await tx.deleteBox(box.boxId);
        } else {
          box.memberUids = box.memberUids.filter((uid) => uid !== ctx.uid);
          await tx.setBox(box);
        }
      }
      if (tx.credentialsByUid) {
        for (const cred of await tx.credentialsByUid(ctx.uid)) await tx.deleteCredential(cred.email);
        await tx.deleteSessionsForUid(ctx.uid);
      }
      await tx.deletePrivate(ctx.uid);
      await tx.deleteUser(ctx.uid);
      await tx.setClaim(ctx.uid, false);
      await audit(tx, ctx.uid, 'deleteAccount', ctx.uid, ['users', 'privateProfiles', 'boxes', 'items']);
      return { ok: true };
    });
  }

  async function setAdminClaim(ctx, data) {
    return store.transact(async (tx) => {
      if (!(await isAdmin(tx, ctx))) throw fail('forbidden');
      const target = await tx.getUser(data.targetUid);
      if (!target) throw fail('forbidden');
      const grant = data.admin === true;
      if (!grant) {
        if (data.targetUid === ctx.uid) throw fail('self_admin');
        const admins = await tx.adminCount();
        const targetIsAdmin = await tx.getClaim(data.targetUid);
        if (targetIsAdmin && admins <= 1) throw fail('last_admin');
      }
      await tx.setClaim(data.targetUid, grant);
      await audit(tx, ctx.uid, 'setAdminClaim', data.targetUid, ['admin']);
      return { ok: true };
    });
  }

  async function adminListUsers(ctx, data) {
    return store.transact(async (tx) => {
      if (!(await isAdmin(tx, ctx))) throw fail('forbidden');
      const query = String(data.query || '').trim().toLowerCase();
      const digits = query.replace(/\D/g, '');
      const rows = [];
      for (const user of await tx.listUsers()) {
        const nick = (user.nicknameLower || '').includes(query);
        const email = (user.email || '').toLowerCase().includes(query);
        const phone = digits && (user.phoneE164 || '').replace(/\D/g, '').includes(digits);
        if (query && !nick && !email && !phone) continue;
        const boxes = await tx.boxesForMember(user.uid);
        const owned = boxes.find((box) => box.ownerUid === user.uid);
        const itemCount = owned ? await tx.countItems(owned.boxId) : 0;
        rows.push({
          uid: user.uid,
          nickname: user.nickname || '',
          role: (await tx.getClaim(user.uid)) ? 'admin' : (user.provider === 'anonymous' ? 'guest' : 'signed'),
          provider: user.provider,
          contact: maskEmail(user.email) || maskPhone(user.phoneE164) || '',
          createdAt: user.createdAt,
          lastLoginAt: user.lastLoginAt,
          itemCount,
          disabled: user.disabled === true,
        });
      }
      rows.sort((a, b) => b.createdAt - a.createdAt);
      return { users: rows };
    });
  }

  async function adminSetDisabled(ctx, data) {
    return store.transact(async (tx) => {
      if (!(await isAdmin(tx, ctx))) throw fail('forbidden');
      if (data.targetUid === ctx.uid) throw fail('forbidden');
      const target = await tx.getUser(data.targetUid);
      if (!target) throw fail('forbidden');
      target.disabled = data.disabled === true;
      await tx.setUser(stripAdmin(target));
      await audit(tx, ctx.uid, 'adminSetDisabled', data.targetUid, ['disabled']);
      return { ok: true };
    });
  }

  async function adminPurgeGuest(ctx, data) {
    return store.transact(async (tx) => {
      if (!(await isAdmin(tx, ctx))) throw fail('forbidden');
      const target = await tx.getUser(data.targetUid);
      if (!target || target.provider !== 'anonymous') throw fail('forbidden');
      const boxes = (await tx.boxesForMember(data.targetUid)).filter((box) => box.ownerUid === data.targetUid);
      let itemCount = 0;
      for (const box of boxes) itemCount += await tx.countItems(box.boxId);
      if (data.confirm !== true) return { itemCount };
      for (const box of boxes) {
        for (const item of await tx.itemsForBox(box.boxId)) await erase(tx, item);
        await tx.deleteSecret(box.boxId);
        await tx.deleteBox(box.boxId);
      }
      await audit(tx, ctx.uid, 'adminPurgeGuest', data.targetUid, ['items']);
      return { itemCount, ok: true };
    });
  }

  async function adminListAudit(ctx) {
    return store.transact(async (tx) => {
      if (!(await isAdmin(tx, ctx))) throw fail('forbidden');
      const rows = await tx.listAudit(200);
      return {
        rows: rows.map((row) => ({
          actorUid: row.actorUid,
          action: row.action,
          targetUid: row.targetUid,
          changedFields: row.changedFields,
          at: row.at,
        })),
      };
    });
  }

  async function adminGetStats(ctx, data) {
    return store.transact(async (tx) => {
      if (!(await isAdmin(tx, ctx))) throw fail('forbidden');
      const range = [7, 30, 90].includes(Number(data.days)) ? Number(data.days) : 7;
      const rows = [];
      const bars = [];
      for (let offset = range - 1; offset >= 0; offset -= 1) {
        const dayMs = now() - offset * 24 * 60 * 60 * 1000;
        const day = seoulDay(dayMs);
        const stat = (await tx.getStat(day)) || emptyStat();
        let guestSum = 0;
        let signedSum = 0;
        for (const event of EVENTS) {
          const guest = stat[event]?.guest || 0;
          const signed = stat[event]?.signed || 0;
          guestSum += guest;
          signedSum += signed;
          if (guest || signed) {
            rows.push({ date: day, event, guest, signed, total: guest + signed });
          }
        }
        if (guestSum || signedSum) bars.push({ date: day, guest: guestSum, signed: signedSum });
      }
      return { days: range, rows, bars };
    });
  }

  async function getTicket(token) {
    return store.transact(async (tx) => {
      const ticket = await tx.getTicket(token);
      if (!ticket || ticket.expiresAt <= now()) throw fail('expired');
      const bytes = await tx.getBlob(ticket.path);
      if (!bytes) throw fail('already_taken');
      return { ticket, bytes };
    });
  }

  return {
    ensureAccount,
    setNickname,
    createBox,
    redeemPairingCode,
    listItems,
    createMessageItem,
    beginFileUpload,
    writeUpload,
    completeFileUpload,
    claimItem,
    ackItem,
    deleteItem,
    setStorageBackend,
    purgeExpired,
    purgeOrphans,
    debugPurge,
    debugUnlock,
    recordPasswordChange,
    deleteAccount,
    setAdminClaim,
    adminListUsers,
    adminSetDisabled,
    adminPurgeGuest,
    adminListAudit,
    adminGetStats,
    getTicket,
    limits: () => limitsFor(plan, rawBudget),
  };
}

module.exports = {
  createHandlers,
  fail,
  validNickname,
  managementId,
  publicProfile,
  ATTACHMENT_ONLY,
  extOf,
};
