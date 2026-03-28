# Twitter/X Outreach List — 2026-03-28

## 🔴 Priority: Direct DM (Scientists)

### Golden Ratio Allies
| @handle | Name | DM Message |
|---------|------|------------|
| @fchollet | François Chollet | Parallel discovery: ARC tasks via HDC binding/bundling |
| @garymarcus | Gary Marcus | Neurosymbolic on $30 FPGA — ternary VSA approach |
| @ylecun | Yann LeCun | Ternary computing {-1,0,+1} vs binary efficiency |
| @goodfellow_ian | Ian Goodfellow | Ternary GANs potential |
| @hardmaru | Yoshua Bengio | VSA for cognitive computing |
| @AndrewYNg | Andrew Ng | Energy-efficient AI: 3000× less power |

### VSA / HDC Community
| @handle | Name | DM Message |
|---------|------|------------|
| @DenisKleyko | Denis Kleyko | VSA in Zig + FPGA — seeking review |
| @rossgayler | Ross Gayler | VSA operations with φ²+φ⁻²=3 foundation |
| @KanervaPentti | Pentti Kanerva | Ternary VSA extension of binary spatter codes |

### Physics / Constants
| @handle | Name | DM Message |
|---------|------|------------|
| @skdh | Sabine Hossenfelder | FAILURES FIRST: γ≠φ⁻³ rejected (DELTA-001 documented) |
| @LeeSmolin | Lee Smolin | G from φ (0.09%) + DELTA-001 failure |
| @carlorovelli | Carlo Rovelli | t_present = φ⁻² ≈ 382ms psychophysics |
| @NF_AFShordi | Niayesh Afshordi | Ω_Λ = γ⁸π⁴/φ² → 0.688 confirmed |

### FPGA / Hardware
| @handle | Name | DM Message |
|---------|------|------------|
| @tomverbeure | Tom Verbeure (Xilinx) | Zero-DSP FPGA synthesis |
| @rgb_views | Ron G. Minnich (RISC-V) | Ternary RISC-V potential |
| @cliffordwolf | Clifford Wolf (Yosys) | Open source FPGA toolchain |

### Zig Language
| @handle | Name | DM Message |
|---------|------|------------|
| @andrewrk | Andrew Kelley | 50+ binaries from one build.zig |
| @zig_language | Zig Official | Trinity showcase submission |

## 🟡 Priority: Follow + Engage

### AI Researchers to Follow
@karpathy, @fchollet, @ylecun, @hardmaru, @goodfellow_ian, @AndrewYNg
@garymarcus, @sirajraval, @j2kun, @ericjang11, @ch402

### Physics to Follow
@skdh, @LeeSmolin, @carlorovelli, @seancarroll, @phyliciawebsite
@Einsteiniumetc, @PhysicsStories, @QuantaMagazine

### FPGA/Hardware to Follow
@tomverbeure, @cliffordwolf, @riscis_open, @openfpga, @fpga_dev
@XilinxInc, @AMD_FPGA, @LatticeSemi

### VSA/HDC to Follow
@DenisKleyko, @rossgayler, @KanervaPentti, @hypervector
@VectorSymbolic, @HDComputing

### Zig to Follow
@andrewrk, @zig_language, @zig_showcase, @ZigSoftware
@Snektron, @dimussion, @tronical

## 📋 DM Templates

### Template 1: Chollet (ARC via VSA)
```
Hey François, love the ARC Prize work!

Quick Q: Have you explored VSA (Vector Symbolic Architecture)
for ARC tasks? bind/unbind/bundle operations might handle
the abstraction reasoning you're looking for.

I implemented VSA in pure Zig with FPGA backend:
- 63 tok/s @ 1W on $30 XC7A100T
- Zero DSP usage
- O(n) operations verified

Math foundation: φ² + φ⁻² = 3 (golden ratio identity)

Demo: github.com/gHashTag/trinity
DOI: 10.5281/zenodo.19227877

Think VSA could be interesting for ARC-AGI?
```

### Template 2: LeCun (Ternary Efficiency)
```
Yann — been following JEPA/energy efficiency work.

Quick insight: Ternary {-1,0,+1} gives:
- 20× memory savings vs float32
- 3000× less power
- 1.58 bits/trit information density

Math justification: φ² + φ⁻² = 3

I have this running on $30 FPGA (63 tok/s @ 1W, zero DSP).

Code: github.com/gHashTag/trinity

Is ternary worth a closer look for energy-efficient AI?
```

### Template 3: Hossenfelder (Failures First)
```
Sabine — big fan of "Lost in Math" perspective.

I'm working on φ²+φ⁻²=3 framework and I want to show you
my REJECTED predictions first:

❌ γ = φ⁻³ for Barbero-Immirzi → 0.617% error (rejected)
❌ α family fit → failed

✅ G = π³γ²/φ → 0.09% error (survived)
✅ Ω_Λ = γ⁸π⁴/φ² → 0.688 (Planck confirmed)

All failures documented in DELTA-001.

Am I fooling myself? Your perspective would be invaluable.

Code: src/tri/math/constants.zig
DOI: 10.5281/zenodo.19227877
```

## 🔧 Twitter Strategy

### Daily Pattern (Mon-Fri)
- **9 AM PST**: Follow 5-10 new people from target lists
- **11 AM PST**: Reply to relevant tweets (add value, not self-promo)
- **2 PM PST**: Quote retweet interesting content with insights
- **5 PM PST**: DM 1-2 high-priority targets with personalized message

### Reply Strategy
- Don't just say "interesting!"
- Add technical insight or question
- Reference their work specifically
- Keep under 280 chars (no threads for replies)

### Example Good Reply
```
@fchollet This ARC task is fascinating! Have you considered
VSA bind/unbind operations for the transformation abstraction?
I've been experimenting with φ²+φ⁻²=3 as a ternary foundation
and seeing interesting pattern composition results.
```

## 📊 Tracking

Create `outreach/twitter_tracker.csv`:
```csv
handle,action,date,response,follow_up
@fchollet,DM sent,2026-03-29,,
@ylecun,Follow,2026-03-29,,
@skdh,DM sent,2026-03-29,,
```

## ✅ Tomorrow's Email Priority

1. **Pentti Kanerva** — `pkanerva@csli.stanford.edu` (corrected)
2. **Michael Sherbon** — `michael.sherbon@case.edu`
3. **Stergios Pellis** — `sterpellis@gmail.com`
4. **Denis Kleyko** — `denis.kleyko@oru.se`
5. **Sabine Hossenfelder** — `sabine@mediamobilize.com`
6. **Lee Smolin** — `lsmolin@perimeterinstitute.ca`
7. **Carlo Rovelli** — `rovelli.carlo@gmail.com`
8. **Jan Rabaey** — `jan_rabaey@berkeley.edu`
9. **Abbas Rahimi** — `abr@zurich.ibm.com`

Skip Chollet (use Twitter DM instead).

---

**φ² + 1/φ² = 3 | TRINITY**
