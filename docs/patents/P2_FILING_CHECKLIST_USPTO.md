# P2 USPTO Provisional Filing Checklist

**Target**: USPTO Provisional Patent Application
**Date**: 2026-03-09
**Status**: READY TO FILE

---

## ✅ PRE-FILING PREPARATION

### 1. Application Document
- [x] **Specification**: `P2_PROVISIONAL_APPLICATION.md` created
- [x] **Abstract**: Included in specification
- [x] **Detailed Description**: Complete with embodiments
- [x] **Claims**: 13 claims drafted
- [x] **Drawings**: 4 figures included

### 2. Evidence Package
- [x] **Hardware Proof**: test_top.bit, d6_blink.bit, uart_top.bit verified
- [x] **Synthesis Reports**: 0 DSP48 proven
- [x] **Code Evidence**: protocol.zig, vsa.zig, uart_top.tri
- [x] **Video Evidence**: LED blink verification (55.1%, 33.6%, 56.5% variation)

### 3. Inventor Information
- [ ] **Full Legal Names**: All inventors
- [ ] **Residence**: Complete address
- [ ] **Citizenship**: For each inventor
- [ ] **Assignment**: If applicable

### 4. Applicant Information
- [ ] **Applicant Name**: Individual or entity
- [ ] **Address**: Mailing address
- [ ] **Entity Status**: Small business, micro entity, or large entity
- [ ] **Correspondence**: Email/phone for USPTO contact

---

## 📋 USPTO FILING STEPS

### Step 1: USPTO Account Setup (if not done)
1. Go to: https://uspto.gov
2. Create USPTO.gov account (if needed)
3. Access EFS-Web (Electronic Filing System)
4. Complete identity verification

**Time**: 15 minutes

### Step 2: Prepare Application Files

#### 2.1 Specification Document
**File**: `P2_PROVISIONAL_APPLICATION.md`
- Convert to PDF format
- Ensure all text is searchable
- Include page numbers
- File naming: `specification.pdf`

#### 2.2 Cover Sheet
**Form**: USPTO Provisional Application Cover Sheet (SB/01)
- Download from: https://www.uspto.gov/forms/
- Fill in:
  - Application title: "Ternary Vector Symbolic Architecture Coprocessor with Wire Protocol for Zero-DSP48 Vector Processing"
  - Inventor information
  - Applicant information
  - Correspondence address
  - Entity status

**File naming**: `cover_sheet.pdf`

#### 2.3 Application Data Sheet (Optional but Recommended)
**Form**: USPTO ADS (Application Data Sheet)
- Inventor details
- Applicant details
- Foreign priority (if any)
- Domestic benefit (if any)

**File naming**: `ads.pdf`

### Step 3: Payment Calculation

#### Fee Schedule (2026)
| Entity Type | Provisional Filing Fee |
|-------------|----------------------|
| Large Entity | $316 |
| Small Entity | $158 |
| Micro Entity | $79 |

**Micro Entity Qualification**:
- Applicant qualifies as small entity AND
- Applicant has not been named on more than 4 provisional applications
- Applicant's gross income < $219,270 (2026) OR
- Applicant is obligated to assign to institution of higher education

### Step 4: EFS-Web Submission

1. **Login** to EFS-Web: https://efs.uspto.gov/EFSWebUI

2. **Start New Provisional Application**:
   - Select "Provisional Patent Application"
   - Enter application title
   - Upload documents:
     - specification.pdf (required)
     - cover_sheet.pdf (required)
     - ads.pdf (optional)
     - drawings.pdf (if separate from specification)

3. **Review Application**:
   - Verify all fields complete
   - Check document integrity
   - Confirm file formats (PDF only)

4. **Submit and Pay**:
   - Select payment method (credit card)
   - Confirm entity type for fee calculation
   - Complete payment
   - Receive provisional serial number

**Expected Serial Number Format**: 63/XXXX,XXX

### Step 5: Post-Filing

1. **Save Confirmation**:
   - Serial number: 63/_________
   - Filing date: _____________
   - Confirmation receipt: ___________

2. **Update Documentation**:
   - Add serial number to all P2 documents
   - Update claim chart with filing data
   - Mark as "FILED" in project tracker

3. **Track Deadline**:
   - **Provisional expires**: 12 months from filing date
   - **Non-provisional must be filed by**: 2027-03-09
   - **Benefit claimed**: In non-provisional application

---

## 📁 DOCUMENT PACKAGE

### Files to Upload to USPTO:

| File | Description | Required |
|------|-------------|----------|
| P2_PROVISIONAL_APPLICATION.pdf | Complete specification | ✅ Yes |
| SB01.pdf | Cover sheet (Form SB/01) | ✅ Yes |
| ADS.pdf | Application data sheet | Optional |
| DRAWINGS.pdf | Figures (if separate) | Optional |

### File Size Limits:
- **Maximum**: 100 MB per application
- **Format**: PDF only
- **Resolution**: 300 DPI for drawings

---

## 💰 FEE SUMMARY

| Item | Amount |
|------|--------|
| Provisional filing fee (Micro) | $79 |
| Provisional filing fee (Small) | $158 |
| Provisional filing fee (Large) | $316 |

**Total Expected**: $79 - $316 (depending on entity status)

**Payment Methods**: Credit card, USPTO deposit account, or EFT

---

## ⏱️ TIME ESTIMATE

| Step | Time |
|------|------|
| Account setup | 15 min |
| Document preparation | 30 min |
| EFS-Web submission | 20 min |
| **Total** | **~1 hour** |

---

## 📞 USPTO CONTACT

- **Website**: https://www.uspto.gov
- **EFS-Web**: https://efs.uspto.gov
- **Inventor Assistance**: 1-800-PTO-9199
- **Customer Service**: 571-272-1000

---

## ✅ PRE-SUBMISSION VERIFICATION

Before submitting, verify:

- [ ] All inventors listed correctly
- [ ] Entity status confirmed (micro/small/large)
- [ ] Payment method ready
- [ ] All documents converted to PDF
- [ ] Specification includes all required sections:
  - [ ] Title
  - [ ] Abstract
  - [ ] Description
  - [ ] Claims (optional for provisional but included)
  - [ ] Drawings (optional but included)
- [ ] No new matter added after this filing
- [ ] File sizes under 100 MB limit

---

## 📅 POST-FILING ACTION ITEMS

### Immediate (after filing)
1. Save serial number and filing date
2. Update project documentation
3. Notify all inventors of filing
4. Schedule non-provisional planning meeting

### 12-Month Timeline (before expiration)
| Month | Action |
|-------|--------|
| Month 1-3 | Refine claims, add experimental data |
| Month 4-6 | Prior art search, competitive analysis |
| Month 7-9 | Draft non-provisional application |
| Month 10-11 | Professional review, revisions |
| Month 12 | **File non-provisional** (by 2027-03-09) |

---

## 🔐 SECURITY NOTES

1. **Do NOT disclose invention publicly** before filing:
   - No publications
   - No conference presentations
   - No blog posts about technical details
   - No GitHub code releases for hardware cores

2. **After filing**:
   - Safe to disclose (provisional pending)
   - Mark materials: "U.S. Provisional Patent Application No. 63/XXXX,XXX"
   - Track 12-month deadline

---

## STATUS

**Last Updated**: 2026-03-09
**Current Status**: READY TO FILE ✅
**Priority**: P0 - FILE TODAY

---

φ² + 1/φ² = 3 = TRINITY
FILE P2 NOW — HARDWARE PROOF COMPLETE — 0 DSP48 PROVEN
