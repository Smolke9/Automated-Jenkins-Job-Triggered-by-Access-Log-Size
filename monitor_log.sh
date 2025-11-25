#!/bin/bash

#=========================
# CONFIGURATION
#=========================
FILE="/var/log/custom/access.log"
MAX_SIZE=$((1024 * 1024 * 1024))   # 1 GB

# Jenkins details
JENKINS_URL="http://localhost:8080"
JENKINS_USER="suraj"
JENKINS_API_TOKEN="113f60d7da9c63c40bf18d4d58e95fca"
JOB_NAME="UploadtoS3"        # MUST MATCH YOUR PIPELINE JOB NAME EXACTLY

#=========================
# CHECK LOG FILE EXISTS
#=========================
if [ ! -f "$FILE" ]; then
  echo "[ERROR] File not found: $FILE"
  exit 1
fi

#=========================
# CHECK FILE SIZE
#=========================
FILE_SIZE=$(stat -c%s "$FILE")

echo "Current file size: $FILE_SIZE bytes"

if [ "$FILE_SIZE" -lt "$MAX_SIZE" ]; then
  echo "[INFO] File size is below 1GB. No action taken."
  exit 0
fi

echo "[INFO] File exceeded 1GB. Triggering Jenkins job..."

#=========================
# GET JENKINS CRUMB
#=========================
CRUMB_JSON=$(curl -s -u "$JENKINS_USER:$JENKINS_API_TOKEN" \
  "$JENKINS_URL/crumbIssuer/api/json")

if [ -z "$CRUMB_JSON" ]; then
  echo "[ERROR] Could not fetch Jenkins crumb. Check API token or Jenkins URL."
  exit 1
fi

CRUMB_FIELD=$(echo "$CRUMB_JSON" | jq -r '.crumbRequestField')
CRUMB_VALUE=$(echo "$CRUMB_JSON" | jq -r '.crumb')

if [ -z "$CRUMB_FIELD" ] || [ -z "$CRUMB_VALUE" ]; then
  echo "[ERROR] Invalid crumb response. Check Jenkins CSRF settings."
  exit 1
fi

CRUMB_HEADER="$CRUMB_FIELD: $CRUMB_VALUE"

#=========================
# TRIGGER JENKINS JOB
#=========================
echo "[INFO] Triggering Jenkins job: $JOB_NAME"

curl -X POST "$JENKINS_URL/job/$JOB_NAME/buildWithParameters" \
  --user "$JENKINS_USER:$JENKINS_API_TOKEN" \
  -H "$CRUMB_HEADER" \
  --data-urlencode "LOG_PATH=$FILE"

if [ $? -eq 0 ]; then
  echo "[SUCCESS] Jenkins job triggered successfully!"
else
  echo "[ERROR] Failed to trigger Jenkins job."
  exit 1
fi

exit 0
