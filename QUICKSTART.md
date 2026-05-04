# Quick Start Guide

Get started with your first AWS security lesson in 5 minutes.

---

## 30-Second Summary

This repository contains **10 security lessons** with **20 executable scripts**:
- **Exploit scripts**: Demonstrate real AWS vulnerabilities
- **Fix scripts**: Show how to patch and remediate each vulnerability

Each lesson takes 10-15 minutes to complete.

---

## Your First Lesson (Lesson 1: RCE via Deserialization)

### 1. Navigate to Lesson 1
```bash
cd lesson-01-event-injection-rce
```

### 2. Edit the exploit script
```bash
nano exploit_lesson1.sh
```

Find and update the CONFIGURATION section (line 12):
```bash
# BEFORE:
API_URL="https://YOUR-API-ID.execute-api.us-east-1.amazonaws.com/Stage/order"

# AFTER (replace with your actual URL):
API_URL="https://a1b2c3d4e5.execute-api.us-east-1.amazonaws.com/Stage/order"
```

Save with `Ctrl+X`, then `Y`, then `Enter`

### 3. Run the exploit
```bash
bash exploit_lesson1.sh
```

### 4. Check the proof
Look at the output - you should see evidence of the vulnerability in:
- API response
- CloudWatch log location reference

### 5. Read the fix explanation
```bash
cat fix_lesson1.sh
```

Look for the comment section at the top explaining the vulnerability and fix.

### 6. Apply the fix (if you have admin access)
```bash
nano fix_lesson1.sh
# Fill in CONFIGURATION section with your values
bash fix_lesson1.sh
```

---

## Configuration Checklist

Before running any script, check off these items:

```
☐ AWS CLI installed and configured
☐ API_URL filled in (get from API Gateway console)
☐ TOKEN filled in (get from Cognito or login)
☐ REGION set correctly (default: us-east-1)
☐ FUNCTION_NAME correct (for fix scripts)
☐ ACCOUNT_ID set (for IAM-related lessons)
```

---

## Lessons Overview

| # | Lesson | Type | Time | Difficulty |
|---|--------|------|------|------------|
| 1 | Event Injection RCE | Code | 10m | Beginner |
| 2 | Broken Authentication | Security | 15m | Beginner |
| 3 | Sensitive Data | Authorization | 10m | Beginner |
| 4 | S3 Configuration | Infrastructure | 12m | Intermediate |
| 5 | Access Control | Code | 10m | Intermediate |
| 6 | Denial of Service | Operational | 15m | Intermediate |
| 7 | Over-Privileged IAM | Infrastructure | 15m | Advanced |
| 8 | Race Condition | Logic | 15m | Advanced |
| 9 | Vulnerable Dependencies | Supply Chain | 12m | Advanced |
| 10 | Exception Leakage | Code | 10m | Advanced |

---

## Common Configurations

### For Testing in Your AWS Account
```bash
# Get your account ID
aws sts get-caller-identity --query Account --output text

# Get Lambda function names
aws lambda list-functions --query 'Functions[].FunctionName' --output text

# Get API Gateway ID
aws apigateway get-rest-apis --query 'items[0].id' --output text
```

### For Getting Tokens
```bash
# Using AWS CLI (if user pool ID is known)
aws cognito-idp admin-initiate-auth \
  --user-pool-id us-east-1_XXXXXXXXX \
  --client-id [CLIENT_ID] \
  --auth-flow ADMIN_NO_SRP_AUTH \
  --auth-parameters USERNAME=[user],PASSWORD=[pass]
```

---

## Typical Workflow

**For Each Lesson:**

```
1. cd lesson-XX-name/
2. cat exploit_lessonXX.sh    # Read explanation
3. nano exploit_lessonXX.sh   # Fill CONFIGURATION
4. bash exploit_lessonXX.sh   # Run exploit
5. Review output for proof
6. nano fix_lessonXX.sh       # Fill CONFIGURATION
7. bash fix_lessonXX.sh       # Apply fix (admin only)
8. bash exploit_lessonXX.sh   # Verify fix works
9. Check CloudWatch logs
10. Document findings
```

---

## Output Examples

### Successful Exploit Run
```
╔══════════════════════════════════════════════════╗
║  LESSON 1 — Event Injection Exploit              ║
╚══════════════════════════════════════════════════╝

[STEP 1] Sending malicious $$ND_FUNC$$ payload to API...
[ATTACK] Injecting JavaScript that writes and reads /tmp/pwned.txt

[STEP 2] Raw API response:
{
  "message": "Internal server error"
}

╔══════════════════════════════════════════════════╗
║  PROOF — Where to find evidence                  ║
╚══════════════════════════════════════════════════╝
[PROOF LOCATION] Go to AWS Console → CloudWatch → Log groups
  Log group : /aws/lambda/DVSA-ORDER-MANAGER
  Search for: FILE READ SUCCESS
  
[VULN CONFIRMED] Arbitrary JavaScript executed inside Lambda.
```

### Successful Fix Run
```
[STEP 4] Re-running exploit to verify it is now blocked...

╔══════════════════════════════════════════════════╗
║  VERIFICATION                                    ║
╚══════════════════════════════════════════════════╝
API response after fix:
{ "status": "error" }

[FIX CONFIRMED] node-serialize removed. $$ND_FUNC$$ payloads are now inert.
```

---

## Troubleshooting Quick Links

| Error | Quick Fix |
|-------|-----------|
| `curl: command not found` | `apt-get install curl` |
| `jq: command not found` | `apt-get install jq` |
| `AccessDenied` | Run `aws sts get-caller-identity` to check creds |
| `404 Not Found` | Check API_URL is correct |
| `Unauthorized` | Get fresh JWT token from Cognito |
| `No such file` | Make sure you're in the lesson folder |

---

## Learning Resources

**Inside This Repository:**
- `README.md` - Full project overview
- `SETUP.md` - Detailed installation
- `CONFIGURATION.md` - Deep dive into configuration
- Each lesson folder contains inline comments

**External Resources:**
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [AWS Security Best Practices](https://docs.aws.amazon.com/security/)
- [AWS Lambda Security](https://docs.aws.amazon.com/lambda/latest/dg/security.html)

---

## Need Help?

1. **Setup issues?** → See SETUP.md
2. **Configuration?** → See CONFIGURATION.md
3. **Script details?** → Read comments in the script
4. **AWS issues?** → Check CloudWatch logs in AWS Console
5. **General questions?** → Check README.md

---

## Next Steps

```bash
# You are here:
# ✓ Installation done
# ✓ Configuration ready
# → Now start with Lesson 1

cd lesson-01-event-injection-rce
nano exploit_lesson1.sh  # Edit configuration
bash exploit_lesson1.sh  # Run it!
```

**Estimated time to complete all 10 lessons: 2-3 hours**

Good luck! 🚀
