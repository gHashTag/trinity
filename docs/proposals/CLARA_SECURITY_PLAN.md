# CUI Protection Plan for Trinity CLARA Proposal

**Document Version**: 1.0
**Date**: 2026-03-27
**Purpose**: Security plan for protecting Controlled Unclassified Information (CUI) under DARPA CLARA

---

## Executive Summary

Trinity is an open-source project. All CUI will be segregated from public repositories and protected via Git-based access controls. This plan documents the security measures for handling DARPA CUI during the CLARA engagement.

**Key Principle**: Zero CUI in public repositories. All DARPA-sensitive materials go to private repository.

---

## 1. Repository Structure

### 1.1 Public Repository (No CUI)

```
trinity/                    # Public (GitHub, MIT license)
  ├── src/                  # Public source code
  ├── docs/                 # Public documentation
  ├── test/                 # Public tests
  ├── fpga/                 # FPGA bitstreams (public)
  ├── .github/              # CI/CD (public)
  ├── CLAUDE.md             # Project instructions (public)
  └── README.md             # Project overview (public)

Access: Anyone (read/write via PR)
License: MIT/Apache 2.0
CUI: NONE
```

### 1.2 Private Repository (CUI)

```
trinity-cui/                # Private (GitHub, restricted access)
  ├── proposals/            # DARPA proposal documents (CUI)
  ├── reporting/            # Quarterly reports, deliverables (CUI)
  ├── form-60/              # DARPA Form 60 submissions (CUI)
  ├── reviews/              # DARPA review comments (CUI)
  ├── meetings/             # Meeting notes (CUI)
  └── .claude-cui/          # CUI-specific configs

Access: Named users only (2FA required)
License: Not applicable (DARPA data)
CUI: ALL CONTENT
```

### 1.3 Access Control Matrix

| Repository | Public Read | Public Write | Named Users | CUI |
|------------|-------------|--------------|-------------|-----|
| `trinity` | ✅ | ⚠️ (via PR) | ❌ | ❌ |
| `trinity-cui` | ❌ | ❌ | ✅ | ✅ |

---

## 2. Data Classification

### 2.1 Classification Categories

| Category | Definition | Examples | Storage | Access |
|----------|------------|----------|---------|--------|
| **CUI** | DARPA-sensitive | Proposals, reports, reviews | Private repo | Named users only |
| **Public** | Open-source | Source code, docs, papers | Public repo | Anyone |
| **Export-controlled** | ITAR/EAR | Technical data (N/A) | Not stored | N/A (open-source) |

### 2.2 CUI Examples

**DEFINITELY CUI** (must go to `trinity-cui/`):
- DARPA CLARA proposal (before award)
- Quarterly progress reports
- DARPA review comments and responses
- Budget details with cost share
- Form 60 submissions (PI biographical data)
- Meeting notes with DARPA personnel

**DEFINITELY PUBLIC** (can go to `trinity/`):
- Source code (MIT/Apache 2.0)
- Research papers (arXiv, Zenodo)
- FPGA bitstreams (open hardware)
- Documentation (technical, API)
- Test results (non-sensitive)

**GRAY AREA** (case-by-case):
- Experimental data (if DARPA-funded → CUI)
- Performance metrics (if classified benchmarks → CUI)
- Collaboration agreements (review with legal)

---

## 3. Access Control

### 3.1 Named Users Policy

**Principle of Least Privilege**: Only users who need CUI access get it.

**Named Users** (for `trinity-cui/`):
1. **Principal Investigator (PI)**: Owner, full access
2. **Co-PI**: Full access
3. **Administrative Assistant**: Read-only access to reporting/

**Onboarding**:
1. User signs CUI handling agreement
2. User completes DARPA CUI training
3. User enables GitHub 2FA
4. Admin adds user to `trinity-cui` repository

**Offboarding**:
1. Admin removes user from `trinity-cui` repository
2. User access revoked immediately
3. Audit log reviewed for data access

