const functions = require('firebase-functions');
const admin = require('firebase-admin');
const express = require('express');
const cors = require('cors');
const http = require('http');
const multer = require('multer');
const { Server } = require('socket.io');
const path = require('path');
const fs = require('fs');

const serviceAccountPath = path.join(__dirname, 'serviceAccountKey.json');

if (!admin.apps.length) {
  if (fs.existsSync(serviceAccountPath)) {
    const serviceAccount = require(serviceAccountPath);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: serviceAccount.project_id,
      storageBucket: 'teamsync-6a35e.firebasestorage.app',
    });
    console.log(`[ADMIN] Firebase Admin initialized with project: ${serviceAccount.project_id}`);
  } else {
    console.warn('[ADMIN] WARNING: serviceAccountKey.json not detected. Falling back to Application Default Credentials.');
    admin.initializeApp({
      projectId: 'teamsync-6a35e',
      storageBucket: 'teamsync-6a35e.firebasestorage.app',
    });
  }
}

const storageRouter = require('./routes/storage');

function createUploadApp() {
  const app = express();
  app.use(cors({ origin: true }));
  app.use(express.json({ limit: '1mb' }));

  const upload = multer({ storage: multer.memoryStorage() });

  app.use('/api/storage', storageRouter);

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
    socket.on('webrtc:register-user', (payload = {}) => {
      const userId = payload.userId || payload.uid || '';
      if (!userId) return;
      socket.data.userId = userId;
      socket.join(`user:${userId}`);
    });

    socket.on('webrtc:unregister-user', (payload = {}) => {
      const userId = payload.userId || payload.uid || socket.data.userId || '';
      if (!userId) return;
      socket.leave(`user:${userId}`);
    });

    socket.on('webrtc:join-room', (payload = {}) => {
      const roomId = payload.roomId || payload.callId || payload.projectId || '';
      if (!roomId) return;
      socket.data.roomId = roomId;
      socket.data.userId = payload.userId || '';
      socket.join(roomId);
      socket.to(roomId).emit('webrtc:peer-joined', {
        peerSocketId: socket.id,
        userId: socket.data.userId,
        roomId,
      });
    });

    socket.on('webrtc:leave-room', (payload = {}) => {
      const roomId = payload.roomId || socket.data.roomId;
      if (!roomId) return;
      socket.leave(roomId);
      socket.to(roomId).emit('webrtc:peer-left', {
        peerSocketId: socket.id,
        userId: socket.data.userId || '',
        roomId,
      });
    });

    socket.on('webrtc:offer', (payload = {}) => {
      const roomId = payload.roomId || socket.data.roomId;
      if (!roomId) return;

      const envelope = {
        ...payload,
        fromSocketId: socket.id,
        fromUserId: socket.data.userId || '',
        roomId,
        createdAt: Date.now(),
      };

      socket.to(roomId).emit('webrtc:offer', envelope);
      socket.to(roomId).emit('signal', { type: 'offer', ...envelope });
    });

    socket.on('webrtc:answer', (payload = {}) => {
      const roomId = payload.roomId || socket.data.roomId;
      if (!roomId) return;

      const envelope = {
        ...payload,
        fromSocketId: socket.id,
        fromUserId: socket.data.userId || '',
        roomId,
        createdAt: Date.now(),
      };

      socket.to(roomId).emit('webrtc:answer', envelope);
      socket.to(roomId).emit('signal', { type: 'answer', ...envelope });
    });

    socket.on('webrtc:ice-candidate', (payload = {}) => {
      const roomId = payload.roomId || socket.data.roomId;
      if (!roomId) return;

      const envelope = {
        ...payload,
        fromSocketId: socket.id,
        fromUserId: socket.data.userId || '',
        roomId,
        createdAt: Date.now(),
      };

      socket.to(roomId).emit('webrtc:ice-candidate', envelope);
      socket.to(roomId).emit('signal', { type: 'ice-candidate', ...envelope });
    });

    socket.on('webrtc:incoming-call', (payload = {}) => {
      const targetUserId = payload.targetUserId || '';
      if (!targetUserId) return;
      io.to(`user:${targetUserId}`).emit('webrtc:incoming-call', {
        ...payload,
        fromSocketId: socket.id,
        fromUserId: socket.data.userId || '',
        createdAt: Date.now(),
      });
    });

    socket.on('webrtc:hangup', (payload = {}) => {
      const roomId = payload.roomId || socket.data.roomId;
      if (!roomId) return;
      socket.to(roomId).emit('webrtc:hangup', {
        ...payload,
        fromSocketId: socket.id,
        fromUserId: socket.data.userId || '',
        createdAt: Date.now(),
      });
    });

    socket.on('join-room', (payload = {}) => {
      const roomId = payload.roomId || payload.callId || payload.projectId || '';
      if (!roomId) return;
      socket.data.roomId = roomId;
      socket.data.userId = payload.userId || '';
      socket.join(roomId);
      socket.to(roomId).emit('webrtc:peer-joined', {
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
      socket.to(roomId).emit('webrtc:peer-left', {
        peerSocketId: socket.id,
        userId: socket.data.userId || '',
        roomId,
      });
    });

    socket.on('disconnect', () => {
      const roomId = socket.data.roomId;
      if (!roomId) return;
      socket.to(roomId).emit('webrtc:peer-left', {
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

function buildNotificationRoute(notification) {
  const data = notification?.data || {};
  const explicitRoute = String(data.route || notification.route || '').trim();
  if (explicitRoute) {
    return explicitRoute;
  }

  const projectId = String(notification.projectId || data.projectId || '').trim();
  const type = String(notification.type || data.type || '').trim();
  if (projectId) {
    if (type === 'chat_message') {
      return `/project/${projectId}/workspace/chat`;
    }
    return `/project/${projectId}`;
  }

  return '/notifications';
}

function normalizeTokens(userData) {
  const tokenValues = [userData.fcm_token, userData.deviceToken, userData.token]
    .filter(Boolean)
    .map((token) => String(token).trim())
    .filter(Boolean);

  const arrayValues = [userData.fcmTokens, userData.deviceTokens, userData.tokens]
    .flatMap((value) => (Array.isArray(value) ? value : []))
    .filter(Boolean)
    .map((token) => String(token).trim())
    .filter(Boolean);

  return Array.from(new Set([...tokenValues, ...arrayValues]));
}

async function sendNotificationPush(recipientId, notification, notificationId) {
  const userDoc = await admin.firestore().collection('users').doc(recipientId).get();
  if (!userDoc.exists) {
    return null;
  }

  const userData = userDoc.data() || {};
  if (userData.pushNotificationsEnabled === false) {
    console.log(`Skipping FCM send for ${recipientId}: push notifications disabled`);
    return null;
  }

  const tokens = normalizeTokens(userData);
  if (!tokens.length) {
    console.log('No device tokens to send to for user', recipientId);
    return null;
  }

  const route = buildNotificationRoute(notification);
  const payloadData = Object.fromEntries(
    Object.entries(Object.assign({}, notification.data || {}, {
      notificationId,
      userId: recipientId,
      projectId: String(notification.projectId || notification?.data?.projectId || ''),
      type: String(notification.type || notification?.data?.type || ''),
      route,
    })).map(([key, value]) => [key, String(value ?? '')]),
  );

  const message = {
    tokens,
    notification: {
      title: notification.title || 'TeamSync',
      body: notification.body || '',
    },
    data: payloadData,
  };

  const response = await admin.messaging().sendEachForMulticast(message);
  const invalidTokens = [];

  response.responses.forEach((result, index) => {
    if (!result.success) {
      const errorCode = result.error?.code || '';
      const token = tokens[index];
      console.warn('FCM send error for token', token, errorCode || result.error?.message || result.error);
      if (
        errorCode === 'messaging/registration-token-not-registered' ||
        errorCode === 'messaging/invalid-registration-token'
      ) {
        invalidTokens.push(token);
      }
    }
  });

  if (invalidTokens.length) {
    const remainingTokens = tokens.filter((token) => !invalidTokens.includes(token));
    await admin.firestore().collection('users').doc(recipientId).update({
      fcm_token: remainingTokens[0] || null,
      fcmTokens: remainingTokens,
      deviceTokens: remainingTokens,
      tokens: remainingTokens,
    });
  }

  return null;
}

// Firestore trigger: send push when a root notification document is created.
exports.sendNotificationOnNotificationCreate = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, ctx) => {
    try {
      const notification = snap.data() || {};
      const recipientId = notification.userId || '';
      if (!recipientId) {
        return null;
      }

      const senderId = notification?.data?.senderId || notification?.senderId || null;
      if (senderId && senderId === recipientId) {
        console.log('Skipping FCM send: recipient is the sender');
        return null;
      }

      return await sendNotificationPush(recipientId, notification, snap.id);
    } catch (e) {
      console.error('Error in sendNotificationOnNotificationCreate:', e);
      return null;
    }
  });

// Backwards-compatible trigger for older user-scoped notification docs.
exports.sendNotificationOnUserNotification = functions.firestore
  .document('users/{userId}/notifications/{notificationId}')
  .onCreate(async (snap, ctx) => {
    try {
      const notification = snap.data() || {};
      const recipientId = ctx.params.userId;
      return await sendNotificationPush(recipientId, notification, snap.id);
    } catch (e) {
      console.error('Error in sendNotificationOnUserNotification:', e);
      return null;
    }
  });
