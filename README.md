# ICS344-Project: DVSA Security Lessons

## Overview

This project contains 10 comprehensive security lessons covering real-world AWS vulnerabilities. Each lesson includes an **exploit script** and a **fix script** to demonstrate the vulnerability and teach the remediation.

**Total: 20 executable bash scripts organized by lesson**

---

## Project Structure

```
ICS344-Project/
├── lesson-01-event-injection-rce/
│   ├── exploit_lesson1.sh    # RCE via insecure deserialization
│   └── fix_lesson1.sh        # Replace node-serialize with JSON.parse
├── lesson-02-broken-authentication-jwt/
│   ├── exploit_lesson2.sh    # JWT forgery - no signature verification
│   └── fix_lesson2.sh        # Add Cognito JWKS signature verification
├── lesson-03-sensitive-data-exposure/
│   ├── exploit_lesson3.sh    # Bypass admin check on receipt URLs
│   └── fix_lesson3.sh        # Add admin authorization check
├── lesson-04-insecure-cloud-configuration/
│   ├── exploit_lesson4.sh    # Upload to publicly writable S3 bucket
│   └── fix_lesson4.sh        # Enable S3 Block Public Access
├── lesson-05-broken-access-control/
│   ├── exploit_lesson5.sh    # Non-admin updates order status
│   └── fix_lesson5.sh        # Add isAdmin guard before status updates
├── lesson-06-denial-of-service/
│   ├── exploit_lesson6.sh    # Concurrent billing flood attack
│   └── fix_lesson6.sh        # Apply API Gateway throttling
├── lesson-07-over-privileged-function/
│   ├── exploit_lesson7.sh    # Lambda with wildcard IAM permissions
│   └── fix_lesson7.sh        # Replace with least-privilege policies
├── lesson-08-logic-vulnerability/
│   ├── exploit_lesson8.sh    # Race condition: pay for 1, get 5
│   └── fix_lesson8.sh        # Add DynamoDB conditional locking
├── lesson-09-vulnerable-dependencies/
│   ├── exploit_lesson9.sh    # CVE-2017-5941 node-serialize RCE
│   └── fix_lesson9.sh        # Remove vulnerable dependency
└── lesson-10-unhandled-exceptions/
    ├── exploit_lesson10.sh   # Stack trace information leakage
    └── fix_lesson10.sh       # Wrap handler in try/catch

README.md
```

---

## Lessons Summary

### Lesson 1: Event Injection (RCE via Insecure Deserialization)
- **Vulnerability**: node-serialize library executes arbitrary JavaScript via `$$ND_FUNC$$` marker
- **Impact**: Remote Code Execution on Lambda backend
- **Fix**: Replace `serialize.unserialize()` with `JSON.parse()`
- **Files**: `exploit_lesson1.sh`, `fix_lesson1.sh`

### Lesson 2: Broken Authentication (JWT Forgery)
- **Vulnerability**: JWT payload decoded without cryptographic signature verification
- **Impact**: Attacker can forge tokens and impersonate any user
- **Fix**: Verify JWT signature using Cognito JWKS public keys via node-jose
- **Files**: `exploit_lesson2.sh`, `fix_lesson2.sh`

### Lesson 3: Sensitive Information Disclosure
- **Vulnerability**: Admin-only receipt URL endpoint lacks authorization check
- **Impact**: Non-admin users access any customer's receipts
- **Fix**: Add admin group verification before generating signed S3 URLs
- **Files**: `exploit_lesson3.sh`, `fix_lesson3.sh`

### Lesson 4: Insecure Cloud Configuration (S3 Public Write)
- **Vulnerability**: S3 bucket allows public/overly-permissive PutObject
- **Impact**: Unauthenticated file uploads to production bucket
- **Fix**: Enable S3 Block Public Access + deny-public-PutObject bucket policy
- **Files**: `exploit_lesson4.sh`, `fix_lesson4.sh`

### Lesson 5: Broken Access Control
- **Vulnerability**: Regular users can invoke admin-only order status updates
- **Impact**: Non-admin users mark orders as "paid" without billing
- **Fix**: Add `isAdmin` guard check before status update operations
- **Files**: `exploit_lesson5.sh`, `fix_lesson5.sh`

### Lesson 6: Denial of Service (Concurrent Request Flood)
- **Vulnerability**: No rate limiting on billing endpoint
- **Impact**: Lambda concurrency exhaustion returns TooManyRequests
- **Fix**: Apply API Gateway throttling (burst=5, rate=2 req/s) + Lambda concurrency cap
- **Files**: `exploit_lesson6.sh`, `fix_lesson6.sh`

### Lesson 7: Over-Privileged Function
- **Vulnerability**: Lambda execution role has wildcard S3 and DynamoDB permissions
- **Impact**: Attackers with function credentials can scan entire orders database
- **Fix**: Replace wildcard policies with least-privilege inline policies scoped to exact ARNs
- **Files**: `exploit_lesson7.sh`, `fix_lesson7.sh`

### Lesson 8: Logic Vulnerabilities (Race Condition)
- **Vulnerability**: Billing and order-update requests lack atomic locks
- **Impact**: Attacker sends billing (1 item) + update (5 items) in parallel → pays for 1, gets 5
- **Fix**: Add DynamoDB conditional write lock during billing
- **Files**: `exploit_lesson8.sh`, `fix_lesson8.sh`

