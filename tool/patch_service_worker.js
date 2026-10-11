'use strict';

const fs = require('fs');
const path = require('path');

const target = path.join(__dirname, '..', 'build', 'web', 'flutter_service_worker.js');
const guard = fs.readFileSync(path.join(__dirname, '..', 'web', 'sw_guard.js'), 'utf8');
if (!fs.existsSync(target)) {
  console.log(JSON.stringify({ code: 'sw_missing', at: new Date().toISOString() }));
  process.exit(0);
}
const current = fs.readFileSync(target, 'utf8');
if (!current.includes('tempbox-no-personal-cache')) {
  fs.writeFileSync(target, `/* tempbox-no-personal-cache */\n${guard}\n${current}`);
}
console.log(JSON.stringify({ code: 'sw_patched', at: new Date().toISOString() }));
