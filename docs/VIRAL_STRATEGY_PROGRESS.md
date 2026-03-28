# Viral Strategy Progress — 2026-03-28 (Round 2 Fixes)

## Completed Fixes (Round 1 + Round 2)

### 1. DNS Configuration Guide ✅ (UPDATED)
**File:** `docs/EMAIL_DELIVERABILITY_SETUP.md`

**Round 2 fixes:**
- **MX records** (10/20/50 priorities) — without them replies are lost
- **SPF with `zohomail.com`** (NOT `zoho.com`) — correct Zoho domain
- **DKIM from Zoho Admin Console** — exact selector (usually `zoho._domainkey`)
- **DMARC with `rua` + `ruf`** — forensic reports for debugging
- **Unstoppable Domains instructions** — exact UI steps
- **mail-tester.com 9+/10 goal** — verify before first email

**Why:** Without these, ~70% of emails from admin@t27.ai go to spam.

### 2. Outreach Module Structure ✅
**Directory:** `src/tri/outreach/`

| File | Purpose |
|------|---------|
| `types.zig` | Data structures (Scientist, EmailMessage, OutreachStatus) |
| `templates.zig` | SHORTENED email templates (80-120 words, not 300+) |
| `email_resolver.zig` | Parse institutional pages for real emails |
| `warming.zig` | Domain warming schedule (2→10 emails/day over 4 weeks) |
| `bounce_handler.zig` | Auto-mark invalid emails |
| `main.zig` | CLI commands (`tri outreach init/status/send/etc`) |

### 3. Shortened Email Templates ✅
**Fix:** Reduced from 300+ words to 80-120 words

**Data:** 50-125 word emails get ~50% reply rate, 300+ words get <5%

**Templates created:**
- `sherbon_short` — Parallel discovery (95 words)
- `karpougas_short` — φ⁵ formulas (88 words)
- `hossenfelder_short` — FAILURES FIRST (85 words)
- `kleyko_short` — VSA review (105 words)
- `kanerva_short` — Ternary VSA (98 words)
- `bitnet_short` — {-1,0,+1} alphabet (92 words)
- `smolin_short` — LQG + G constant (88 words)
- `rovelli_short` — Time + φ (82 words)
- `afshordi_short` — Dark energy (87 words)
- `chollet_short` — ARC via VSA (78 words)
- `rabaey_short` — Zero-DSP FPGA (83 words)

### 4. Domain Warming Schedule ✅ (UPDATED)
**File:** `src/tri/outreach/warming.zig`

**Round 2 fix:** 14-day manual warmup BEFORE first real email!

| Phase | Days | Daily Limit | Focus |
|-------|------|-------------|-------|
| **Manual Warmup** | 1-14 | 3 | Send to YOURSELF (Gmail, Outlook, Yahoo) → Open + Reply + mark "not spam" |
| **Engaged Contacts** | 15-21 | 3 | Golden Ratio Allies (Sherbon, Karpougas) |
| **Scaling** | 22-28 | 5 | VSA Experts (Kleyko, Kanerva, Rahimi) |
| **Full Volume** | 29+ | 8-10 | LQG, Cosmology, Particle Physics, AI |

**Critical:** Without 14-day manual warmup, even 10/10 mail-tester score = greylisting by large providers.

**Follow-up:** 14 days first follow-up, 21 days second follow-up.

### 5. RFC 8058 List-Unsubscribe Header ✅ (NEW)
**File:** `src/tri/outreach/smtp.zig`

**Gmail requirement since Feb 2024** for bulk senders:
```zig
List-Unsubscribe: <https://t27.ai/unsubscribe?id={uuid}>
List-Unsubscribe-Post: List-Unsubscribe=One-Click
```

**One-click** — user can unsubscribe without replying.

### 6. README Updates ✅

#### Honest Science Section
- **DELTA-001** prominently displayed at top
- Rejected hypotheses shown first (builds trust)
- Evidence level indicators (🔴 Smoking Gun, 🟡 Consistent, ⚫ Rejected)

#### Getting Started (5 Minutes)
```bash
npm install -g @playra/tri
tri --version
tri constants
tri phi 2
tri clara demo
```

#### GitHub Topics
19 topics added to README for discoverability:
- `ternary-computing`, `vsa`, `golden-ratio`, `fpga-inference`
- `zig`, `hypervector`, `neurosymbolic-ai`, `energy-efficient-ai`
- etc.

