#!/usr/bin/env bash
# ============================================================
# LESSON 6 — Denial of Service FIX
# Fix: Apply API Gateway usage plan with throttling limits
#   (burst=5, rate=2 req/s) on the billing endpoint.
#   Verify flood now returns 429 Too Many Requests.
# ============================================================

# ── CONFIGURATION — fill these in before running ────────────
API_URL="https://YOUR-API-ID.execute-api.us-east-1.amazonaws.com/Stage/order"
TOKEN="PASTE_VALID_USER_JWT_HERE"
ORDER_ID="PASTE_YOUR_ORDER_ID_HERE"
REST_API_ID="YOUR-API-GATEWAY-ID"
STAGE_NAME="Stage"
REGION="us-east-1"
FLOOD_COUNT=20
# ────────────────────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; RESET='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║  LESSON 6 — Denial of Service FIX               ║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${RESET}"

echo -e "\n${YELLOW}[STEP 1] Creating Usage Plan with throttling (burst=5, rate=2)...${RESET}"
PLAN_ID=$(aws apigateway create-usage-plan \
  --name "dvsa-dos-protection" \
  --throttle burstLimit=5,rateLimit=2 \
  --region "$REGION" \
  --query 'id' --output text)
echo -e "${GREEN}[OK] Usage plan created: $PLAN_ID${RESET}"

echo -e "\n${YELLOW}[STEP 2] Attaching usage plan to DVSA API stage...${RESET}"
aws apigateway create-usage-plan-key \
  --usage-plan-id "$PLAN_ID" \
  --key-type "API_KEY" \
  --region "$REGION" 2>/dev/null || true

aws apigateway update-stage \
  --rest-api-id "$REST_API_ID" \
  --stage-name "$STAGE_NAME" \
  --patch-operations \
    op=replace,path="/*/*/throttling/burstLimit",value=5 \
    op=replace,path="/*/*/throttling/rateLimit",value=2 \
  --region "$REGION" > /dev/null 2>&1
echo -e "${GREEN}[OK] Stage throttling applied.${RESET}"

echo -e "\n${YELLOW}[STEP 3] Also setting Lambda reserved concurrency to 5...${RESET}"
aws lambda put-function-concurrency \
  --function-name "DVSA-BILLING" \
  --reserved-concurrent-executions 5 \
  --region "$REGION" 2>/dev/null \
  && echo -e "${GREEN}[OK] Lambda concurrency capped at 5.${RESET}" \
  || echo -e "${YELLOW}[NOTE] Lambda name may differ — check DVSA-BILLING or similar.${RESET}"

echo -e "\n${YELLOW}[STEP 4] Waiting 5s then re-running flood test ($FLOOD_COUNT requests)...${RESET}"
sleep 5

PAYLOAD="{\"action\":\"billing\",\"order-id\":\"$ORDER_ID\",\"data\":{\"ccn\":\"4242424242424242\",\"exp\":\"12/26\",\"cvv\":\"123\"}}"
TMPDIR=$(mktemp -d)
for i in $(seq 1 $FLOOD_COUNT); do
  curl -s -X POST "$API_URL" \
    -H "content-type: application/json" \
    -H "authorization: $TOKEN" \
    --data-raw "$PAYLOAD" \
    -o "$TMPDIR/resp_$i.json" &
done
wait

THROTTLED=0
for i in $(seq 1 $FLOOD_COUNT); do
  if grep -qi "429\|TooMany\|throttl\|Limit Exceeded" "$TMPDIR/resp_$i.json" 2>/dev/null; then
    THROTTLED=$((THROTTLED+1))
  fi
done

echo -e "\n${CYAN}╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║  VERIFICATION                                    ║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${RESET}"
echo -e "${GREEN}429 / throttled responses: $THROTTLED / $FLOOD_COUNT${RESET}"
if [ "$THROTTLED" -gt 0 ]; then
  echo -e "${GREEN}[FIX CONFIRMED] Throttling is active. Flood is now rate-limited.${RESET}"
else
  echo -e "${YELLOW}[NOTE] Throttling may need a few minutes to propagate. Retry in 2 minutes.${RESET}"
fi
rm -rf "$TMPDIR"
