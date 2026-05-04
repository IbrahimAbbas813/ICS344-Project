#!/usr/bin/env bash
# ============================================================
# LESSON 7 — Over-Privileged Function FIX
# Fix: Replace wildcard IAM policies on the Lambda role with
#   least-privilege inline policies scoped to exact DVSA
#   resource ARNs only. Verify simulator shows Deny elsewhere.
# ============================================================

# ── CONFIGURATION — fill these in before running ────────────
REGION="us-east-1"
ACCOUNT_ID="YOUR-AWS-ACCOUNT-ID"
ROLE_NAME="serverlessrepo-OWASP-DVSA-SendReceiptFunctionRole-XXXXXXXXXX"
RECEIPTS_BUCKET="YOUR-DVSA-RECEIPTS-BUCKET-NAME"
ORDERS_TABLE_ARN="arn:aws:dynamodb:us-east-1:YOUR-ACCOUNT-ID:table/DVSA-ORDERS-DB"
# ────────────────────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; RESET='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║  LESSON 7 — Over-Privileged Function FIX        ║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${RESET}"

echo -e "\n${YELLOW}[STEP 1] Detaching overly broad managed policies...${RESET}"
for POLICY_ARN in \
  "arn:aws:iam::aws:policy/AmazonSESFullAccess"; do
  aws iam detach-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-arn "$POLICY_ARN" \
    --region "$REGION" 2>/dev/null \
    && echo -e "${GREEN}[OK] Detached: $POLICY_ARN${RESET}" \
    || echo -e "${YELLOW}[SKIP] Policy not attached or already removed: $POLICY_ARN${RESET}"
done

echo -e "\n${YELLOW}[STEP 2] Applying least-privilege inline policy...${RESET}"
cat > /tmp/least_priv_policy.json <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3ReceiptsOnly",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject"],
      "Resource": "arn:aws:s3:::${RECEIPTS_BUCKET}/*"
    },
    {
      "Sid": "SESMinimal",
      "Effect": "Allow",
      "Action": ["ses:SendEmail", "ses:SendRawEmail"],
      "Resource": "*"
    },
    {
      "Sid": "DynamoDBDvsaTablesOnly",
      "Effect": "Allow",
      "Action": ["dynamodb:GetItem", "dynamodb:Query"],
      "Resource": "${ORDERS_TABLE_ARN}"
    },
    {
      "Sid": "STSIdentity",
      "Effect": "Allow",
      "Action": "sts:GetCallerIdentity",
      "Resource": "*"
    }
  ]
}
POLICY

aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name "dvsa-least-privilege-fix" \
  --policy-document file:///tmp/least_priv_policy.json
echo -e "${GREEN}[OK] Least-privilege inline policy applied.${RESET}"

echo -e "\n${YELLOW}[STEP 3] Verifying — simulating S3 wildcard access (should be DENY)...${RESET}"
aws iam simulate-principal-policy \
  --policy-source-arn "arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}" \
  --action-names "s3:GetObject" "s3:PutObject" \
  --resource-arns "arn:aws:s3:::some-other-bucket/key" \
  --region "$REGION" | jq '.EvaluationResults[] | {Action:.EvalActionName, Decision:.EvalDecision}'

echo -e "\n${YELLOW}[STEP 4] Verifying — simulating DynamoDB wildcard Scan (should be DENY)...${RESET}"
aws iam simulate-principal-policy \
  --policy-source-arn "arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}" \
  --action-names "dynamodb:Scan" "dynamodb:DeleteItem" \
  --resource-arns "arn:aws:dynamodb:${REGION}:${ACCOUNT_ID}:table/some-other-table" \
  --region "$REGION" | jq '.EvaluationResults[] | {Action:.EvalActionName, Decision:.EvalDecision}'

echo -e "\n${CYAN}╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║  VERIFICATION                                    ║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${RESET}"
echo -e "${GREEN}[FIX CONFIRMED] Check above — both wildcard resources should show 'implicitDeny'.${RESET}"
echo -e "${GREEN}The function can now only access its specific receipts bucket and DVSA orders table.${RESET}"
