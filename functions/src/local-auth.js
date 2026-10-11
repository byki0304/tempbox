'use strict';

const crypto = require('crypto');
const { fail } = require('./handlers');

const THIRTY_MIN = 30 * 60 * 1000;

function hashPassword(password) {
  const salt = crypto.randomBytes(16).toString('hex');
  const hash = crypto.scryptSync(password, salt, 32).toString('hex');
  return `${salt}:${hash}`;
}

function verifyPassword(password, stored) {
  const [salt, hash] = String(stored || '').split(':');
  if (!salt || !hash) return false;
  const next = crypto.scryptSync(password, salt, 32);
  const prev = Buffer.from(hash, 'hex');
  if (prev.length !== next.length) return false;
  return crypto.timingSafeEqual(prev, next);
}

function validPassword(password) {
  return /^[A-Za-z0-9]{6,20}$/.test(password || '');
}

function validEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email || '');
}

function normalizePhone(country, national) {
  const digits = String(national || '').replace(/\D/g, '');
  if (digits.length < 9 || digits.length > 11) return null;
  let cc = String(country || '+82').trim();
  if (!cc.startsWith('+')) cc = `+${cc.replace(/\D/g, '')}`;
  let body = digits;
  if (cc === '+82' && body.startsWith('0')) body = body.slice(1);
  if (body.length < 9 || body.length > 11) return null;
  return `${cc}${body}`;
}

function phoneEmail(e164) {
  return `${e164}@phone.tempbox.invalid`;
}