### 3.2 GitHub Security Settings

**Repository Settings** (`trinity-cui/`):
```
✅ Private repository
✅ Force 2FA for all collaborators
✅ Restrict issue creation to collaborators
✅ Disable forking (critical for CUI)
✅ Enable "Protected branches" (main)
✅ Require pull request reviews (1 approval)
✅ Require status checks to pass
✅ Enable "Secret scanning" (for credentials)
✅ Enable "Dependabot alerts"
```

**Branch Protection** (`trinity-cui/main`):
```
✅ Require pull request before merging
✅ Require 1 approval
✅ Dismiss stale PR approvals
✅ Require status checks to pass
✅ Require branches to be up to date
✅ Lock branch to non-admins (optional)
```

### 3.3 Audit Logging

**GitHub Audit Log** (Enterprise feature):
- All access attempts (success/failure)
- All clone operations
- All push operations
- All PR creation/merge events
- All permission changes

**Retention**: 90 days (GitHub default) + export to permanent storage

**Review**: Weekly by PI, monthly by security review

---

## 4. Communication Security

### 4.1 Email

**CUI Email Policy**:
- ✅ Use PGP encryption for CUI attachments
- ✅ Send to `@darpa.mil` addresses only
- ❌ No CUI to personal email addresses
- ❌ No CUI in subject line (use "CLARA Proposal" not "Secret DARPA Data")

**PGP Key Management**:
```
PI Key: RSA 4096-bit, published on keyserver
Rotation: Annually
Revocation: Immediate if compromised
```

### 4.2 Meetings

