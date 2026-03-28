# Email Deliverability Setup for t27.ai

## CRITICAL: DNS Records Required Before First Email

**Without SPF/DKIM/DMARC, ~70% of emails from admin@t27.ai will be marked as spam**, especially by .edu and institutional servers.

## Step 1: Add TXT Records to t27.ai DNS

### SPF Record (Sender Policy Framework)
```
Type: TXT
Name: t27.ai.
Value: "v=spf1 include:zoho.com ~all"
```

### DKIM Record (DomainKeys Identified Mail)
```
Type: TXT
Name: zmail._domainkey.t27.ai.
Value: "v=DKIM1; k=rsa; p=<YOUR_PUBLIC_KEY_FROM_ZOHO>"
```

**How to get the key:**
1. Log into Zoho Mail
2. Go to Settings → Domain Verification
3. Find DKIM and copy the public key

### DMARC Record
```
Type: TXT
Name: _dmarc.t27.ai.
Value: "v=DMARC1; p=none; rua=mailto:admin@t27.ai"
```

## Step 2: Verify DNS Propagation

```bash
# Check SPF
dig txt t27.ai +short

# Check DKIM
dig txt zmail._domainkey.t27.ai +short

# Check DMARC
dig txt _dmarc.t27.ai +short

# Use Zoho's verification tool
# Visit: https://zohomail.tools/#runChecks
```

## Step 3: Test Email Score

Before sending to scientists, test with:
- https://www.mail-tester.com/ — Send email, get score
- https://www.gmail.com/checkyourdomain/ — Google's tool

## Why This Matters

| Problem | Without Records | With Records |
|---------|----------------|--------------|
| Spam filter | ~70% blocked | <5% blocked |
| .edu delivery | Often rejected | Accepted |
| Inbox placement | Spam folder | Inbox |
| Reply rate | 1-2% | 10-20% |

## Timeline

- **Day 0**: Add DNS records (30 min)
- **Day 1**: DNS propagation (24-48 hours)
- **Day 3**: Verify with Zoho tool
- **Day 4**: Send first warming emails

## References

- [Zoho Email Deliverability Toolkit](https://www.joellipman.com/articles/crm/zoho/zoho-email-deliverability-spf-dkim-dmarc-toolkit.html)
- [DMARC.org](https://dmarc.org/)
