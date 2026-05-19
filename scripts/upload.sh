#!/usr/bin/env bash
set -euo pipefail

AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
BUCKET="example-demo-uploads"

file="${1:?usage: upload.sh <file>}"
key="$(basename "$file")"
date_stamp="$(date -u +%Y%m%dT%H%M%SZ)"

aws s3 cp "$file" "s3://${BUCKET}/${key}" \
  --no-progress \
  --metadata "uploaded-at=${date_stamp}"

echo "uploaded ${file} -> s3://${BUCKET}/${key}"