function createLocalAuth(store, handlers, clock) {
  const now = clock || (() => Date.now());

  async function issue(uid, signInProvider, email, phoneE164) {
    const token = crypto.randomBytes(24).toString('hex');
    await store.transact(async (tx) => {
      await tx.setSession(token, {
        uid,
        signInProvider,
        email: email || null,
        phoneE164: phoneE164 || null,
        lastSeen: now(),
      });
    });
    const ctx = { uid, signInProvider, email: email || null, phoneE164: phoneE164 || null, admin: false };
    const ensured = await handlers.ensureAccount(ctx);
    ctx.admin = ensured.profile.admin === true;
    return { token, profile: ensured.profile, ctx };
  }

  async function signup(data) {
    const kind = data.kind === 'phone' ? 'phone' : 'email';
    if (!validPassword(data.password)) throw fail('invalid_password');
    let email;
    let phoneE164 = null;
    if (kind === 'phone') {
      phoneE164 = normalizePhone(data.country, data.national);
      if (!phoneE164) throw fail('invalid_phone');
      email = phoneEmail(phoneE164);
    } else {
      email = String(data.email || '').trim().toLowerCase();
      if (!validEmail(email)) throw fail('invalid_email');
    }
    const uid = crypto.randomBytes(12).toString('hex');
    const created = await store.transact(async (tx) => {
      if (await tx.getCredential(email)) return false;
      await tx.setCredential(email, { uid, passwordHash: hashPassword(data.password), kind });
      return true;
    });
    if (!created) throw fail('exists');
    return issue(uid, kind === 'phone' ? 'password' : 'password', email, phoneE164);
  }

  async function login(data) {
    const kind = data.kind === 'phone' ? 'phone' : 'email';
    let email;
    if (kind === 'phone') {
      const phoneE164 = normalizePhone(data.country, data.national);
      if (!phoneE164 || !data.password) throw fail('invalid_phone_login');
      email = phoneEmail(phoneE164);
    } else {
      email = String(data.email || '').trim().toLowerCase();
      if (!validEmail(email) || !data.password) throw fail('invalid_login');
    }
    const found = await store.transact(async (tx) => tx.getCredential(email));
    if (!found || !verifyPassword(data.password, found.passwordHash)) {
      throw fail(kind === 'phone' ? 'invalid_phone_login' : 'invalid_login');
    }
    const phoneE164 = kind === 'phone' ? email.slice(0, -('@phone.tempbox.invalid'.length)) : null;
    return issue(found.uid, 'password', email, phoneE164);
  }

  async function google() {
    let uid = await store.transact(async (tx) => tx.getLocalGoogleUid());
    const exists = uid ? await store.transact(async (tx) => tx.getUser(uid)) : null;
    if (!uid || !exists) {
      uid = crypto.randomBytes(12).toString('hex');
      await store.transact(async (tx) => tx.setLocalGoogleUid(uid));
    }
    return issue(uid, 'google', null, null);
  }

  async function guest() {
    const uid = crypto.randomBytes(12).toString('hex');
    return issue(uid, 'anonymous', null, null);
  }

  async function link(ctx, data) {
    if (!ctx?.uid) throw fail('unauthenticated');
    const current = await store.transact(async (tx) => tx.getUser(ctx.uid));
    if (!current || current.provider !== 'anonymous') throw fail('forbidden');
    if (data.kind === 'google') {
      const taken = await store.transact(async (tx) => tx.getLocalGoogleUid());
      if (taken && taken !== ctx.uid) throw fail('forbidden');
      await store.transact(async (tx) => tx.setLocalGoogleUid(ctx.uid));
      return issue(ctx.uid, 'google', null, null);
    }
    if (!validPassword(data.password)) throw fail('invalid_password');
    let email;
    let phoneE164 = null;
    if (data.kind === 'phone') {
      phoneE164 = normalizePhone(data.country, data.national);
      if (!phoneE164) throw fail('invalid_phone');
      email = phoneEmail(phoneE164);
    } else {
      email = String(data.email || '').trim().toLowerCase();
      if (!validEmail(email)) throw fail('invalid_email');
    }
    const created = await store.transact(async (tx) => {
      if (await tx.getCredential(email)) return false;
      await tx.setCredential(email, { uid: ctx.uid, passwordHash: hashPassword(data.password), kind: data.kind === 'phone' ? 'phone' : 'email' });
      return true;
    });
    if (!created) throw fail('exists');
    return issue(ctx.uid, 'password', email, phoneE164);
  }

  async function changePassword(ctx, data) {
    if (!ctx?.uid) throw fail('unauthenticated');
    if (!validPassword(data.next)) throw fail('invalid_password');
    await store.transact(async (tx) => {
      const user = await tx.getUser(ctx.uid);
      if (!user || user.provider === 'google' || user.provider === 'anonymous') throw fail('forbidden');
      const creds = await tx.credentialsByUid(ctx.uid);
      const cred = creds[0];
      if (!cred || !verifyPassword(data.current || '', cred.passwordHash)) {
        throw fail(user.provider === 'phone' ? 'invalid_phone_login' : 'invalid_login');
      }
      await tx.setCredential(cred.email, { ...cred, passwordHash: hashPassword(data.next) });
      await tx.addAudit({
        actorUid: ctx.uid,
        action: 'changePassword',
        targetUid: ctx.uid,
        changedFields: ['password'],
        at: now(),
      });
    });
    return { ok: true };
  }

  async function logout(token) {
    if (!token) return { ok: true };
    await store.transact(async (tx) => tx.deleteSession(token));
    return { ok: true };
  }

  async function contextFor(token) {
    if (!token) throw fail('unauthenticated');
    return store.transact(async (tx) => {
      const session = await tx.getSession(token);
      if (!session) throw fail('unauthenticated');
      if (now() - session.lastSeen > THIRTY_MIN) {
        await tx.deleteSession(token);
        throw fail('unauthenticated');
      }
      session.lastSeen = now();
      await tx.setSession(token, session);
      const admin = await tx.getClaim(session.uid);
      return {
        uid: session.uid,
        signInProvider: session.signInProvider,
        email: session.email,
        phoneE164: session.phoneE164,
        admin,
      };
    });
  }

  return { signup, login, google, guest, link, changePassword, logout, contextFor, normalizePhone, phoneEmail };
}

module.exports = { createLocalAuth, validPassword, validEmail, normalizePhone };
