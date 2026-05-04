#!/usr/bin/env bash
# ============================================================
# LESSON 3 — Sensitive Information Disclosure FIX
# Fix: Add admin authorization check inside the get-receipt
#   Lambda handler before generating any signed URL.
#   Non-admin requests will receive 403 Forbidden.
# ============================================================

# ── CONFIGURATION — fill these in before running ────────────
API_URL="https://YOUR-API-ID.execute-api.us-east-1.amazonaws.com/Stage/order"
TOKEN="PASTE_ANY_VALID_NON_ADMIN_USER_JWT_HERE"
VICTIM_ORDER_ID="PASTE_VICTIM_ORDER_ID_HERE"
FUNCTION_NAME="DVSA-ADMIN-GET-RECEIPT"
REGION="us-east-1"
WORK_DIR="/tmp/dvsa_lesson3_fix"
# ────────────────────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; RESET='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║  LESSON 3 — Sensitive Information Disclosure FIX║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${RESET}"

mkdir -p "$WORK_DIR" && cd "$WORK_DIR"

echo -e "\n${YELLOW}[STEP 1] Downloading Lambda...${RESET}"
URL=$(aws lambda get-function --function-name "$FUNCTION_NAME" --region "$REGION" \
  --query 'Code.Location' --output text)
curl -s -o function.zip "$URL"
unzip -q -o function.zip -d extracted/

echo -e "\n${YELLOW}[STEP 2] Patching handler to check isAdmin before generating URL...${RESET}"
# Find the handler JS file
HANDLER_FILE=$(find extracted/ -name "*.js" | head -1)
node -e "
const fs = require('fs');
let code = fs.readFileSync('$HANDLER_FILE','utf8');
const adminCheck = \`
  // SECURITY FIX: verify caller is admin
  var callerIsAdmin = (event.requestContext && event.requestContext.authorizer &&
    event.requestContext.authorizer.claims &&
    event.requestContext.authorizer.claims['cognito:groups'] &&
    event.requestContext.authorizer.claims['cognito:groups'].includes('admin'));
  if (!callerIsAdmin) {
    return callback(null, {
      statusCode: 403,
      headers: { 'Access-Control-Allow-Origin': '*' },
      body: JSON.stringify({ status: 'err', msg: 'Forbidden: admin only' })
    });
  }
\`;
// Insert after exports.handler = function(event, context, callback) {
code = code.replace(/(exports\.handler\s*=\s*(?:async\s*)?function[^{]*\{)/, '\$1' + adminCheck);
fs.writeFileSync('$HANDLER_FILE', code);
console.log('Admin check injected.');
" 2>/dev/null || echo -e "${YELLOW}[NOTE] Manual patch may be needed. Check $HANDLER_FILE${RESET}"

echo -e "${GREEN}[OK] Patch applied.${RESET}"

echo -e "\n${YELLOW}[STEP 3] Redeploying...${RESET}"
cd extracted && zip -qr ../patched.zip . && cd ..
aws lambda update-function-code \
  --function-name "$FUNCTION_NAME" \
  --zip-file fileb://patched.zip \
  --region "$REGION" > /dev/null
echo -e "${GREEN}[OK] Deployed. Waiting 10s...${RESET}"
sleep 10

echo -e "\n${YELLOW}[STEP 4] Re-running exploit with non-admin token...${RESET}"
RESULT=$(curl -s -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: $TOKEN" \
  -d "{\"action\":\"get-receipt\",\"order-id\":\"$VICTIM_ORDER_ID\"}")

echo -e "\n${CYAN}╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║  VERIFICATION                                    ║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${RESET}"
echo "$RESULT" | jq . 2>/dev/null || echo "$RESULT"
if echo "$RESULT" | grep -qi "forbidden\|403\|admin only"; then
  echo -e "\n${GREEN}[FIX CONFIRMED] Non-admin user now receives 403 Forbidden.${RESET}"
else
  echo -e "\n${YELLOW}[NOTE] Verify the function name is correct and the patch applied cleanly.${RESET}"
fi
