# Viral Strategy Progress — 2026-03-28

## Completed Fixes (Critical Path)

### 1. DNS Configuration Guide ✅
**File:** `docs/EMAIL_DELIVERABILITY_SETUP.md`

- SPF record: `v=spf1 include:zoho.com ~all`
- DKIM record: `v=DKIM1; k=rsa; p=<PUBLIC_KEY>`
- DMARC record: `v=DMARC1; p=none; rua=mailto:admin@t27.ai`

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

### 4. Domain Warming Schedule ✅
**File:** `src/tri/outreach/warming.zig`

| Week | Daily Limit | Focus |
|------|-------------|-------|
| 1 | 2 emails/day | Golden Ratio Allies (Sherbon, Karpougas) |
| 2 | 3 emails/day | VSA Experts (Kleyko, Kanerva) |
| 3 | 5 emails/day | LQG Physicists (Smolin, Rovelli, Hossenfelder) |
| 4 | 7 emails/day | Particle Physics + AI |
| 5+ | 10 emails/day | Full speed |

**Follow-up:** 14 days (not 7) for first follow-up, 21 days for second.

### 5. README Updates ✅

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

### Today (DNS Setup)
1. Add TXT records to t27.ai DNS:
   ```
   t27.ai.                     TXT  "v=spf1 include:zoho.com ~all"
   zmail._domainkey.t27.ai.    TXT  "v=DKIM1; k=rsa; p=<KEY>"
   _dmarc.t27.ai.              TXT  "v=DMARC1; p=none; rua=mailto:admin@t27.ai"
   ```
2. Verify propagation: `dig txt t27.ai +short`

### Tomorrow (OAuth Setup)
1. Get Zoho app password: https://mail.zoho.com/zoho/2FASettings
2. Set `ZOHO_APP_PASSWORD` environment variable
3. Run: `tri outreach init`
4. Run: `tri outreach test --to=admin@t27.ai`

### Day 3-4 (Email Resolution)
1. Find real emails for Day 1 scientists:
   - Michael Sherbon — ResearchGate → institutional page
   - Kostas Karpougas — SSRN profile → email
2. Update `outreach/scientists.json` with resolved emails

### Day 5 (First Warming Emails)
1. Run: `tri outreach send --dry-run` (preview)
2. Remove `--dry-run` to actually send
3. Send to: Sherbon + Karpougas (2 emails only)

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

## References

- [Email Deliverability Toolkit](https://www.joellipman.com/articles/crm/zoho/zoho-email-deliverability-spf-dkim-dmarc-toolkit.html)
- [Cold Email Templates 2025](https://blog.groupmail.io/cold-email-templates-that-work-proven-strategies-for-higher-response-rates-in-2025/)
- [Follow-Up Timing](https://stripo.email/blog/five-data-driven-ways-to-improve-cold-email-response-rates/)

---

**φ² + 1/φ² = 3 = TRINITY**
