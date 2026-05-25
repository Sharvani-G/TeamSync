const functions = require('firebase-functions');
const admin = require('firebase-admin');
const express = require('express');
const cors = require('cors');
const multer = require('multer');

admin.initializeApp();

const app = express();
app.use(cors({ origin: true }));

const upload = multer({ storage: multer.memoryStorage() });

// POST /upload
// Accepts multipart/form-data with field `files` and optional metadata fields:
// projectId, channelId, blockId, levelId, messageId, storagePathPrefix
app.post('/upload', upload.array('files'), async (req, res) => {
  try {
    const files = req.files || [];
    const {
      projectId = '',
      channelId = '',
      blockId = '',
      levelId = '',
      messageId = '',
      storagePathPrefix = '',
    } = req.body || {};

    if (!files.length) {
      return res.status(400).json({ error: 'No files uploaded' });
    }

    const bucket = admin.storage().bucket();

    const results = [];
    for (let i = 0; i < files.length; i++) {
      const f = files[i];
      const fileId = admin.firestore().collection('attachments').doc().id;
      const pathPrefix = storagePathPrefix || `project_files/${projectId}/${blockId || messageId || fileId}`;
      const destination = `${pathPrefix}/${fileId}`;

      const file = bucket.file(destination);
      await file.save(f.buffer, {
        metadata: {
          contentType: f.mimetype || 'application/octet-stream',
          metadata: {
            uploadedBy: req.get('x-user-id') || '',
            fileName: f.originalname,
            projectId,
            channelId,
            blockId,
            levelId,
            messageId,
          },
        },
      });

      // Make the file publically readable if you prefer, or generate signed URL
      const [url] = await file.getSignedUrl({ action: 'read', expires: Date.now() + 1000 * 60 * 60 * 24 * 365 });

      const metadata = {
        id: fileId,
        name: f.originalname,
        mimeType: f.mimetype || '',
        size: f.size || 0,
        downloadUrl: url,
        uploadedBy: req.get('x-user-id') || '',
        createdAt: new Date().toISOString(),
        storagePath: destination,
      };

      // Persist attachment metadata in Firestore for durability
      try {
        await admin.firestore().collection('attachments').doc(fileId).set({
          id: metadata.id,
          name: metadata.name,
          mimeType: metadata.mimeType,
          size: metadata.size,
          downloadUrl: metadata.downloadUrl,
          uploadedBy: metadata.uploadedBy,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          storagePath: metadata.storagePath,
          projectId,
          channelId,
          blockId,
          levelId,
          messageId,
        });
      } catch (err) {
        console.error('Failed to persist attachment metadata', err);
      }

      results.push(metadata);
    }

    return res.json({ files: results });
  } catch (e) {
    console.error('Upload error', e);
    return res.status(500).json({ error: e.message || String(e) });
  }
});

exports.app = functions.https.onRequest(app);

if (require.main === module) {
  const port = Number(process.env.PORT || 5001);
  app.listen(port, () => {
    console.log(`Upload proxy listening on http://127.0.0.1:${port}`);
  });
}
