'use strict';

// Checked against Firebase docs on 2026-10-11.
// Spark: Cloud Storage for Firebase is unavailable (billing requirement effective 2026-02-03).
// Storage capacity on Spark is 0 bytes, so 90% of that capacity is also 0.
// Blaze: no fixed account cap. A Cloud Storage object can be at most 5 TiB.
// Blaze no-cost stored data for the default bucket is 5 GB, then pay-as-you-go.
// Google Drive allows 5 TB for one ordinary file. This product caps a Drive original at 2 GiB.

const TiB = 1024 ** 4;
const GB = 1000 ** 3;
const GiB = 1024 ** 3;

const SPARK_STORAGE_BYTES = 0;
const BLAZE_OBJECT_MAX_BYTES = 5 * TiB;
const BLAZE_NO_COST_BYTES = 5 * GB;
const DRIVE_PLATFORM_MAX_BYTES = 5 * TiB;
const DRIVE_PRODUCT_MAX_BYTES = 2 * GiB;
const DRIVE_CAP_OPTIONS = [128, 256, 512, 1024, 2048].map((mb) => mb * 1024 * 1024);
const CLOUD_CAP_OPTIONS = [20, 100, 256, 512, 1024].map((mb) => mb * 1024 * 1024);
const CLOUD_DEFAULT_BYTES = 20 * 1024 * 1024;

const KEEP_MS = 240 * 60 * 60 * 1000;
const GUEST_KEEP_MS = 24 * 60 * 60 * 1000;
const LOCK_MS = 10 * 60 * 1000;
const ORPHAN_MS = 24 * 60 * 60 * 1000;
const GUEST_ITEM_CAP = 30;
const SIGNED_ITEM_CAP = 200;

function storageCapacity(plan) {
  return plan === 'spark' ? SPARK_STORAGE_BYTES : BLAZE_OBJECT_MAX_BYTES;
}

function resolveBudget(plan, rawBudget) {
  const parsed = Number(rawBudget);
  if (Number.isFinite(parsed) && parsed > 0) return Math.floor(parsed);
  if (plan === 'spark') return 0;
  return BLAZE_NO_COST_BYTES;
}

function limitsFor(plan, rawBudget) {
  const budget = resolveBudget(plan, rawBudget);
  const capacity = storageCapacity(plan);
  return {
    plan,
    budget,
    capacity,
    planFileMax: Math.floor(capacity * 0.9),
    perFileMax: Math.floor(budget * 0.8),
    usageStop: Math.floor(budget * 0.8),
    drivePlatformMax: DRIVE_PLATFORM_MAX_BYTES,
    driveProductMax: DRIVE_PRODUCT_MAX_BYTES,
    driveOptions: DRIVE_CAP_OPTIONS.slice(),
  };
}

function assessUpload({ plan, rawBudget, usedBytes, size, backend, driveCap, cloudCap }) {
  const limits = limitsFor(plan, rawBudget);
  if (!Number.isFinite(size) || size <= 0) return 'empty_message';
  if (backend === 'google_drive') {
    const cap = DRIVE_CAP_OPTIONS.includes(driveCap) ? driveCap : DRIVE_PRODUCT_MAX_BYTES;
    if (size > Math.floor(DRIVE_PLATFORM_MAX_BYTES * 0.9)) return 'plan_capacity';
    if (size > cap) return 'too_large';
    return null;
  }
  if (backend === 'google_cloud') {
    const cap = CLOUD_CAP_OPTIONS.includes(cloudCap) ? cloudCap : CLOUD_DEFAULT_BYTES;
    if (size > cap) return 'too_large';
    return null;
  }
  if (size > limits.planFileMax) return 'plan_capacity';
  if (size > limits.perFileMax) return 'too_large';
  const used = Math.max(0, usedBytes || 0);
  if (used >= limits.usageStop || used + size > limits.usageStop) return 'quota_project';
  return null;
}

module.exports = {
  SPARK_STORAGE_BYTES,
  BLAZE_OBJECT_MAX_BYTES,
  BLAZE_NO_COST_BYTES,
  DRIVE_PLATFORM_MAX_BYTES,
  DRIVE_PRODUCT_MAX_BYTES,
  DRIVE_CAP_OPTIONS,
  CLOUD_CAP_OPTIONS,
  CLOUD_DEFAULT_BYTES,
  KEEP_MS,
  GUEST_KEEP_MS,
  LOCK_MS,
  ORPHAN_MS,
  GUEST_ITEM_CAP,
  SIGNED_ITEM_CAP,
  storageCapacity,
  resolveBudget,
  limitsFor,
  assessUpload,
};
