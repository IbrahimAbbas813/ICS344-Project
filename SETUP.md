# Setup & Installation Guide

## Prerequisites

### System Requirements
- **OS**: Linux, macOS, or Windows (WSL/Git Bash)
- **AWS Account**: Active AWS account with DVSA deployed
- **CLI Tools**: bash, curl, jq, python3, zip, unzip
- **AWS CLI**: Configured with credentials and proper permissions

### Required Permissions
Your AWS IAM user/role needs permissions for:
- Lambda (get-function, update-function-code)
- API Gateway (describe, update, throttling)
- S3 (get-bucket-acl, put-bucket-policy, put-public-access-block)
- IAM (list-attached-role-policies, simulate-principal-policy, put-role-policy, detach-role-policy)
- DynamoDB (scan, get-item, query)
- CloudWatch Logs (describe-log-groups, filter-log-events)

---

## Step 1: Install Dependencies

### Linux (Ubuntu/Debian)
```bash
sudo apt-get update
sudo apt-get install -y \
  curl \
  jq \
  python3 \
  unzip \
  zip \
  git
```

### macOS
```bash
brew install \
  curl \
  jq \
  python3 \
  unzip \
  zip \
  git
```

### Windows (WSL2/Git Bash)
Follow Linux steps above within WSL2, or use Git Bash with equivalent tools.

---

## Step 2: Configure AWS CLI

### Check if AWS CLI is installed
```bash
aws --version
```

### If not installed:
```bash
# Using pip
pip3 install awscli

# Or on macOS with Homebrew
brew install awscli
```

### Configure credentials
```bash
aws configure

# You will be prompted for:
# AWS Access Key ID: [your-access-key]
# AWS Secret Access Key: [your-secret-key]
# Default region: us-east-1
# Default output format: json
```

### Verify configuration
```bash
aws sts get-caller-identity
```

---

## Step 3: Obtain DVSA Credentials

### Get API Endpoint
1. Go to AWS Console → API Gateway
2. Find your DVSA API
3. Copy the Invoke URL (e.g., `https://XXXXXXXXXX.execute-api.us-east-1.amazonaws.com/Stage/order`)

### Get User JWT Tokens
1. Go to AWS Console → Cognito → User Pools
2. Find DVSA user pool
3. Create test users or log in with existing credentials
4. Obtain JWT tokens (via CLI or web interface)
5. Format: `Authorization: Bearer [JWT_TOKEN]`

---

## Step 4: Clone or Download Repository

```bash
# Clone if using git
git clone https://github.com/your-repo/ICS344-Project.git
cd ICS344-Project

# Or download and extract
unzip ICS344-Project.zip
cd ICS344-Project
```

---

## Step 5: Verify Script Permissions

```bash
# Check all scripts are executable
ls -la lesson-*/
find . -name "*.sh" -type f -exec ls -l {} \;

# Make all executable (if needed)
chmod +x lesson-*/*.sh
```

---

## Step 6: Configure Environment Variables (Optional)

Create a `.env` file in project root for shared configuration:

```bash
# .env
export AWS_REGION="us-east-1"
export DVSA_API_URL="https://XXXXXXXXXX.execute-api.us-east-1.amazonaws.com/Stage/order"
export DVSA_USER_TOKEN="[your-user-jwt]"
export DVSA_ADMIN_TOKEN="[your-admin-jwt]"
export AWS_ACCOUNT_ID="123456789012"
```

Load it before running scripts:
```bash
source .env
```

---

## Step 7: Test Installation

Run a quick test to verify everything works:

```bash
# Test 1: Verify AWS CLI access
aws lambda list-functions --region us-east-1

# Test 2: Check curl and jq
curl -s "https://httpbin.org/json" | jq .

# Test 3: Verify script is executable
cd lesson-01-event-injection-rce
bash exploit_lesson1.sh --help 2>/dev/null || echo "Script ready"
```

---

## Troubleshooting

### "AWS CLI not found"
```bash
# Check if installed
which aws

# If not, install:
pip3 install awscli --upgrade
```

### "jq not found"
```bash
# Linux
sudo apt-get install jq

# macOS
brew install jq
```

### "AccessDenied" when running scripts
```bash
# Verify credentials are set
aws sts get-caller-identity

# Check IAM permissions
aws iam get-user
```

### "Unable to locate credentials"
```bash
# Reconfigure AWS CLI
aws configure

# Or set environment variables
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export AWS_DEFAULT_REGION="us-east-1"
```

### "API endpoint 404"
- Verify API_URL is correct
- Check DVSA Lambda functions are deployed
- Ensure API Gateway stage is published

### "Invalid token" errors
- Get fresh JWT tokens from Cognito
- Verify token hasn't expired
- Check user has correct permissions

---

## Next Steps

1. Read **QUICKSTART.md** for first exploit
2. Review **CONFIGURATION.md** for detailed setup
3. Start with Lesson 1: `cd lesson-01-event-injection-rce`
4. Edit exploit script with your API endpoint and token
5. Run the exploit: `bash exploit_lesson1.sh`

---

## System Check Script

Run this to verify all prerequisites:

```bash
#!/bin/bash
echo "Checking ICS344-Project prerequisites..."
echo ""

# Check bash version
echo -n "Bash: "
bash --version | head -1

# Check required tools
for tool in curl jq python3 zip unzip git aws; do
  echo -n "$tool: "
  command -v $tool &>/dev/null && echo "✓ installed" || echo "✗ NOT FOUND"
done

echo ""
echo "AWS Configuration:"
aws sts get-caller-identity 2>/dev/null || echo "✗ AWS CLI not configured"

echo ""
echo "Script permissions:"
find . -name "*.sh" -type f -exec test -x {} \; -print | wc -l
echo "executable scripts found"
```

---

## Support

- For AWS issues: See [AWS Troubleshooting Docs](https://docs.aws.amazon.com/troubleshooting/)
- For script errors: Check CloudWatch logs in AWS Console
- For setup help: Review configuration section in each lesson folder
