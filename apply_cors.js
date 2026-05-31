const { Storage } = require('@google-cloud/storage');
const fs = require('fs');
const path = require('path');

async function configureBucketCors() {
  const bucketName = 'teamsync-6a35e.firebasestorage.app';
  const corsConfigPath = path.join(__dirname, 'cors.json');

  console.log('Reading CORS configurations...');
  const corsData = JSON.parse(fs.readFileSync(corsConfigPath, 'utf8'));

  // Initialize storage client. It will automatically pick up local application
  // default credentials or service account configurations.
  const storage = new Storage();

  try {
    console.log(`Applying CORS matrix to bucket: ${bucketName}...`);
    await storage.bucket(bucketName).setCorsConfiguration(corsData);
    console.log('🎉 SUCCESS: CORS configuration applied perfectly to Google Cloud Storage!');
  } catch (error) {
    console.error('❌ FAILED to update bucket metadata:', error);
    console.log('\n💡 Help: Ensure you have run "gcloud auth application-default login" or that your service account possesses Storage Admin roles.');
  }
}

configureBucketCors();
