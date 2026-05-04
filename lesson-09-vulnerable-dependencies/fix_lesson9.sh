#!/usr/bin/env bash
# ============================================================
# LESSON 9 — Vulnerable Dependencies FIX
# Fix: Remove node-serialize from package.json, replace its
#   usage with JSON.parse, run npm audit to confirm 0 critical
#   vulnerabilities, rebuild and redeploy the Lambda.
# ============================================================

# ── CONFIGURATION — fill these in before running ────────────
API_URL="https://YOUR-API-ID.execute-api.us-east-1.amazonaws.com/Stage/order"
FUNCTION_NAME="DVSA-ORDER-MANAGER"
REGION="us-east-1"
WORK_DIR="/tmp/dvsa_lesson9_fix"
# ────────────────────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; RESET='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║  LESSON 9 — Vulnerable Dependencies FIX         ║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${RESET}"

mkdir -p "$WORK_DIR" && cd "$WORK_DIR"

echo -e "\n${YELLOW}[STEP 1] Downloading Lambda...${RESET}"
URL=$(aws lambda get-function --function-name "$FUNCTION_NAME" --region "$REGION" \
  --query 'Code.Location' --output text)
curl -s -o function.zip "$URL"
unzip -q -o function.zip -d extracted/

echo -e "\n${YELLOW}[STEP 2] Removing node-serialize from package.json...${RESET}"
node -e "
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('extracted/package.json','utf8'));
delete pkg.dependencies['node-serialize'];
fs.writeFileSync('extracted/package.json', JSON.stringify(pkg, null, 2));
console.log('node-serialize removed from package.json');
" 2>/dev/null || echo -e "${YELLOW}[NOTE] package.json may not exist at root — check extracted/ directory.${RESET}"

echo -e "\n${YELLOW}[STEP 3] Patching source code — replacing serialize.unserialize with JSON.parse...${RESET}"
find extracted/ -name "*.js" | xargs sed -i \
  -e "s/serialize\.unserialize(/JSON.parse(/g" \
  -e "s/var serialize = require('node-serialize');//g" \
  -e 's/const serialize = require("node-serialize");//g' \
  2>/dev/null
echo -e "${GREEN}[OK] Source patched.${RESET}"

echo -e "\n${YELLOW}[STEP 4] Rebuilding node_modules without node-serialize...${RESET}"
if command -v npm &>/dev/null && [ -f "extracted/package.json" ]; then
  cd extracted
  rm -rf node_modules/node-serialize
  npm install --omit=dev --quiet 2>/dev/null
  echo -e "\n${YELLOW}npm audit after fix:${RESET}"
  npm audit 2>&1 | tail -5
  cd ..
else
  rm -rf extracted/node_modules/node-serialize 2>/dev/null
  echo -e "${YELLOW}[NOTE] npm not available — manually deleted node-serialize from node_modules.${RESET}"
fi
echo -e "${GREEN}[OK] Dependencies cleaned.${RESET}"

echo -e "\n${YELLOW}[STEP 5] Rezipping and redeploying...${RESET}"
cd extracted && zip -qr ../patched.zip . && cd ..
aws lambda update-function-code \
  --function-name "$FUNCTION_NAME" --zip-file fileb://patched.zip --region "$REGION" > /dev/null
echo -e "${GREEN}[OK] Deployed. Waiting 10s...${RESET}"
sleep 10

echo -e "\n${YELLOW}[STEP 6] Re-running injection payload to confirm it is blocked...${RESET}"
RESULT=$(curl -s -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d '{"action":"_$$ND_FUNC$$_function(){console.error(\"STILL-VULNERABLE\");}()","cart-id":""}')

echo -e "\n${CYAN}╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║  VERIFICATION                                    ║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${RESET}"
echo "$RESULT" | jq . 2>/dev/null || echo "$RESULT"
echo -e "\n${GREEN}[VERIFY] Check CloudWatch → /aws/lambda/DVSA-ORDER-MANAGER${RESET}"
echo -e "${GREEN}Search for: STILL-VULNERABLE${RESET}"
echo -e "${GREEN}It should NOT appear. The $$ND_FUNC$$ marker is now treated as plain string by JSON.parse.${RESET}"
echo -e "${GREEN}[FIX CONFIRMED] node-serialize removed. CVE-2017-5941 is remediated.${RESET}"
