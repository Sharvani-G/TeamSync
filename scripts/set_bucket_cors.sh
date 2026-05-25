#!/usr/bin/env bash
# Usage: ./set_bucket_cors.sh <BUCKET_NAME>
# This script requires the Google Cloud SDK (gsutil) to be installed and
# authenticated (e.g., run `gcloud auth login` or set application default creds).

if [ -z "$1" ]; then
  echo "Usage: $0 <BUCKET_NAME>"
  exit 1
fi
BUCKET=$1

cat > /tmp/cors.json <<EOF
[
  {
    "origin": ["http://localhost:8080", "http://127.0.0.1:8080", "http://localhost:8081", "http://127.0.0.1:8081"],
    "method": ["GET", "HEAD", "PUT", "POST", "DELETE"],
    "responseHeader": ["Content-Type", "x-goog-resumable", "Authorization", "x-user-id"],
    "maxAgeSeconds": 3600
  }
]
EOF

echo "Applying CORS to gs://$BUCKET"
gsutil cors set /tmp/cors.json gs://$BUCKET
echo "Done. You may want to verify with: gsutil cors get gs://$BUCKET"
