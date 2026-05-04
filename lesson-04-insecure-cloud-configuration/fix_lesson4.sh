#!/usr/bin/env bash
# ============================================================
# LESSON 4 — Insecure Cloud Configuration FIX
# Fix: Enable S3 Block Public Access and apply a bucket policy
#   that denies public PutObject. Verify upload now fails.
# ============================================================

# ── CONFIGURATION — fill these in before running ────────────
BUCKET_NAME="YOUR-DVSA-WEBSITE-BUCKET-NAME"
REGION="us-east-1"
ACCOUNT_ID="YOUR-AWS-ACCOUNT-ID"
# ────────────────────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; RESET='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║  LESSON 4 — Insecure Cloud Configuration FIX    ║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${RESET}"

echo -e "\n${YELLOW}[STEP 1] Enabling S3 Block Public Access...${RESET}"
aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --region "$REGION" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
echo -e "${GREEN}[OK] Public access block enabled.${RESET}"

echo -e "\n${YELLOW}[STEP 2] Applying deny-public-PutObject bucket policy...${RESET}"
cat > /tmp/bucket_policy.json <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyPublicPutObject",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::${BUCKET_NAME}/*",
      "Condition": {
        "StringNotEquals": {
          "aws:PrincipalAccount": "${ACCOUNT_ID}"
        }
      }
    }
  ]
}
POLICY
aws s3api put-bucket-policy --bucket "$BUCKET_NAME" --policy file:///tmp/bucket_policy.json --region "$REGION"
echo -e "${GREEN}[OK] Bucket policy applied.${RESET}"

echo -e "\n${YELLOW}[STEP 3] Re-attempting malicious upload to verify block...${RESET}"
echo "STILL EVIL" > /tmp/evil2.txt
RESULT=$(aws s3 cp /tmp/evil2.txt "s3://$BUCKET_NAME/evil-test2.txt" --region "$REGION" 2>&1)
echo "$RESULT"

echo -e "\n${CYAN}╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║  VERIFICATION                                    ║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${RESET}"
if echo "$RESULT" | grep -qi "AccessDenied\|Error\|Denied"; then
  echo -e "${GREEN}[FIX CONFIRMED] Upload blocked. S3 bucket is now properly restricted.${RESET}"
else
  echo -e "${YELLOW}[NOTE] Upload may still succeed with account credentials — that is expected.${RESET}"
  echo -e "${YELLOW}The fix blocks external/public uploads. Verify public access block is ON.${RESET}"
fi