### Lesson 9: Vulnerable Dependencies
- **Vulnerability**: CVE-2017-5941 in node-serialize package
- **Impact**: Same RCE as Lesson 1, but via dependency vulnerability
- **Fix**: Remove node-serialize, replace usage with JSON.parse, run npm audit
- **Files**: `exploit_lesson9.sh`, `fix_lesson9.sh`

### Lesson 10: Unhandled Exceptions (Information Leakage)
- **Vulnerability**: Malformed requests cause Lambda to return stack traces
- **Impact**: Internal paths, function names, validation details leak to client
- **Fix**: Wrap handler in global try/catch, return generic error to client only
- **Files**: `exploit_lesson10.sh`, `fix_lesson10.sh`

---

## Quick Start

### Prerequisites
- AWS CLI configured with credentials
- curl, jq, python3, zip, unzip installed
- Valid AWS account with DVSA application deployed
- User JWTs for testing (Lessons 2, 5, 10)

### Running a Lesson

1. **Navigate to the lesson folder**:
   ```bash
   cd lesson-01-event-injection-rce
   ```

2. **Edit the exploit script** - Fill in the CONFIGURATION section:
   ```bash
   nano exploit_lesson1.sh
   # Set API_URL to your DVSA endpoint
   ```

3. **Run the exploit**:
   ```bash
   bash exploit_lesson1.sh
   ```

4. **Review the proof** - Check CloudWatch logs or API response for evidence

5. **Apply the fix**:
   ```bash
   bash fix_lesson1.sh
   ```

6. **Verify the fix** - Re-run the exploit to confirm it no longer works

---

## Configuration Required

Each script requires specific configuration values at the top:

### Exploit Scripts Need:
- `API_URL` - DVSA API Gateway endpoint
- `TOKEN` or `TOKEN_B`/`TOKEN_C` - Valid JWT tokens from Cognito
- `REGION` - AWS region (default: us-east-1)
- Lesson-specific values (ORDER_ID, BUCKET_NAME, etc.)

### Fix Scripts Need:
- Same as exploit scripts PLUS:
- `FUNCTION_NAME` - Lambda function name (e.g., DVSA-ORDER-MANAGER)
- `ACCOUNT_ID` - AWS account ID for IAM policies
- Additional resource identifiers (table names, bucket names, role names)

---

## Learning Path

**Beginner (Start here):**
1. Lesson 1 - Event Injection RCE
2. Lesson 2 - Broken Authentication
3. Lesson 3 - Sensitive Data Exposure

**Intermediate:**
4. Lesson 4 - Insecure Cloud Configuration
5. Lesson 5 - Broken Access Control
6. Lesson 6 - Denial of Service

**Advanced:**
7. Lesson 7 - Over-Privileged Function
8. Lesson 8 - Logic Vulnerabilities
9. Lesson 9 - Vulnerable Dependencies
10. Lesson 10 - Unhandled Exceptions

---

## Key Concepts by Category

### Authentication & Authorization
- **Lesson 2**: JWT verification and signature validation
- **Lesson 3**: Authorization checks before sensitive operations
- **Lesson 5**: Role-based access control (RBAC)

### Infrastructure & Cloud Security
- **Lesson 4**: S3 bucket policies and public access blocks
- **Lesson 7**: IAM least-privilege principle

### Application Security
- **Lesson 1**: Insecure deserialization RCE
- **Lesson 8**: Race conditions and concurrency issues
- **Lesson 9**: Dependency vulnerability management
- **Lesson 10**: Error handling and information disclosure

### Operational Security
- **Lesson 6**: Rate limiting and DoS protection

---

## Common Issues & Troubleshooting

| Issue | Solution |
|-------|----------|
| `[ERROR] curl not installed` | Install curl: `apt-get install curl` (Linux) or `brew install curl` (Mac) |
| `[ERROR] jq not installed` | Install jq: `apt-get install jq` (Linux) or `brew install jq` (Mac) |
| `Access Denied` error | Verify AWS credentials and permissions in IAM |
| `404 Not Found` on API | Check API_URL is correct and Lambda is deployed |
| `Unauthorized` on token | Ensure JWT tokens are fresh and valid |
| `No such file or directory` | You may be in the wrong lesson folder |

---

## Files Reference

- **exploit_lessonX.sh** - Demonstrates the vulnerability and proves exploitability
- **fix_lessonX.sh** - Patches the vulnerable code and redeploys to AWS

Each fix script:
1. Downloads the Lambda deployment package
2. Applies security patches to source code
3. Rezips and redeploys the function
4. Re-runs the exploit to verify the fix works

---

## Notes for Instructors

- All scripts are intentionally verbose to aid learning
- Color-coded output (RED=attack, GREEN=success, YELLOW=info, CYAN=sections)
- CloudWatch log integration shows real-time evidence
- Scripts fail gracefully with helpful error messages
- Can be modified to add custom payloads or extend for additional scenarios

---

## Resources

- [OWASP Top 10 AWS Security Best Practices](https://owasp.org)
- [AWS Lambda Security Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/security.html)
- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- CVE-2017-5941: https://nvd.nist.gov/vuln/detail/CVE-2017-5941

---

## License

Educational use only. Use responsibly in authorized environments only.

Last Updated: May 5, 2026
