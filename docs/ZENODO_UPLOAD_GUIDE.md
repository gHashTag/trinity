# Zenodo v9.0 Upload Guide — Step-by-Step

> φ² + 1/φ² = 3 | TRINITY
> **Status:** Ready for Publication
> **Date:** 2026-03-27

---

## Prerequisites

### 1. Zenodo Account
- Create account: https://zenodo.org/signup
- Verify email address

### 2. API Token
- Go to: https://zenodo.org/account/settings/applications/tokens/new
- Click "New token"
- Scopes: `deposit:write`, `deposit:actions:update`
- Copy token to clipboard

### 3. Set Environment Variable
```bash
export ZENODO_TOKEN="your_token_here"
# Or add to .env file:
echo "ZENODO_TOKEN=your_token_here" >> .env
```

### 4. Verify Token
```bash
curl -H "Authorization: Bearer $ZENODO_TOKEN" https://zenodo.org/api/deposit/depositions
```

Expected output: JSON array of your depositions (may be empty `[]`)

---

## Step-by-Step Upload

### Option A: Upload All Bundles (Recommended)

```bash
# Dry-run (validation only)
python3 tools/zenodo_upload_v9.py --dry-run --all

# Actual upload
python3 tools/zenodo_upload_v9.py --all
```

### Option B: Upload Individual Bundle

```bash
# B001 (HSLM)
python3 tools/zenodo_upload_v9.py --bundle B001

# B002 (FPGA)
python3 tools/zenodo_upload_v9.py --bundle B002

# ... etc
```

### Option C: Upload Parent Collection Only

```bash
python3 tools/zenodo_upload_v9.py --bundle PARENT
```

---

## Expected Output

### Successful Upload

```
============================================================
Publishing B001 to Zenodo...
============================================================
Title: Trinity B001: HSLM-1.95M Ternary Neural Networks v9.0
Version: 9.0

[1/4] Creating deposition...
     Draft ID: 1234567

[2/4] Updating metadata...

[3/4] Uploading figures...
     Uploaded 3 figure files

[4/4] Publishing...

============================================================
✅ B001 Published!
============================================================
DOI:         10.5281/zenodo.19227865
Concept DOI: 10.5281/zenodo.19227865
URL:         https://doi.org/10.5281/zenodo.19227865
```

---

## Troubleshooting

### Error: "401 Unauthorized"
**Cause:** Invalid or missing API token
**Fix:**
```bash
# Verify token
curl -H "Authorization: Bearer $ZENODO_TOKEN" https://zenodo.org/api/deposit/depositions
# If 401, regenerate token and try again
```

### Error: "400 Bad Request"
**Cause:** Invalid metadata format
**Fix:**
```bash
# Validate metadata
python3 tools/validate_zenodo_v19.py --all
```

### Error: "404 Not Found"
**Cause:** Bundle JSON file not found
**Fix:** Verify file exists at `docs/research/.zenodo.BXXX_v9.0.json`

### Error: "413 Payload Too Large"
**Cause:** Files exceed Zenodo limit
**Fix:**
- Remove large files from upload
- Use Git LFS for large binaries
- Compress figures before upload

---

## Post-Upload Verification

### 1. Check Zenodo Record
- Visit: https://zenodo.org/record/19227865
- Verify title, authors, description
- Check DOI is correct

### 2. Verify Files
- Click "Files" tab
- Check all expected files are present
- Verify file sizes

### 3. Test Download
- Click "Download" button
- Extract and verify contents

### 4. Update CITATION.cff
After first upload, update DOI if auto-generated:
```yaml
doi: 10.5281/zenodo.YOUR_ACTUAL_DOI
```

---

## Version Management

### Creating New Version

```bash
# Update version in metadata JSON
# "version": "9.0" → "9.1"

# Upload new version
python3 tools/zenodo_upload_v9.py --bundle B001
```

Zenodo automatically:
- Creates new version under same concept DOI
- Preserves version history
- Links all versions together

### Best Practices

1. **Semantic Versioning:** Major.Minor.Patch (e.g., 9.0.0 → 9.0.1 → 9.1.0)
2. **Changelog:** Document changes in description
3. **Backward Compatibility:** Minor versions should be compatible
4. **Deletion:** Never delete published versions

---

## Integration with GitHub

### Automatic Deposit from GitHub Actions

Add `.github/workflows/zenodo-publish.yml`:

```yaml
name: Zenodo Publish

on:
  release:
    types: [published]

jobs:
  zenodo:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Publish to Zenodo
        env:
          ZENODO_TOKEN: ${{ secrets.ZENODO_TOKEN }}
        run: |
          python3 tools/zenodo_upload_v9.py --bundle PARENT
```

### GitHub-Zenodo Link

1. Go to Zenodo record
2. Click "On GitHub integration"
3. Select repository: `gHashTag/trinity`
4. Zenodo will automatically update on new releases

---

## Citation After Upload

### BibTeX
```bibtex
@software{trinity_b001,
  title={Trinity B001: HSLM-1.95M Ternary Neural Networks v9.0},
  author={Vasilev, Dmitrii},
  year={2026},
  doi={10.5281/zenodo.19227865},
  publisher={Zenodo}
}
```

### APA
```
Vasilev, D. (2026). Trinity B001: HSLM-1.95M ternary neural networks v9.0. Zenodo. https://doi.org/10.5281/zenodo.19227865
```

### IEEE
```
D. Vasilev, "Trinity B001: HSLM-1.95M ternary neural networks v9.0," Zenodo, 2026. doi: 10.5281/zenodo.19227865.
```

---

## Checklist

Before Upload:
- [ ] All metadata validated (`python3 tools/validate_zenodo_v19.py --all`)
- [ ] CITATION.cff exists at project root
- [ ] README.md is up to date
- [ ] LICENSE file is included
- [ ] All tests pass (`zig build test`)
- [ ] Code formatted (`zig fmt`)

After Upload:
- [ ] Verify record on Zenodo website
- [ ] Check DOI is correct
- [ ] Test download
- [ ] Update GitHub release notes
- [ ] Notify collaborators

---

## Support

**Documentation:** https://gHashTag.github.io/trinity

**Issues:** https://github.com/gHashTag/trinity/issues

**Email:** dmitrii@trinity.ai

---

**φ² + 1/φ² = 3 | TRINITY**
