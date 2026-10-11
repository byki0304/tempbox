'use strict';

async function accessToken(refreshToken) {
  const clientId = process.env.GOOGLE_OAUTH_CLIENT_ID;
  const clientSecret = process.env.GOOGLE_OAUTH_CLIENT_SECRET;
  if (!clientId || !clientSecret || !refreshToken) return null;
  const body = new URLSearchParams({
    client_id: clientId,
    client_secret: clientSecret,
    refresh_token: refreshToken,
    grant_type: 'refresh_token',
  });
  const response = await fetch('https://oauth2.googleapis.com/token', { method: 'POST', body });
  if (!response.ok) return null;
  const json = await response.json();
  return json.access_token || null;
}

async function openResumable({ refreshToken, fileName, mime, uploadId }) {
  const token = await accessToken(refreshToken);
  if (!token) {
    const error = new Error('drive_rejected');
    error.code = 'drive_rejected';
    throw error;
  }
  const response = await fetch('https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json; charset=UTF-8',
      'X-Upload-Content-Type': mime || 'application/octet-stream',
    },
    body: JSON.stringify({
      name: fileName,
      appProperties: { tempbox: '1', uploadId },
    }),
  });
  if (!response.ok) {
    const error = new Error('drive_rejected');
    error.code = 'drive_rejected';
    throw error;
  }
  return { uploadUrl: response.headers.get('location'), driveFileId: uploadId };
}

async function deleteDriveFile(fileId) {
  const token = await accessToken(process.env.GOOGLE_DRIVE_REFRESH_TOKEN || '');
  if (!token || !fileId) return;
  await fetch(`https://www.googleapis.com/drive/v3/files/${encodeURIComponent(fileId)}`, {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${token}` },
  });
}

module.exports = { openResumable, deleteDriveFile };
