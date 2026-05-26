const http = require('http');

const { createUploadApp, attachSocketServer } = require('./index');

const port = Number(process.env.PORT || 8080);
const app = createUploadApp();
const server = http.createServer(app);

attachSocketServer(server);

server.listen(port, () => {
  console.log(`TeamSync signaling server listening on http://127.0.0.1:${port}`);
});