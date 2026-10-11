'use strict';

const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { MemoryStore } = require('./src/store');
const { createHandlers } = require('./src/handlers');
const { createLocalAuth } = require('./src/local-auth');

const dataDir = path.join(__dirname, 'data');
const dataFile = path.join(dataDir, 'store.json');
const blobDir = path.join(dataDir, 'blobs');
const port = Number(process.env.PORT || 8787);

function loadPepper() {
  if (process.env.PAIRING_PEPPER) return process.env.PAIRING_PEPPER;
  fs.mkdirSync(dataDir, { recursive: true });
  const pepperFile = path.join(dataDir, 'pepper');
  if (fs.existsSync(pepperFile)) return fs.readFileSync(pepperFile, 'utf8').trim();
  const pepper = crypto.randomBytes(32).toString('hex');
  fs.writeFileSync(pepperFile, pepper);
  return pepper;
}

const plan = process.env.FIREBASE_PLAN === 'spark' ? 'spark' : 'blaze';
const store = new MemoryStore({ blobDir });
if (fs.existsSync(dataFile)) store.loadJSON(fs.readFileSync(dataFile, 'utf8'));

const handlers = createHandlers(store, {
  pepper: loadPepper(),
  clock: () => Date.now(),
  origin: `http://127.0.0.1:${port}`,
  seedSamples: process.env.SEED_SAMPLES !== '0',
  env: {
    FIREBASE_PLAN: plan,
    STORAGE_BUDGET_BYTES: process.env.STORAGE_BUDGET_BYTES || '',
  },
});
const auth = createLocalAuth(store, handlers, () => Date.now());

function persist() {
  fs.mkdirSync(dataDir, { recursive: true });
  fs.writeFileSync(dataFile, JSON.stringify(store.toJSON()));
}

const openRoutes = new Set(['signup', 'login', 'google', 'guest']);
const authRoutes = {
  signup: (ctx, data) => auth.signup(data),
  login: (ctx, data) => auth.login(data),
  google: () => auth.google(),
  guest: () => auth.guest(),
  link: (ctx, data) => auth.link(ctx, data),
  logout: (ctx, data, token) => auth.logout(token),
  changePassword: (ctx, data) => auth.changePassword(ctx, data),
};

function send(res, status, body) {
  const raw = JSON.stringify(body);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    'Access-Control-Allow-Origin': res.reqOrigin || '*',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, OPTIONS',
  });
  res.end(raw);
}

function readJson(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let total = 0;
    req.on('data', (chunk) => {
      total += chunk.length;
      if (total > 1024 * 1024) {
        reject(Object.assign(new Error('invalid'), { code: 'invalid' }));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => {
      if (!chunks.length) return resolve({});
      try { resolve(JSON.parse(Buffer.concat(chunks).toString('utf8'))); }
      catch { reject(Object.assign(new Error('invalid'), { code: 'invalid' })); }
    });
  });
}

function readRaw(req, max) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let total = 0;
    req.on('data', (chunk) => {
      total += chunk.length;
      if (total > max) {
        reject(Object.assign(new Error('too_large'), { code: 'too_large' }));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => resolve(Buffer.concat(chunks)));
  });
}

const server = http.createServer(async (req, res) => {
  const origin = req.headers.origin || '*';
  res.reqOrigin = origin;
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': origin,
      'Access-Control-Allow-Headers': 'Authorization, Content-Type',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, OPTIONS',
      'Access-Control-Max-Age': '600',
    });
    res.end();
    return;
  }
  const url = new URL(req.url, `http://127.0.0.1:${port}`);
  try {
    if (req.method === 'GET' && url.pathname === '/health') {
      const limits = handlers.limits();
      send(res, 200, {
        ok: true,
        plan: limits.plan,
        budget: limits.budget,
        perFileMax: limits.perFileMax,
        planFileMax: limits.planFileMax,
        usageStop: limits.usageStop,
        driveOptions: limits.driveOptions,
        driveProductMax: limits.driveProductMax,
        drivePlatformMax: limits.drivePlatformMax,
        sparkStorageBytes: 0,
        devTools: true,
      });
      return;
    }
    const storageMatch = url.pathname.match(/^\/(storage|thumb)\/([a-f0-9]+)$/);
    if (req.method === 'GET' && storageMatch) {
      const packed = await handlers.getTicket(storageMatch[2]);
      const mime = packed.ticket.mime || 'application/octet-stream';
      res.writeHead(200, {
        'Content-Type': mime,
        'Content-Length': packed.bytes.length,
        'Cache-Control': 'private, no-store',
        'Content-Disposition': `attachment; filename="${encodeURIComponent(packed.ticket.fileName || 'file')}"`,
        'X-Content-Type-Options': 'nosniff',
        'Access-Control-Allow-Origin': origin,
      });
      res.end(packed.bytes);
      return;
    }
    const uploadMatch = url.pathname.match(/^\/upload\/([a-f0-9]+)(\/thumb)?$/);
    if (req.method === 'PUT' && uploadMatch) {
      const meta = await store.transact(async (tx) => tx.getUpload(uploadMatch[1]));
      if (!meta) {
        send(res, 404, { error: { code: 'forbidden' } });
        return;
      }
      const bytes = await readRaw(req, meta.maxBytes + 1);
      await handlers.writeUpload(uploadMatch[1], bytes, Boolean(uploadMatch[2]));
      persist();
      send(res, 200, { result: { ok: true } });
      return;
    }
    const call = url.pathname.match(/^\/v1\/([A-Za-z]+)$/);
    if (req.method === 'POST' && call) {
      const name = call[1];
      const body = await readJson(req);
      const data = body.data || body;
      const header = req.headers.authorization || '';
      const token = header.startsWith('Bearer ') ? header.slice(7) : '';
      let ctx = null;
      if (!openRoutes.has(name)) ctx = await auth.contextFor(token);
      let result;
      if (authRoutes[name]) result = await authRoutes[name](ctx, data, token);
      else if (typeof handlers[name] === 'function' && name !== 'writeUpload' && name !== 'getTicket' && name !== 'limits') {
        if (name === 'debugPurge' || name === 'debugUnlock') {
          result = await handlers[name](ctx, data);
        } else {
          result = await handlers[name](ctx, data);
        }
      } else {
        send(res, 404, { error: { code: 'invalid' } });
        return;
      }
      persist();
      send(res, 200, { result });
      return;
    }
    send(res, 404, { error: { code: 'invalid' } });
  } catch (error) {
    const code = error.code || 'invalid';
    const itemId = null;
    console.log(JSON.stringify({ uid: null, itemId, code, at: new Date().toISOString() }));
    const status = code === 'unauthenticated' ? 401 : 400;
    send(res, status, { error: { code } });
  }
});

server.listen(port, '127.0.0.1', () => {
  if (!process.env.FIREBASE_PLAN) {
    console.log(JSON.stringify({ code: 'plan_default_blaze', at: new Date().toISOString() }));
  }
  console.log(JSON.stringify({ code: 'local_listen', at: new Date().toISOString(), port }));
});
