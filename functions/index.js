const functions = require('firebase-functions');
const admin = require('firebase-admin');
const express = require('express');
const cors = require('cors');
const http = require('http');
const multer = require('multer');
const { Server } = require('socket.io');

admin.initializeApp();

function createUploadApp() {
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

        // Make the file publicly readable if you prefer, or generate signed URL
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

  return app;
}

function attachSocketServer(httpServer) {
  const io = new Server(httpServer, {
    cors: {
      origin: true,
      methods: ['GET', 'POST'],
    },
  });

  io.on('connection', (socket) => {
    socket.on('join-room', (payload = {}) => {
      const roomId = payload.roomId || payload.callId || payload.projectId || '';
      if (!roomId) return;
      socket.data.roomId = roomId;
      socket.data.userId = payload.userId || '';
      socket.join(roomId);
      socket.to(roomId).emit('peer-joined', {
        peerSocketId: socket.id,
        userId: socket.data.userId,
        roomId,
      });
    });

    socket.on('signal', (payload = {}) => {
      const roomId = payload.roomId || socket.data.roomId;
      if (!roomId) return;

      const envelope = {
        fromSocketId: socket.id,
        fromUserId: socket.data.userId || '',
        roomId,
        targetSocketId: payload.targetSocketId || '',
        type: payload.type || 'signal',
        data: payload.data ?? payload,
        createdAt: Date.now(),
      };

      if (payload.targetSocketId) {
        io.to(payload.targetSocketId).emit('signal', envelope);
      } else {
        socket.to(roomId).emit('signal', envelope);
      }
    });

    socket.on('leave-room', (payload = {}) => {
      const roomId = payload.roomId || socket.data.roomId;
      if (!roomId) return;
      socket.leave(roomId);
      socket.to(roomId).emit('peer-left', {
        peerSocketId: socket.id,
        userId: socket.data.userId || '',
        roomId,
      });
    });

    socket.on('disconnect', () => {
      const roomId = socket.data.roomId;
      if (!roomId) return;
      socket.to(roomId).emit('peer-left', {
        peerSocketId: socket.id,
        userId: socket.data.userId || '',
        roomId,
      });
    });
  });

  return io;
}

const uploadApp = createUploadApp();

exports.app = functions.https.onRequest(uploadApp);
exports.createUploadApp = createUploadApp;
exports.attachSocketServer = attachSocketServer;

if (require.main === module) {
  const port = Number(process.env.PORT || 5001);
  const server = http.createServer(uploadApp);
  attachSocketServer(server);
  server.listen(port, () => {
    console.log(`Upload + signaling server listening on http://127.0.0.1:${port}`);
  });
}

// Firestore trigger: when a notification doc is created under users/{userId}/notifications/{notificationId}
// send an FCM push to the user's device tokens while ensuring the sender never receives their own notification.
exports.sendNotificationOnUserNotification = functions.firestore
  .document('users/{userId}/notifications/{notificationId}')
  .onCreate(async (snap, ctx) => {
    try {
      const notification = snap.data() || {};
      const recipientId = ctx.params.userId;

      // If notification data explicitly indicates a sender, and it's the same as the recipient, skip.
      const senderId = notification?.data?.senderId || notification?.senderId || null;
      if (senderId && senderId === recipientId) {
        console.log('Skipping FCM send: recipient is the sender');
        return null;
      }

      // Load recipient user document to obtain device tokens (field names may vary)
      const userDoc = await admin.firestore().collection('users').doc(recipientId).get();
      if (!userDoc.exists) return null;
      const userData = userDoc.data() || {};

      // Common token fields: deviceTokens, fcmTokens, tokens
      const tokensRaw = userData.deviceTokens || userData.fcmTokens || userData.tokens || [];
      const tokens = Array.isArray(tokensRaw) ? tokensRaw.filter(Boolean) : [];

      // Optionally the notification may carry the sender's device token; exclude it
      const senderToken = notification?.senderToken || notification?.data?.senderToken || null;
      const senderUid = notification?.senderUid || notification?.data?.senderUid || notification?.data?.senderId || null;

      const filteredTokens = tokens.filter((t) => {
        if (!t) return false;
        if (t === senderToken) return false;
        if (t === senderUid) return false;
        return true;
      });
      if (!filteredTokens.length) {
        console.log('No device tokens to send to for user', recipientId);
        return null;
      }

      // Build payload
      const payload = {
        notification: {
          title: notification.title || 'TeamSync',
          body: notification.body || '',
        },
        data: Object.assign({}, notification.data || {}, {
          notificationId: snap.id,
        }),
      };

      const response = await admin.messaging().sendToDevice(filteredTokens, payload);

      // Clean up invalid tokens
      const tokensToRemove = [];
      if (response && response.results) {
        response.results.forEach((result, idx) => {
          if (result.error) {
            const err = result.error;
            const token = filteredTokens[idx];
            // Remove unregistered or invalid tokens from user doc
            if (err.code === 'messaging/registration-token-not-registered' || err.code === 'messaging/invalid-registration-token') {
              tokensToRemove.push(token);
            }
            console.warn('FCM send error for token', token, err.code || err.message || err);
          }
        });
      }

      if (tokensToRemove.length) {
        const remaining = tokens.filter((t) => !tokensToRemove.includes(t));
        await admin.firestore().collection('users').doc(recipientId).update({
          deviceTokens: remaining,
          fcmTokens: remaining,
        });
      }

      return null;
    } catch (e) {
      console.error('Error in sendNotificationOnUserNotification:', e);
      return null;
    }
  });
