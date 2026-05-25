const fetch = require('node-fetch');
const fs = require('fs');

async function main() {
  const region = process.env.FIREBASE_REGION || 'us-central1';
  const project = process.env.FIREBASE_PROJECT;
  if (!project) {
    console.error('FIREBASE_PROJECT not set');
    process.exit(2);
  }
  const url = `https://${region}-${project}.cloudfunctions.net/app/upload`;
  const filePath = 'e2e/test_upload.txt';
  const stats = fs.statSync(filePath);
  const fileStream = fs.createReadStream(filePath);

  const FormData = require('form-data');
  const form = new FormData();
  form.append('files', fileStream, { filename: 'test_upload.txt' });
  form.append('projectId', 'e2e-test');

  console.log('Posting to', url);
  const res = await fetch(url, { method: 'POST', headers: { 'x-user-id': 'ci@test' }, body: form });
  const body = await res.text();
  console.log('Response status', res.status);
  console.log(body);
  if (res.status !== 200) process.exit(1);
}

main().catch((e) => { console.error(e); process.exit(1); });
