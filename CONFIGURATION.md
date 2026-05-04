# Configuration Guide

Complete guide to configuring all 20 scripts for your AWS environment.

---

## Overview

Each script requires specific configuration values set at the top in the **CONFIGURATION** section.

**Format:**
```bash
# ── CONFIGURATION — fill these in before running ────────────
VARIABLE="VALUE"
# ────────────────────────────────────────────────────────────
```

---

## Global Configuration (All Lessons)

### API_URL
**Required for:** Lessons 1-6, 10  
**Where to find:**
1. AWS Console → API Gateway
2. Select DVSA API
3. Click "Stages" in left menu
4. Select your stage (usually "Stage")
5. Copy the **Invoke URL**

**Format:**
```bash
API_URL="https://XXXXXXXXXX.execute-api.us-east-1.amazonaws.com/Stage/order"
                    ^^^^^^^^^^^^ This part changes
```

**How to get via CLI:**
```bash
aws apigateway get-rest-apis --query 'items[0].[id,name]' --output text
# Output: a1b2c3d4e5 DVSA

aws apigateway get-stage \
  --rest-api-id a1b2c3d4e5 \
  --stage-name Stage \
  --query 'invokeUrl' --output text
```

---

### TOKEN / TOKEN_B / TOKEN_C
**Required for:** Most exploit scripts  
**What it is:** JWT (JSON Web Token) from Cognito user pool

**How to get:**

#### Option 1: Via AWS Console
1. Go to Cognito → User Pools → Your Pool
2. Click "Users and groups"
3. Select a user
4. Copy the displayed token (if available)
5. Or use the test user credentials to log in

#### Option 2: Via AWS CLI
```bash
# Get these values from Cognito first:
USER_POOL_ID="us-east-1_XXXXXXXXX"  # From User Pool settings
CLIENT_ID="a1b2c3d4e5f6g7h8i9j0k1l2m"  # From App Client settings
USERNAME="testuser"
PASSWORD="TestPassword123!"

# Get token
aws cognito-idp admin-initiate-auth \
  --user-pool-id $USER_POOL_ID \
  --client-id $CLIENT_ID \
  --auth-flow ADMIN_NO_SRP_AUTH \
  --auth-parameters USERNAME=$USERNAME,PASSWORD=$PASSWORD \
  --query 'AuthenticationResult.IdToken' \
  --output text
```

#### Option 3: Via Python Script
```python
import boto3
import json

cognito = boto3.client('cognito-idp', region_name='us-east-1')

response = cognito.admin_initiate_auth(
    UserPoolId='us-east-1_XXXXXXXXX',
    ClientId='a1b2c3d4e5f6g7h8i9j0k1l2m',
    AuthFlow='ADMIN_NO_SRP_AUTH',
    AuthParameters={
        'USERNAME': 'testuser',
        'PASSWORD': 'TestPassword123!'
    }
)

id_token = response['AuthenticationResult']['IdToken']
print(f"TOKEN=\"{id_token}\"")
```

**For Lesson 2 (JWT Forgery):**
- `TOKEN_B` = Regular user token (attacker)
- `TOKEN_C` = Different user token (victim)
- Both must be valid tokens from different users

---

### REGION
**Default:** `us-east-1`  
**Required for:** All fix scripts and lessons with AWS CLI calls

**How to check your DVSA region:**
```bash
aws lambda list-functions --query 'Functions[0].FunctionArn' --output text
# Output: arn:aws:lambda:us-east-1:123456789012:function:DVSA-ORDER-MANAGER
#                            ^^^^^^^^^ This is your region
```

---

## Lesson-Specific Configuration

### Lesson 1 & 9: Event Injection & Vulnerable Dependencies

```bash
API_URL="https://XXXXXXXXXX.execute-api.us-east-1.amazonaws.com/Stage/order"
FUNCTION_NAME="DVSA-ORDER-MANAGER"
REGION="us-east-1"
```

**Where to find FUNCTION_NAME:**
```bash
aws lambda list-functions --region us-east-1 --query 'Functions[].FunctionName' --output text
```

---

### Lesson 2: Broken Authentication (JWT Forgery)

```bash
API_URL="https://XXXXXXXXXX.execute-api.us-east-1.amazonaws.com/Stage/order"
TOKEN_B="eyJhbGciOiJIUzI1NiIs..."  # Regular user token
TOKEN_C="eyJhbGciOiJIUzI1NiIs..."  # Different user token
FUNCTION_NAME="DVSA-ORDER-MANAGER"
REGION="us-east-1"
```

