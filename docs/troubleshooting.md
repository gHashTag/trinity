# Troubleshooting Guide

This guide helps resolve common issues when working with Trinity.

---

## Build Issues

### "zig build test" fails

**Symptoms:** Compilation errors in test files

**Solutions:**
1. Ensure Zig 0.15.x is installed:
   ```bash
   zig version  # Should be 0.15.x
   ```
2. Clean build artifacts:
   ```bash
   zig build clean
   zig build test
   ```
3. Check for Zig 0.15 API migration issues:
   - `ArrayList.init()` → `ArrayList.empty()`
   - `append(item)` → `append(allocator, item)`
   - `std.time.sleep` → `std.Thread.sleep`

### "Test command not yet implemented"

**Symptoms:** `tri test` shows limited functionality message

**Solution:** Use `zig build test` instead:
```bash
zig build test  # Full test suite
tri test         # Limited, use zig build test
```

### Format errors on commit

**Symptoms:** Pre-commit hook fails with formatting issues

**Solution:**
```bash
zig fmt src/
git add src/
git commit
```

---

## FPGA Issues

### FPGA programming fails

**Symptoms:** `openFPGALoader` cannot detect board or fails to program

**Critical:** JTAG cable MUST be in JTAG mode (PID 0x0008), not bootloader mode (PID 0x0013)

**Solution:**
```bash
# First, switch cable to JTAG mode
fxload -t fx2 -I ./fpga/openxc7-synth/xc7a-xc7s-ftdi.hex -d 0x0013

# Then program
tri fpga flash
# OR
./fpga/tools/flash_no_sudo.sh hslm_full_top.bit
```

**Never skip fxload step** — programming will fail.

### UART communication fails (no echo)

**Symptoms:** `tri fpga uart` runs but no response from board

**Possible Causes:**
1. **UART headers not soldered** — Hardware issue, cannot be fixed in software
2. **Wrong baud rate** — Check UART_README.md for correct rate
3. **CPLD issue** — Abnormal CPLD version indicates hardware problem

**Diagnosis:**
```bash
# Check CPLD version
tri fpga probe

# If CPLD shows 0xFFFE consistently, this is a DLC10 clone with known behavior
```

**Solution:** Do not debug software if UART headers are not soldered. Hardware modification required.

### "openFPGALoader --cable xpc" fails

**Symptoms:** Error when trying to use xpc cable type

**Cause:** openFPGALoader does not support `--cable xpc`

**Solution:** Use `fxload` first, then:
```bash
openFPGALoader --cable ft232 --bitstream hslm_full_top.bit
```

---

## Training Issues

### Training stalls at low steps

**Symptoms:** Loss stops improving before 10K steps

**Cause:** Using `flat` LR schedule instead of `cosine`

**Solution:**
```yaml
# In Railway environment variables
HSLM_LR_SCHEDULE: cosine  # NOT flat
```

**Never use flat schedule** — training dead by 20K steps.

### Early kill at 30K steps

**Symptoms:** Worker stops automatically around 30K steps

**Cause:** Old binary bug (fixed in recent versions)

**Solution:**
```bash
# Restart worker with latest binary
tri farm recycle --service <service-id>
```

### PPL not improving

**Symptoms:** Loss oscillating or not decreasing

**Diagnosis:**
1. Check context length (should be ≥ 81 for NTP)
2. Verify LR schedule is cosine
3. Check for repetition rate anomalies
4. Review 5-gate record verification

**Solution:**
```bash
# Check SEVO configuration
tri farm evolve --auto
```

---

## Cloud & Deployment Issues

### Railway deployment fails

**Symptoms:** Service fails to start on Railway

**Checks:**
1. **Dockerfile** is being used:
   ```bash
   # Check service config
   railway service instance get --service-id <id>
   # Should show: builder: NIXPACKS
   ```
2. **Environment variables** are set:
   ```bash
   railway variable list --service-id <id>
   # Minimum required: HSLM_OPTIMIZER, HSLM_LR, HSLM_LR_SCHEDULE
   ```
3. **Dockerfile path** is correct:
   ```yaml
   # Must set in service config, NOT just env var
   dockerfilePath: "Dockerfile.hslm-train"
   ```

**Solution:**
```bash
# Update service config
tri deploy update --service-id <id> --dockerfile-path "Dockerfile.hslm-train" --builder nixpacks
```

### "startCommand cannot be set" error

**Symptoms:** Deployment fails when startCommand is set

**Cause:** Training services must use Dockerfile ENTRYPOINT, not Railway's startCommand

**Solution:**
```bash
# Remove startCommand from service config
railway service update --service-id <id> --start-command null
```

---

## Agent Issues

### "Agent timeout" in logs

**Symptoms:** Agent stops after 1 hour without completing task

**Cause:** Default AGENT_TIMEOUT is 3600s (1 hour)

**Solution:** Adjust timeout in `.ralph/config.json`:
```json
{
  "timeout_seconds": 7200  // 2 hours
}
```

### Agent fails to create PR

**Symptoms:** Agent reports success but no PR is created

**Diagnosis:**
1. Check PAT permissions (must have `repo` scope)
2. Verify branch exists on remote
3. Check for merge conflicts

**Solution:**
```bash
# Verify agent token
gh auth status

# Check agent logs
tri cloud history <issue-number>
```

---

## Documentation Issues

### Broken links

**Symptoms:** Clicking links in README or docs results in 404

**Solution:**
1. Report the broken link in a GitHub issue
2. CI automatically checks for broken links on PR

### Outdated command reference

**Symptoms:** Command in README doesn't match actual behavior

**Solution:**
1. Check command registry: `tri help`
2. Report discrepancy in issue

---

## Performance Issues

### Slow compilation

**Symptoms:** `zig build` takes very long

**Solutions:**
1. Use `zig build --summary all` to see what takes longest
2. Incremental builds help after first full build
3. Consider using `zig build-exe cache` if available

### High memory usage

**Symptoms:** Process OOMs during build or training

**Solutions:**
1. Reduce batch size for training
2. Close other applications
3. Increase swap space (Linux) or check memory limits (macOS)

---

## Error Messages Reference

| Error | Category | Solution | Link |
|--------|-----------|------------|-------|
| E0501 | Memory management | Check allocators | [src/vsa/README.md](src/vsa/README.md) |
| E0502 | Allocator leak | Verify cleanup | [Memory Guide](docs/troubleshooting.md) |
| E0601 | UART timeout | Check hardware connection | [UART README](fpga/openxc7-synth/UART_README.md) |
| E0701 | Training config | Verify env vars | [Farm Guide](.claude/projects/-Users-playra-trinity-w1/memory/project_farm_patterns.md) |
| E0801 | Agent token expired | Refresh PAT | [Cloud Pipeline](.claude/projects/-Users-playra-trinity-w1/memory/project_cloud_dev_pipeline.md) |

---

## Getting Help

### Where to Report Issues

1. **GitHub Issues**: https://github.com/gHashTag/trinity/issues
2. **GitHub Discussions**: For questions and general discussion
3. **Telegram**: Community notifications (see README for link)

### What to Include in Bug Reports

- Trinity version: `tri --version`
- Zig version: `zig version`
- OS and version
- Full error message or stack trace
- Steps to reproduce
- Expected vs actual behavior

### Before Reporting

1. Search existing issues (your problem may already be reported)
2. Check documentation index: [docs/DOCUMENTATION_INDEX.md](docs/DOCUMENTATION_INDEX.md)
3. Try latest version (issue may be fixed)

---

*Last updated: 2026-03-24*