**DARPA-Approved Platforms**:
- ✅ Zoom Gov (https://gov.zoom.us)
- ✅ Microsoft Teams (FedRAMP authorized)
- ✅ Google Meet (for non-sensitive)
- ❌ Personal Zoom (not approved)

**Meeting Notes**:
- ✅ Summarize key points (not verbatim)
- ✅ Store in `trinity-cui/meetings/`
- ❌ No audio/video recording without approval

### 4.3 File Sharing

**ALLOWED**:
- ✅ GitHub private repository (for code/docs)
- ✅ DARPA-approved file transfer (if provided)
- ✅ PGP-encrypted email attachments

**PROHIBITED**:
- ❌ Personal cloud storage (Dropbox, Google Drive, OneDrive)
- ❌ Public file sharing (WeTransfer, SendSpace)
- ❌ Unencrypted email for CUI

---

## 5. Incident Response

### 5.1 Incident Categories

| Category | Example | Response Time |
|----------|---------|---------------|
| **Critical** | CUI published to public repo | Immediate (within 1 hour) |
| **High** | Unauthorized access attempt | Within 4 hours |
| **Medium** | Suspected CUI in public docs | Within 24 hours |
| **Low** | Process violation (no exposure) | Within 1 week |

### 5.2 Response Procedure

**Step 1: Identify** (0-1 hour)
- Determine scope (what data, who accessed)
- Classify severity (Critical/High/Medium/Low)

**Step 2: Contain** (0-4 hours)
- If CUI on public repo: Immediately delete
- Revoke all non-essential access
- Change passwords/keys

**Step 3: Notify** (Within 24 hours)
- Email: CLARA@darpa.mil
- Subject: "CLARA Security Incident - [Project Name]"
- Content: What happened, what we did, what we're doing next

**Step 4: Remediate** (Within 1 week)
- Root cause analysis
- Process update to prevent recurrence
- Security review (all CUI access)

**Step 5: Post-Mortem** (Within 2 weeks)
- Document incident timeline
- Update security plan (this document)
- Training refresh for all users

### 5.3 Incident Report Template

```markdown
# CLARA Security Incident Report

**Date**: [YYYY-MM-DD]
**Severity**: [Critical/High/Medium/Low]
**Reporter**: [Name]

## What Happened
[Description of incident]

## Timeline
| Time | Event |
|------|-------|
| HH:MM | [Event 1] |
| HH:MM | [Event 2] |

## Impact Assessment
- **Data exposed**: [Yes/No, what data]
- **Users affected**: [Number, who]
- **DARPA notified**: [Yes/No, when]

## Containment Actions
1. [Action 1]
2. [Action 2]

## Root Cause
[Analysis of why it happened]

## Preventive Measures
1. [Measure 1]
2. [Measure 2]

## Status
- [ ] Contained
- [ ] Notified DARPA
- [ ] Remediated
- [ ] Post-mortem complete
```

---

## 6. Training and Certification

### 6.1 CUI Training

**Required for**: All named users with `trinity-cui/` access

**DARPA Online Course**: "Handling CUI" (if provided by DARPA)

**Trinity Internal Training** (annual refresher):
```
Module 1: What is CUI? (30 min)
  - Definition, examples, gray areas
  - Classification exercise

Module 2: Access Control (30 min)
  - GitHub security settings
  - 2FA setup, best practices
  - Named user onboarding/offboarding

Module 3: Communication Security (20 min)
  - Email encryption (PGP)
  - Approved meeting platforms
  - File sharing rules

Module 4: Incident Response (20 min)
  - How to identify incidents
  - Response procedure
  - Reporting requirements

Total: 100 minutes (1h 40m)
```

**Completion Tracking**:
- Training date logged in `trinity-cui/.claude-cui/training.log`
- Annual refresher required
- New users must complete before access

### 6.2 Security Awareness

**Monthly Reminders** (email to all named users):
- CUI handling refresh
- New threats/vulnerabilities
- Policy updates

**Quarterly Reviews**:
- Access audit (who has access, still needed?)
- Repository audit (is any CUI in public repo?)
- Training compliance (everyone up to date?)

---

## 7. Compliance Monitoring

### 7.1 Automated Checks

**Pre-Commit Hook** (for `trinity-cui/`):
```bash
#!/bin/bash
# Check for accidental CUI in commits

# Block commits with keywords in public repo
if [[ "$(git remote get-url origin)" == *"trinity"* ]] && \
   [[ "$(git remote get-url origin)" != *"-cui"* ]]; then
    if git diff --cached | grep -i "CLARA\|DARPA\|CUI"; then
        echo "ERROR: Possible CUI in public repository!"
        echo "Use trinity-cui/ repository for DARPA materials."
        exit 1
    fi
fi
```

**Scheduled Scans** (weekly):
```bash
# Scan public repo for CUI keywords
cd trinity/
grep -r "CLARA\|DARPA\|CUI\|proposal" . || echo "No CUI found"
```

### 7.2 Manual Reviews

**Weekly** (PI):
- Review `trinity-cui/` access log
- Check for any new forks (should be none)
- Verify 2FA compliance

**Monthly** (security review):
- Full audit of all repositories
- Verify CUI segregation
- Review incident reports (if any)

**Quarterly** (DARPA reporting):
- Compliance status report
- Security metrics
- Training completion

---

## 8. Software Supply Chain

### 8.1 Dependency Management

**Public Repository** (`trinity/`):
- ✅ Open-source dependencies (Zig std, Yosys)
- ✅ Dependabot alerts enabled
- ✅ Security updates applied within 30 days

**Private Repository** (`trinity-cui/`):
- ✅ No external dependencies (docs only)
- ✅ No code execution (read-only storage)

### 8.2 CI/CD Security

**Public CI** (`trinity/.github/`):
```
✅ GitHub Actions (open-source workflows)
✅ No secrets in logs
✅ pinned action versions (not @latest)
✅ Dependabot for dependency updates
```

**No CI for CUI**:
- `trinity-cui/` has no CI/CD (read-only storage)
- No automated builds of CUI content
- Manual review only

---

## 9. Data Retention and Disposal

### 9.1 Retention Policy

| Document Type | Retention Period | Location |
|---------------|------------------|----------|
| Proposals | 7 years after award | `trinity-cui/proposals/` |
| Quarterly reports | 7 years after award | `trinity-cui/reporting/` |
| Meeting notes | 3 years | `trinity-cui/meetings/` |
| Form 60 | 3 years after award | `trinity-cui/form-60/` |
| Audit logs | 90 days (GitHub) + export | Permanent storage |

### 9.2 Disposal Procedure

**After Retention Period**:
1. Review with DARPA program manager (confirm OK to dispose)
2. Secure deletion (Git history purge, not just file delete)
3. Verification (confirm data unrecoverable)
4. Document disposal in log

**Git History Purge** (for sensitive data):
```bash
# WARNING: Destructive, use with caution
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch path/to/cui/file" \
  --prune-empty --tag-name-filter cat -- --all

# Force push (only on private repo!)
git push origin --force --all
```

---

## 10. Third-Party Risk Management

### 10.1 GitHub (Platform)

**Risk Assessment**: LOW
- GitHub is FedRAMP authorized
- Used by DARPA for open-source projects
- 2FA, encryption at rest

**Mitigation**: None needed (platform is approved)

### 10.2 Collaboration Tools

**Zoom Gov** (for meetings):
- FedRAMP authorized
- End-to-end encryption available
- No CUI in chat (use voice only)

**Email** (for communication):
- PGP encryption for CUI attachments
- `@darpa.mil` addresses only

### 10.3 No Third-Party Code

**Principle**: All CUI handling is manual, no third-party libraries.

**Risk**: MITIGATED (no supply chain attack surface)

---

## 11. Certification and Attestation

### 11.1 PI Attestation

**I certify that**:
- [ ] I have completed CUI training
- [ ] I understand the classification rules
- [ ] I have access to `trinity-cui/` repository
- [ ] I will report incidents within 24 hours
- [ ] I will segregate CUI from public repos

**Signature**: _____________________
**Date**: _______________

### 11.2 Annual Compliance Review

**Review Checklist**:
- [ ] All named users completed training
- [ ] No CUI in public repository
- [ ] Access list up to date (remove departed users)
- [ ] 2FA enabled for all users
- [ ] Audit logs reviewed
- [ ] Incident procedures tested
- [ ] Security plan updated

**Reviewer**: _____________________
**Date**: _______________

---

## 12. Summary

### Security Posture

| Aspect | Status | Notes |
|--------|--------|-------|
| **Repository segregation** | ✅ | Public vs private |
| **Access control** | ✅ | Named users, 2FA |
| **Communication security** | ✅ | PGP email, approved platforms |
| **Incident response** | ✅ | 24-hour notification |
| **Training** | ✅ | Annual requirement |
| **Compliance monitoring** | ✅ | Weekly scans, quarterly reviews |

### Key Contacts

| Role | Name | Email | GitHub |
|------|------|-------|--------|
| **PI** | [Name] | [Email] | @[username] |
| **DARPA PM** | [Name] | CLARA@darpa.mil | N/A |
| **Security Lead** | [Name] | [Email] | @[username] |

### Document Approval

| Role | Name | Signature | Date |
|------|------|-----------|------|
| **Author** | Trinity PI | _____________________ | _______________ |
| **Reviewer** | Security Lead | _____________________ | _______________ |
| **Approved** | DARPA PM | _____________________ | _______________ |

---

## References

1. DARPA CLARA PA-25-07-02: Security Requirements
2. CUI Regulation: 32 CFR 2002
3. GitHub Security Best Practices: https://docs.github.com/en/security
4. FedRAMP Marketplace: https://marketplace.fedramp.gov

---

**φ² + 1/φ² = 3 | TRINITY**

**Document Control**:
- Version: 1.0
- Owner: Trinity PI
- Review: Quarterly
- Classification: CUI (store in `trinity-cui/`)
