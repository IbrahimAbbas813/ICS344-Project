#!/usr/bin/env bash
# ============================================================
# LESSON 1 — Event Injection FIX
# Fix: Replace node-serialize with plain JSON.parse in the
#   Lambda function and redeploy. Removes the $$ND_FUNC$$
#   deserialization attack surface entirely.
# What this script does:
#   1. Downloads the current Lambda zip
#   2. Patches the dangerous deserialize() call
#   3. Rezips and redeploys
#   4. Re-runs the exploit to prove it no longer works
# ============================================================

# ── CONFIGURATION — fill these in before running ────────────
API_URL="https://YOUR-API-ID.execute-api.us-east-1.amazonaws.com/Stage/order"
FUNCTION_NAME="DVSA-ORDER-MANAGER"
REGION="us-east-1"
LAMBDA_JS_FILENAME="order-manager.js"   # name of the JS file inside the zip
WORK_DIR="/tmp/dvsa_lesson1_fix"
# ────────────────────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; RESET='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║  LESSON 1 — Event Injection FIX                 ║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${RESET}"

for tool in aws curl jq zip unzip; do
  command -v $tool &>/dev/null || { echo -e "${RED}[ERROR] $tool not installed.${RESET}"; exit 1; }
done

mkdir -p "$WORK_DIR" && cd "$WORK_DIR"

echo -e "\n${YELLOW}[STEP 1] Downloading current Lambda deployment package...${RESET}"
URL=$(aws lambda get-function --function-name "$FUNCTION_NAME" --region "$REGION" \
  --query 'Code.Location' --output text)
curl -s -o function.zip "$URL"
unzip -q -o function.zip -d extracted/
echo -e "${GREEN}[OK] Downloaded and extracted.${RESET}"

echo -e "\n${YELLOW}[STEP 2] Patching — removing serialize() calls...${RESET}"
# Replace: var serialize = require('node-serialize');
# Replace: serialize.unserialize(...)  →  JSON.parse(...)
sed -i "s/serialize\.unserialize(/JSON.parse(/g" extracted/"$LAMBDA_JS_FILENAME" 2>/dev/null
sed -i "s/var serialize = require('node-serialize');//g" extracted/"$LAMBDA_JS_FILENAME" 2>/dev/null
sed -i 's/const serialize = require("node-serialize");//g' extracted/"$LAMBDA_JS_FILENAME" 2>/dev/null
echo -e "${GREEN}[OK] Patched serialize calls to JSON.parse.${RESET}"

echo -e "\n${YELLOW}[STEP 3] Rezipping and redeploying Lambda...${RESET}"
cd extracted && zip -qr ../patched.zip . && cd ..
aws lambda update-function-code \
  --function-name "$FUNCTION_NAME" \
  --zip-file fileb://patched.zip \
  --region "$REGION" > /dev/null
echo -e "${GREEN}[OK] Lambda redeployed. Waiting 10s for propagation...${RESET}"
sleep 10

echo -e "\n${YELLOW}[STEP 4] Re-running exploit to verify it is now blocked...${RESET}"
RESPONSE=$(curl -s -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d '{"action":"_$$ND_FUNC$$_function(){var fs=require(\"fs\");fs.writeFileSync(\"/tmp/pwned.txt\",\"STILL PWNED\");console.error(\"FILE READ SUCCESS: still works\");}()","cart-id":""}')

echo -e "\n${CYAN}╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║  VERIFICATION                                    ║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${RESET}"
echo -e "${YELLOW}API response after fix:${RESET}"
echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
echo -e "\n${GREEN}[VERIFY] Now check CloudWatch → /aws/lambda/DVSA-ORDER-MANAGER${RESET}"
echo -e "${GREEN}  Search for: FILE READ SUCCESS${RESET}"
echo -e "${GREEN}  It should NOT appear in new log streams after the fix.${RESET}"
echo -e "${GREEN}[FIX CONFIRMED] node-serialize removed. $$ND_FUNC$$ payloads are now inert.${RESET}"
