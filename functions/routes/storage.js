const express = require('express');
const admin = require('firebase-admin');
const { v2: cloudinary } = require('cloudinary');

const router = express.Router();

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME || 'dkrfetmrq',
  api_key: process.env.CLOUDINARY_API_KEY || '823464582758267',
  api_secret: process.env.CLOUDINARY_API_SECRET || '1PHSyZI9n9MfVmEIrzU2xSk4t_w',
  secure: true,
});

async function verifyFirebaseToken(req, res, next) {
  console.log('[AUTH] verifyFirebaseToken channel triggered');
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    console.error('[AUTH] FAILURE: Malformed or missing Bearer authorization string token.');
    return res.status(401).json({ error: 'Missing auth token', detail: 'No Bearer token present in payload headers' });
  }

  try {
    const token = authHeader.split('Bearer ')[1];
    const decodedToken = await admin.auth().verifyIdToken(token);
    console.log(`[AUTH] SUCCESS: Verified Identity Context for uid=${decodedToken.uid} targeting aud=${decodedToken.aud}`);
    req.user = decodedToken;
    return next();
  } catch (err) {
    console.error('[AUTH] EXCEPTION: Cryptographic verification signature dropped:', err.code, err.message);
    return res.status(401).json({ error: 'Invalid auth token', detail: err.message, code: err.code });
  }
}

function isSupportedMimeType(mimeType) {
  const normalized = mimeType.trim().toLowerCase();

  if (normalized.startsWith('image/')) {
    return true;
  }

  return [
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'text/plain',
    'text/csv',
    'application/csv',
    'application/zip',
    'application/x-zip-compressed',
  ].includes(normalized);
}

function buildCloudinaryFolder(context) {
  const projectId = context.projectId.trim();
  const sectionName = (context.sectionName || '').trim() || ((context.type || '').trim().toLowerCase() === 'ideaboard' ? 'idea-board' : (context.type || 'files').trim());

  if ((context.type || '').trim().toLowerCase() === 'chat') {
    const channelId = (context.channelId || '').trim();
    return `teamsync/${projectId}/chat/${channelId}`;
  }

  if ((context.type || '').trim().toLowerCase() === 'ideaboard') {
    const levelId = (context.levelId || '').trim();
    const blockId = (context.blockId || '').trim();
    return `teamsync/${projectId}/${sectionName}/${levelId}/${blockId}`;
  }

  return `teamsync/${projectId}/${sectionName}`;
}

router.post('/cloudinary-signature', verifyFirebaseToken, async (req, res) => {
  try {
    const { fileName, mimeType, fileSize, context } = req.body || {};
    const uid = req.user.uid;

    if (!fileName || !mimeType || fileSize == null || !context || !context.projectId) {
      return res.status(400).json({ error: 'Missing required fields.' });
    }
    if (Number(fileSize) > 10 * 1024 * 1024) {
      return res.status(400).json({ error: 'File too large. Maximum size is 10MB.' });
    }
    if (!isSupportedMimeType(mimeType)) {
      return res.status(400).json({ error: 'File type not supported.' });
    }

    const cloudName = process.env.CLOUDINARY_CLOUD_NAME || 'dkrfetmrq';
    const apiKey = process.env.CLOUDINARY_API_KEY || '823464582758267';
    const apiSecret = process.env.CLOUDINARY_API_SECRET || '1PHSyZI9n9MfVmEIrzU2xSk4t_w';

    if (!cloudName || !apiKey || !apiSecret) {
      return res.status(500).json({ error: 'Cloudinary credentials are not configured.' });
    }

    const folder = buildCloudinaryFolder(context);
    const timestamp = Math.floor(Date.now() / 1000);
    const signature = cloudinary.utils.api_sign_request(
      { folder, timestamp },
      apiSecret,
    );

    const uploadUrl = `https://api.cloudinary.com/v1_1/${cloudName}/auto/upload`;

    console.log(`[CLOUDINARY] Signature generated for uid=${uid} folder=${folder}`);
    return res.json({
      uploadUrl,
      apiKey: apiKey,
      timestamp,
      signature,
      folder,
    });
  } catch (err) {
    console.error('[CLOUDINARY] Signature generation failed:', err);
    return res.status(500).json({ error: err.message || 'Cloudinary signature generation failed.' });
  }
});

module.exports = router;