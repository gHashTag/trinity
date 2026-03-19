# TRINITY FPGA - AWS F2 AUTO-DEPLOY

**Sacred formula**: φ² + 1/φ² = 3  
**Goal**: Validate TRINITY V5.0 on real FPGA  
**Budget**: $5-10 for full test

---

## SCRIPTS

| Script | Description | Time |
|--------|-------------|------|
| `00_full_deploy.sh` | Full auto-deploy | 2-3 hours |
| `01_launch_f2.sh` | Launch F2 instance | 5 min |
| `02_setup_fpga.sh` | Setup environment | 10 min |
| `03_build_afi.sh` | Build AFI | 1-2 hours |
| `04_test_trinity.sh` | Testing | 15 min |
| `05_stop_instance.sh` | Stop (IMPORTANT!) | 1 min |

---

## QUICK START

### Option 1: Full auto-deploy
```bash
cd deploy/aws-f2
chmod +x *.sh
./00_full_deploy.sh
```

### Option 2: Step by step
```bash
cd deploy/aws-f2
chmod +x *.sh

# 1. Launch instance
./01_launch_f2.sh

# 2. Setup
./02_setup_fpga.sh

# 3. Build AFI (takes time!)
./03_build_afi.sh

# 4. Testing
./04_test_trinity.sh

# 5. MUST TURN OFF!
./05_stop_instance.sh
```

---

## COST

| Stage | Time | Cost |
|-------|------|------|
| Launch + setup | 15 min | $0.41 |
| Build AFI | 90 min | $2.48 |
| Testing | 15 min | $0.41 |
| S3 storage | - | $0.50 |
| **TOTAL** | **~2 hours** | **~$4-5** |

---

## IMPORTANT

1. **F2 Limit** - request IN ADVANCE (24-48h wait)
2. **TURN OFF INSTANCE** - $1.65/hour if you forget!
3. **Region us-east-1** - cheapest for F2

---

## WHAT WE TEST

| Test | Expected Result |
|------|-----------------|
| Golden Identity | φ² + 1/φ² = 3.0000000000 |
| PAS Daemons | 578.8x vs Binary |
| Berry Phase | 0.11423 mod 2π |
| SU(3) Core | Stable operation |

---

## STRUCTURE

```
deploy/aws-f2/
├── 00_full_deploy.sh      # Full auto-deploy
├── 01_launch_f2.sh        # Launch instance
├── 02_setup_fpga.sh       # Setup SDK
├── 03_build_afi.sh        # Build AFI
├── 04_test_trinity.sh     # Testing
├── 05_stop_instance.sh    # Stop
└── README.md              # This documentation
```

---

**φ² + 1/φ² = 3 | TRINITY READY FOR DEPLOY!**