**Getting two different tokens:**
```bash
# Log in as User B
TOKEN_B=$(aws cognito-idp admin-initiate-auth \
  --user-pool-id us-east-1_XXXXXXXXX \
  --client-id a1b2c3d4e5f6 \
  --auth-flow ADMIN_NO_SRP_AUTH \
  --auth-parameters USERNAME=userb,PASSWORD=Password123 \
  --query 'AuthenticationResult.IdToken' --output text)

# Log in as User C
TOKEN_C=$(aws cognito-idp admin-initiate-auth \
  --user-pool-id us-east-1_XXXXXXXXX \
  --client-id a1b2c3d4e5f6 \
  --auth-flow ADMIN_NO_SRP_AUTH \
  --auth-parameters USERNAME=userc,PASSWORD=Password123 \
  --query 'AuthenticationResult.IdToken' --output text)

echo "TOKEN_B=\"$TOKEN_B\""
echo "TOKEN_C=\"$TOKEN_C\""
```

---

### Lesson 3: Sensitive Data Exposure

```bash
API_URL="https://XXXXXXXXXX.execute-api.us-east-1.amazonaws.com/Stage/order"
TOKEN="eyJhbGciOiJIUzI1NiIs..."  # Any valid user token
VICTIM_ORDER_ID="order-12345"
FUNCTION_NAME="DVSA-ADMIN-GET-RECEIPT"
REGION="us-east-1"
```

**Getting VICTIM_ORDER_ID:**
```bash
# First place an order as a user, then get the order ID
# Or check DynamoDB directly:
aws dynamodb scan \
  --table-name DVSA-ORDERS-DB \
  --limit 1 \
  --query 'Items[0].order_id.S' \
  --output text
```

---

### Lesson 4: Insecure S3 Configuration

```bash
BUCKET_NAME="dvsa-website-bucket-12345"
REGION="us-east-1"
ACCOUNT_ID="123456789012"  # For fix script
```

**Getting BUCKET_NAME:**
```bash
# List all S3 buckets
aws s3 ls

# Or find DVSA-specific bucket
aws s3 ls | grep -i dvsa
```

**Getting ACCOUNT_ID:**
```bash
aws sts get-caller-identity --query 'Account' --output text
```

---

### Lesson 5: Broken Access Control

```bash
API_URL="https://XXXXXXXXXX.execute-api.us-east-1.amazonaws.com/Stage/order"
TOKEN="eyJhbGciOiJIUzI1NiIs..."  # Regular user token (NOT admin)
ORDER_ID="order-12345"
FUNCTION_NAME="DVSA-ORDER-MANAGER"
REGION="us-east-1"
```

**Important:** Use a regular user token, NOT an admin token, to demonstrate the vulnerability.

---

### Lesson 6: Denial of Service

```bash
API_URL="https://XXXXXXXXXX.execute-api.us-east-1.amazonaws.com/Stage/order"
TOKEN="eyJhbGciOiJIUzI1NiIs..."
ORDER_ID="order-12345"
FLOOD_COUNT=50  # Number of concurrent requests
# For fix script:
REST_API_ID="a1b2c3d4e5"
STAGE_NAME="Stage"
```

**Getting REST_API_ID:**
```bash
aws apigateway get-rest-apis --query 'items[0].id' --output text
```

---

### Lesson 7: Over-Privileged Function

```bash
REGION="us-east-1"
ACCOUNT_ID="123456789012"
ROLE_NAME="serverlessrepo-OWASP-DVSA-SendReceiptFunctionRole-XXXXXXXXXX"
RECEIPTS_BUCKET="dvsa-receipts-bucket-12345"
ORDERS_TABLE_ARN="arn:aws:dynamodb:us-east-1:123456789012:table/DVSA-ORDERS-DB"
```

**Getting ROLE_NAME:**
```bash
aws iam list-roles --query 'Roles[?contains(RoleName, `SendReceipt`)].RoleName' --output text
```

**Getting ORDERS_TABLE_ARN:**
```bash
aws dynamodb list-tables --query 'TableNames' --output text | grep -i orders
# Then construct: arn:aws:dynamodb:REGION:ACCOUNT_ID:table/TABLE_NAME
```

