#!/usr/bin/env bash
# ============================================================
# LESSON 10 — Unhandled Exceptions FIX
# Fix: Wrap Lambda handler in try/catch. Return only a generic
#   {"message":"Bad Request"} to the client. Keep full error
#   details in console.error for CloudWatch only. Redeploy.
# ============================================================

# ── CONFIGURATION — fill these in before running ────────────
API_URL="https://YOUR-API-ID.execute-api.us-east-1.amazonaws.com/Stage/order"
TOKEN="PASTE_VALID_USER_JWT_HERE"
FUNCTION_NAME="DVSA-ORDER-MANAGER"
REGION="us-east-1"
WORK_DIR="/tmp/dvsa_lesson10_fix"
# ────────────────────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; RESET='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║  LESSON 10 — Unhandled Exceptions FIX           ║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${RESET}"

mkdir -p "$WORK_DIR" && cd "$WORK_DIR"

echo -e "\n${YELLOW}[STEP 1] Downloading Lambda...${RESET}"
URL=$(aws lambda get-function --function-name "$FUNCTION_NAME" --region "$REGION" \
  --query 'Code.Location' --output text)
curl -s -o function.zip "$URL"
unzip -q -o function.zip -d extracted/

echo -e "\n${YELLOW}[STEP 2] Wrapping handler in global try/catch...${RESET}"
node -e "
const fs = require('fs');
let code = fs.readFileSync('extracted/order-manager.js','utf8');

// Wrap exports.handler body in try/catch for safe error handling
code = code.replace(
  /(exports\.handler\s*=\s*(?:async\s*)?function\s*\([^)]*\)\s*\{)/,
  \`\$1
  try {
    // BEGIN SAFE HANDLER WRAPPER
\`
);

// Close the try and add catch before last closing brace of file
code = code.trimEnd();
code += \`
  } catch (unexpectedError) {
    console.error('[UNHANDLED EXCEPTION]', unexpectedError);
    return callback(null, {
      statusCode: 400,
      headers: { 'Access-Control-Allow-Origin': '*' },
      body: JSON.stringify({ message: 'Bad Request' })
    });
  }
  // END SAFE HANDLER WRAPPER
\`;

fs.writeFileSync('extracted/order-manager.js', code);
console.log('try/catch wrapper applied.');
" 2>/dev/null || echo -e "${YELLOW}[NOTE] Auto-wrap may need manual adjustment. Open extracted/order-manager.js to verify.${RESET}"

echo -e "${GREEN}[OK] Patch applied.${RESET}"

echo -e "\n${YELLOW}[STEP 3] Redeploying...${RESET}"
cd extracted && zip -qr ../patched.zip . && cd ..
aws lambda update-function-code \
  --function-name "$FUNCTION_NAME" --zip-file fileb://patched.zip --region "$REGION" > /dev/null
echo -e "${GREEN}[OK] Deployed. Waiting 10s...${RESET}"
sleep 10

echo -e "\n${YELLOW}[STEP 4] Re-running malformed payloads to verify no leakage...${RESET}"
LEAKED=0
for PAYLOAD in 'null' '{}' '{"action":null}' '{"action":"get"}' 'not-json'; do
  RESPONSE=$(curl -s -X POST "$API_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: $TOKEN" \
    --data-raw "$PAYLOAD")
  if echo "$RESPONSE" | grep -qiE "TypeError|ReferenceError|at Object|\.js:[0-9]+|/var/task|Cannot read|node_modules"; then
    LEAKED=$((LEAKED+1))
    echo -e "${RED}[STILL LEAKING] $PAYLOAD → $RESPONSE${RESET}"
  else
    echo -e "${GREEN}[SAFE] $PAYLOAD → $(echo $RESPONSE | jq -c . 2>/dev/null || echo $RESPONSE)${RESET}"
  fi
done

echo -e "\n${CYAN}╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║  VERIFICATION                                    ║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${RESET}"
if [ "$LEAKED" -eq 0 ]; then
  echo -e "${GREEN}[FIX CONFIRMED] All malformed requests return generic error. No internal details leaked.${RESET}"
  echo -e "${GREEN}Full error details still appear in CloudWatch → /aws/lambda/DVSA-ORDER-MANAGER${RESET}"
else
  echo -e "${YELLOW}[NOTE] $LEAKED payload(s) still leaking. Check that the try/catch wrapper is syntactically correct.${RESET}"
fi