### 6. FOR_SCIENTISTS.md ✅
**File:** `docs/FOR_SCIENTISTS.md`

One-page summary for easy sharing with:
- What works (smoking guns)
- What doesn't work (honest reporting)
- Quick verification commands
- Contact info

## Next Steps (Immediate)

### Step 1: DNS Setup (15 min) — Unstoppable Domains
1. Open: https://unstoppabledomains.com/manage?page=dns&domain=t27.ai
2. Open: Zoho Admin Console → Domains → t27.ai
3. Add records in **exact order**:
   - **MX**: mx.zoho.com (10), mx2.zoho.com (20), mx3.zoho.com (50)
   - **SPF**: `"v=spf1 include:zohomail.com ~all"` (note: zohomail.com!)
   - **DKIM**: Get from Zoho Admin Console → Email Authentication → DKIM tab
   - **DMARC**: `"v=DMARC1; p=none; rua=mailto:admin@t27.ai; ruf=mailto:admin@t27.ai"`

### Step 2: Verify DNS (5 min)
```bash
dig mx t27.ai +short
dig txt t27.ai +short
dig txt zoho._domainkey.t27.ai +short  # replace with actual selector
dig txt _dmarc.t27.ai +short
```

### Step 3: Verify in Zoho (2 min)
Zoho Admin Console → Domains → t27.ai → Verify all 4 tabs (MX, SPF, DKIM, DMARC)

### Step 4: Test Score (10 min)
1. Get unique address from https://www.mail-tester.com/
2. Send test email from admin@t27.ai
3. Goal: **9+/10** before proceeding

### Step 5: 14-Day Manual Warmup (REQUIRED!)
**Days 1-14:** Send 2-3 emails/day to YOUR personal accounts
- your-personal@gmail.com
- your-personal@outlook.com
- your-personal@yahoo.com

**For each email:**
1. Send it
2. Open it immediately
3. Reply to it
4. Mark "not spam" if in spam folder

### Step 6: First Real Emails (Day 15+)
After 14-day warmup:
1. `tri outreach init` — OAuth setup
2. `tri outreach send --dry-run` — preview
3. `tri outreach send --batch=day1` — actually send (3 emails max)

## CLI Commands Available

```bash
tri outreach init                 # Initialize outreach system
tri outreach status                # Show warming status & queue
tri outreach send --dry-run        # Preview emails (no send)
tri outreach send --batch=day1     # Send today's batch
tri outreach follow-up             # Check pending follow-ups
tri outreach resolve <name>        # Resolve email from placeholder
tri outreach preview <template>    # Preview specific template
tri outreach test --to=<email>     # Send test email to yourself
```

## Metrics to Track

| Metric | Week 1 | Week 2 | Week 4 |
|--------|--------|--------|--------|
| Emails sent | 10 | 15 | 35 |
| Replies | 1-2 | 3-4 | 8-10 |
| Bounces | <1 | <2 | <5 |
| Spam complaints | 0 | 0 | 0 |

## Secondary Domain Recommendation (NEW)

**Never use primary domain for cold outreach!**

| Domain | Purpose | Cost |
|--------|---------|------|
| `t27.ai` | Primary — replies, collaborations | — |
| `trynity.ai` or `t27mail.com` | Cold outreach only | ~$10/year |

**Why:** If secondary domain gets blacklisted, primary remains clean.

---

## Updated Checklist (Round 2)

- [x] MX records (10/20/50 priorities)
- [x] SPF with `zohomail.com` (NOT `zoho.com`)
- [x] DKIM — exact selector from Zoho Admin Console
- [x] DMARC with `rua` and `ruf`
- [ ] Verified in Zoho (4 green checkmarks)
- [ ] mail-tester.com score 9+/10
- [ ] 14-day manual warmup completed
- [x] List-Unsubscribe header (RFC 8058) implemented
- [ ] Consider secondary domain for outreach

---

## References

- [Email Deliverability Toolkit](https://www.joellipman.com/articles/crm/zoho/zoho-email-deliverability-spf-dkim-dmarc-toolkit.html)
- [Cold Email Templates 2025](https://blog.groupmail.io/cold-email-templates-that-work-proven-strategies-for-higher-response-rates-in-2025/)
- [Follow-Up Timing](https://stripo.email/blog/five-data-driven-ways-to-improve-cold-email-response-rates/)

---

**φ² + 1/φ² = 3 = TRINITY**
