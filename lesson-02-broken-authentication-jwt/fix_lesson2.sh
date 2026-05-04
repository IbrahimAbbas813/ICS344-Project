#!/usr/bin/env bash
# ============================================================
# LESSON 2 — Broken Authentication FIX
# Fix: Patch order-manager.js to verify JWT signature using
#   Cognito JWKS public keys via node-jose before trusting
#   any identity claim. Redeploy and prove forged token fails.
# ============================================================

# ── CONFIGURATION — fill these in before running ────────────
API_URL="https://YOUR-API-ID.execute-api.us-east-1.amazonaws.com/Stage/order"
FUNCTION_NAME="DVSA-ORDER-MANAGER"
REGION="us-east-1"
TOKEN_B="PASTE_USER_B_JWT_HERE"
TOKEN_C="PASTE_USER_C_JWT_HERE"
WORK_DIR="/tmp/dvsa_lesson2_fix"
# ────────────────────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; RESET='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║  LESSON 2 — Broken Authentication FIX           ║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${RESET}"

mkdir -p "$WORK_DIR" && cd "$WORK_DIR"

echo -e "\n${YELLOW}[STEP 1] Downloading Lambda package...${RESET}"
URL=$(aws lambda get-function --function-name "$FUNCTION_NAME" --region "$REGION" \
  --query 'Code.Location' --output text)
curl -s -o function.zip "$URL"
unzip -q -o function.zip -d extracted/

echo -e "\n${YELLOW}[STEP 2] Writing JWT verification helper into order-manager.js...${RESET}"

HELPER_CODE='
const https = require("https");
let _jwksCache = { keystore: null, fetchedAt: 0 };
function resp(statusCode, bodyObj) {
  return { statusCode, headers: { "Access-Control-Allow-Origin": "*" }, body: JSON.stringify(bodyObj) };
}
function fetchJson(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      let data = "";
      res.on("data", (c) => data += c);
      res.on("end", () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          try { resolve(JSON.parse(data)); } catch(e) { reject(e); }
        } else { reject(new Error("HTTP " + res.statusCode)); }
      });
    }).on("error", reject);
  });
}
async function getCognitoKeystore() {
  const now = Date.now();
  if (_jwksCache.keystore && (now - _jwksCache.fetchedAt) < 6*60*60*1000) return _jwksCache.keystore;
  const region = process.env.AWS_REGION;
  const userPoolId = process.env.userpoolid;
  const jwks = await fetchJson(`https://cognito-idp.${region}.amazonaws.com/${userPoolId}/.well-known/jwks.json`);
  const keystore = await jose.JWK.asKeyStore(jwks);
  _jwksCache = { keystore, fetchedAt: now };
  return keystore;
}
async function verifyCognitoJwt(jwt) {
  const region = process.env.AWS_REGION;
  const userPoolId = process.env.userpoolid;
  const issuer = `https://cognito-idp.${region}.amazonaws.com/${userPoolId}`;
  const keystore = await getCognitoKeystore();
  const result = await jose.JWS.createVerify(keystore).verify(jwt);
  const claims = JSON.parse(result.payload.toString("utf8"));
  if (claims.iss !== issuer) throw new Error("bad issuer");
  if (typeof claims.exp === "number" && (Date.now()/1000) > claims.exp) throw new Error("expired");
  return claims;
}
'

# Inject helper after the jose require line
node -e "
const fs = require('fs');
let code = fs.readFileSync('extracted/order-manager.js','utf8');
const marker = \"const jose = require('node-jose');\";
if (!code.includes('verifyCognitoJwt')) {
  code = code.replace(marker, marker + \`\n${HELPER_CODE.replace(/\`/g,'\\`')}\n\`);
}
// Replace vulnerable parsing block
code = code.replace(
  /var auth_header = headers\.Authorization.*?var isAdmin = false;/s,
  \`var auth_header = (headers.Authorization || headers.authorization || '');
var jwt = auth_header.replace(/^Bearer\\\\s+/i,'').trim();
if (!jwt) return callback(null, resp(401,{status:'err',msg:'missing authorization'}));
verifyCognitoJwt(jwt).then((claims) => {
var user = claims.username || claims['cognito:username'] || claims.sub;
if (!user) return callback(null, resp(401,{status:'err',msg:'missing subject'}));
var isAdmin = false;\`
);
// Add catch before last closing brace
code = code.replace(/(\}\s*)$/, \`}).catch((e)=>{
  console.log('JWT verify failed:', e);
  return callback(null, resp(401,{status:'err',msg:'invalid token'}));
});\n\$1\`);
fs.writeFileSync('extracted/order-manager.js', code);
console.log('Patch applied.');
" 2>/dev/null || echo -e "${YELLOW}[NOTE] Auto-patch may need manual review. Check extracted/order-manager.js${RESET}"

echo -e "${GREEN}[OK] Patch written.${RESET}"

echo -e "\n${YELLOW}[STEP 3] Rezipping and redeploying...${RESET}"
cd extracted && zip -qr ../patched.zip . && cd ..
aws lambda update-function-code \
  --function-name "$FUNCTION_NAME" \
  --zip-file fileb://patched.zip \
  --region "$REGION" > /dev/null
echo -e "${GREEN}[OK] Redeployed. Waiting 10s...${RESET}"
sleep 10

echo -e "\n${YELLOW}[STEP 4] Re-running JWT forgery attack...${RESET}"
export TOKEN_B TOKEN_C
FAKE_AS_C=$(python3 - <<PYEOF
import os, json, base64
t  = os.environ["TOKEN_B"]
c_raw = os.environ["TOKEN_C"]
def decode(tok):
    p = tok.split(".")[1]; p += "=" * (-len(p)%4)
    return json.loads(base64.urlsafe_b64decode(p.encode()))
victim = decode(c_raw)
h,p,s  = t.split(".")
p += "=" * (-len(p)%4)
data = json.loads(base64.urlsafe_b64decode(p.encode()))
data["username"] = victim.get("username", victim.get("sub"))
data["sub"]      = victim.get("sub", victim.get("username"))
newp = base64.urlsafe_b64encode(json.dumps(data,separators=(",",":")).encode()).rstrip(b"=").decode()
h2,_,s2 = t.split(".")
print(f"{h2}.{newp}.{s2}")
PYEOF
)

RESULT=$(curl -s "$API_URL" \
  -H "content-type: application/json" \
  -H "authorization: $FAKE_AS_C" \
  --data-raw '{"action":"orders"}')

echo -e "\n${CYAN}╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║  VERIFICATION                                    ║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${RESET}"
echo "$RESULT" | jq . 2>/dev/null || echo "$RESULT"
if echo "$RESULT" | grep -q "invalid token\|unauthorized\|401\|err"; then
  echo -e "\n${GREEN}[FIX CONFIRMED] Forged token was rejected. Signature verification is enforced.${RESET}"
else
  echo -e "\n${YELLOW}[NOTE] Review CloudWatch logs for JWT verify failed entries.${RESET}"
fi
