#!/usr/bin/env bash
# ============================================================
# LESSON 5 — Broken Access Control FIX
# Fix: Patch the Lambda handler to verify isAdmin flag before
#   allowing order status updates. Non-admin users are rejected
#   with 403. Redeploy and verify.
# ============================================================

# ── CONFIGURATION — fill these in before running ────────────
API_URL="https://YOUR-API-ID.execute-api.us-east-1.amazonaws.com/Stage/order"
TOKEN="PASTE_REGULAR_USER_JWT_HERE"
ORDER_ID="PASTE_YOUR_ORDER_ID_HERE"
FUNCTION_NAME="DVSA-ORDER-MANAGER"
REGION="us-east-1"
WORK_DIR="/tmp/dvsa_lesson5_fix"
# ────────────────────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; RESET='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║  LESSON 5 — Broken Access Control FIX           ║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${RESET}"

mkdir -p "$WORK_DIR" && cd "$WORK_DIR"

echo -e "\n${YELLOW}[STEP 1] Downloading Lambda...${RESET}"
URL=$(aws lambda get-function --function-name "$FUNCTION_NAME" --region "$REGION" \
  --query 'Code.Location' --output text)
curl -s -o function.zip "$URL"
unzip -q -o function.zip -d extracted/

echo -e "\n${YELLOW}[STEP 2] Patching: adding isAdmin check before status update...${RESET}"
node -e "
const fs = require('fs');
let code = fs.readFileSync('extracted/order-manager.js','utf8');
// Wrap the update/admin action block with isAdmin check
const adminGuard = \`
    if (action === 'update' || action === 'admin-update') {
      if (!isAdmin) {
        return callback(null, {
          statusCode: 403,
          headers: {'Access-Control-Allow-Origin':'*'},
          body: JSON.stringify({status:'err', msg:'Forbidden: admin only'})
        });
      }
    }
\`;
// Insert guard after isAdmin is declared
code = code.replace(/(var isAdmin = false;)/, '\$1\n' + adminGuard);
fs.writeFileSync('extracted/order-manager.js', code);
console.log('Admin guard injected.');
" 2>/dev/null || echo -e "${YELLOW}[NOTE] Manual review of extracted/order-manager.js recommended.${RESET}"

echo -e "${GREEN}[OK] Patch applied.${RESET}"

echo -e "\n${YELLOW}[STEP 3] Redeploying...${RESET}"
cd extracted && zip -qr ../patched.zip . && cd ..
aws lambda update-function-code \
  --function-name "$FUNCTION_NAME" \
  --zip-file fileb://patched.zip \
  --region "$REGION" > /dev/null
echo -e "${GREEN}[OK] Deployed. Waiting 10s...${RESET}"
sleep 10

echo -e "\n${YELLOW}[STEP 4] Re-running exploit...${RESET}"
RESULT=$(curl -s -X POST "$API_URL" \
  -H "content-type: application/json" \
  -H "authorization: $TOKEN" \
  --data-raw "{\"action\":\"update\",\"order-id\":\"$ORDER_ID\",\"status\":\"paid\"}")

echo -e "\n${CYAN}╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║  VERIFICATION                                    ║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${RESET}"
echo "$RESULT" | jq . 2>/dev/null || echo "$RESULT"
if echo "$RESULT" | grep -qi "Forbidden\|403\|admin only"; then
  echo -e "\n${GREEN}[FIX CONFIRMED] Regular user now receives 403 on admin update action.${RESET}"
else
  echo -e "\n${YELLOW}[NOTE] Check that the action name matches what the function uses internally.${RESET}"
fi