---

### Lesson 8: Logic Vulnerability (Race Condition)

```bash
API_URL="https://XXXXXXXXXX.execute-api.us-east-1.amazonaws.com/Stage/order"
TOKEN="eyJhbGciOiJIUzI1NiIs..."
ORDER_ID="order-with-1-item-12345"
FUNCTION_NAME="DVSA-ORDER-MANAGER"
REGION="us-east-1"
```

**Important:** Use an order that has exactly 1 item for the exploit to work properly.

---

### Lesson 10: Unhandled Exceptions

```bash
API_URL="https://XXXXXXXXXX.execute-api.us-east-1.amazonaws.com/Stage/order"
TOKEN="eyJhbGciOiJIUzI1NiIs..."
FUNCTION_NAME="DVSA-ORDER-MANAGER"
REGION="us-east-1"
```

---

## Creating a Configuration File

### Option 1: .env File (Recommended for Development)

Create `.env` in project root:

```bash
# Global settings
export AWS_REGION="us-east-1"
export AWS_ACCOUNT_ID="123456789012"

# API Configuration
export DVSA_API_URL="https://a1b2c3d4e5.execute-api.us-east-1.amazonaws.com/Stage/order"

# User Tokens
export USER_TOKEN="eyJhbGciOiJIUzI1NiIs..."
export ADMIN_TOKEN="eyJhbGciOiJIUzI1NiIs..."
export USER_B_TOKEN="eyJhbGciOiJIUzI1NiIs..."
export USER_C_TOKEN="eyJhbGciOiJIUzI1NiIs..."

# Lambda Configuration
export DVSA_ORDER_MANAGER_FUNCTION="DVSA-ORDER-MANAGER"
export DVSA_BILLING_FUNCTION="DVSA-BILLING"

# Resource IDs
export DVSA_BUCKET="dvsa-website-bucket-12345"
export DVSA_RECEIPTS_BUCKET="dvsa-receipts-bucket-12345"
export DVSA_ORDERS_TABLE="DVSA-ORDERS-DB"
```

Load before running:
```bash
source .env
cd lesson-01-event-injection-rce
bash exploit_lesson1.sh
```

### Option 2: Individual Script Configuration

Edit each script directly:
```bash
nano lesson-01-event-injection-rce/exploit_lesson1.sh
# Find CONFIGURATION section and fill in values
```

---

## Validation Checklist

Before running any script, verify:

```bash
# ✓ Check API endpoint is reachable
curl -I $API_URL

# ✓ Check token is valid (decoding works)
echo $TOKEN | cut -d'.' -f2 | base64 -d 2>/dev/null | jq .

# ✓ Check AWS CLI access
aws sts get-caller-identity

# ✓ Check Lambda function exists
aws lambda get-function --function-name $FUNCTION_NAME --region $REGION

# ✓ Check S3 bucket exists
aws s3 ls s3://$BUCKET_NAME

# ✓ Check DynamoDB table
aws dynamodb describe-table --table-name $ORDERS_TABLE --region $REGION
```

---

## Troubleshooting Configuration Issues

| Problem | Solution |
|---------|----------|
| `404 Not Found` on API_URL | Verify URL is correct, check API Gateway is deployed |
| `Invalid token` | Get fresh token from Cognito, check expiration |
| `AccessDenied` | Check AWS IAM permissions, verify credentials with `aws sts get-caller-identity` |
| `Function not found` | Verify FUNCTION_NAME matches exactly, check region is correct |
| `Table not found` | Verify table name and region match DynamoDB console |
| `Bucket not found` | Verify bucket name exists and region is correct |

---

## Security Best Practices

⚠️ **Important:** Never commit actual tokens or credentials to version control.

### DO:
```bash
# Store in .env (add to .gitignore)
export TOKEN="your-token-here"

# Use in scripts:
API_URL=$DVSA_API_URL
```

### DON'T:
```bash
# Never hardcode in script
API_URL="https://actual-url.com"  # ✗ Wrong

# Never commit .env file
git add .env  # ✗ Wrong

# Never share credentials
TOKEN="eyJhbGciOi..." # ✗ Wrong
```

---

## Getting Help

If configuration fails:
1. Run validation checklist above
2. Check AWS Console for resource existence
3. Review error message in script output
4. Check CloudWatch logs for Lambda errors
5. See SETUP.md for tool installation issues
