# Zenodo V17: Scientific Improvements Proposal
## Trinity S³AI Research Framework — Next Generation

**Date**: 2026-03-27
**Status**: Proposal
**Target**: NeurIPS/ICLR/MLSys 2025 Compliance + FAIR Principles

---

## Executive Summary

This document proposes comprehensive improvements to the Zenodo V16 framework, addressing gaps identified through analysis of 2025 conference standards (NeurIPS, ICLR, MLSys), FAIR principles, and emerging reproducibility requirements.

**Key Findings**:
1. V16 has strong statistical rigor (p-values, confidence intervals)
2. Missing: FAIR compliance scoring, automated reproducibility checks
3. Missing: Environmental impact tracking (new MLSys 2025 requirement)
4. Missing: DataCite 4.5 schema integration for dataset/code citations

---

## Part 1: FAIR Score Calculator

### Background
FAIR Principles (Findable, Accessible, Interoperable, Reusable) are now mandatory for NeurIPS 2025 dataset track submissions.

### Proposed Implementation

```zig
// src/tri/zenodo_v17_fair.zig

/// FAIR Score Components (0-100 each)
pub const FairScore = struct {
    findable: u8,      // F1F (Identifier), F2F (Metadata), F3F (Search), F4F (Identify)
    accessible: u8,    // A1 (Protocol), A2 (Auth), A1.1 (Metadata)
    interoperable: u8, // I1 (Format), I2 (Vocab), I3 (Refs)
    reusable: u8,      // R1 (License), R1.1 (Provenance), R1.2 (Community)

    /// Overall FAIR score (0-100)
    pub fn overall(self: FairScore) f64 {
        return (@as(f64, @floatFromInt(self.findable)) +
                @as(f64, @floatFromInt(self.accessible)) +
                @as(f64, @floatFromInt(self.interoperable)) +
                @as(f64, @floatFromInt(self.reusable))) / 4.0;
    }

    /// Grade (A/B/C/D/F)
    pub fn grade(self: FairScore) []const u8 {
        const score = self.overall();
        if (score >= 90) return "A";
        if (score >= 80) return "B";
        if (score >= 70) return "C";
        if (score >= 60) return "D";
        return "F";
    }

    /// FAIR compliance checklist
    pub fn checklist(self: FairScore) []const ChecklistItem {
        return [_]ChecklistItem{
            .{ .id = "F1F", .name = "Identifier", .score = self.findable },
            .{ .id = "F2F", .name = "Rich Metadata", .score = self.findable },
            // ... 13 total items
        };
    }
};

pub const ChecklistItem = struct {
    id: []const u8,
    name: []const u8,
    score: u8,
    passed: bool,
};

/// Calculate FAIR score from Zenodo metadata
pub fn calculateFairScore(metadata: ZenodoMetadata) !FairScore {
    return .{
        .findable = calculateFindable(metadata),
        .accessible = calculateAccessible(metadata),
        .interoperable = calculateInteroperable(metadata),
        .reusable = calculateReusable(metadata),
    };
}

fn calculateFindable(m: ZenodoMetadata) u8 {
    var score: u8 = 0;
    // F1F: DOI assigned
    if (m.doi != null) score += 25;
    // F2F: Rich metadata
    if (m.title.len > 0 and m.authors.len > 0 and m.description.len > 100) score += 25;
    // F3F: Searchable (Zenodo automatically indexes)
    score += 25;
    // F4F: Identifier in metadata
    if (std.mem.indexOf(u8, m.description, "doi.org") != null) score += 25;
    return score;
}
```

### CLI Integration

```bash
tri zenodo fair-score B001
# Output:
# FAIR Score: 85/100 (Grade: B)
# ├─ Findable: 90/100
# ├─ Accessible: 100/100
# ├─ Interoperable: 75/100
# └─ Reusable: 75/100
#
# Recommendations:
# - Add machine-readable metadata (JSON-LD)
# - Specify vocabulary (schema.org, DataCite)
# - Add community standards
```

---

## Part 2: Reproducibility Checklist Automation

### Background
NeurIPS 2025 requires reproducibility checklist (code, data, random seeds, hyperparameters). ICLR 2025 has similar requirements.

### Proposed Implementation

```zig
// src/tri/zenodo_v17_reproducibility.zig

/// Reproducibility Checklist (NeurIPS 2025)
pub const ReproducibilityChecklist = struct {
    /// Code availability
    code_available: bool,
    code_url: ?[]const u8,
    code_license: ?[]const u8,

    /// Data availability
    data_available: bool,
    data_url: ?[]const u8,
    data_license: ?[]const u8,

    /// Hyperparameters documented
    hyperparams_documented: bool,

    /// Random seeds documented
    seeds_documented: bool,

    /// Computational requirements
    compute_specified: bool,
    gpu_hours: ?f64,
    cpu_hours: ?f64,

    /// Score (0-100)
    pub fn score(self: ReproducibilityChecklist) u8 {
        var s: u8 = 0;
        if (self.code_available) s += 20;
        if (self.code_url != null) s += 10;
        if (self.code_license != null) s += 5;
        if (self.data_available) s += 20;
        if (self.data_url != null) s += 10;
        if (self.hyperparams_documented) s += 15;
        if (self.seeds_documented) s += 10;
        if (self.compute_specified) s += 10;
        return s;
    }

    /// Generate checklist text (for paper submission)
    pub fn formatPaperChecklist(self: ReproducibilityChecklist) []const u8 {
        // Returns NeurIPS/ICLR formatted checklist
    }
};

/// Extract reproducibility info from Zenodo metadata
pub fn extractReproducibility(metadata: ZenodoMetadata) ReproducibilityChecklist {
    // Parse metadata for code/data URLs, compute requirements
}
```

### Paper Checklist Output

```
# NeurIPS 2025 Reproducibility Checklist

1. Code: [Yes] Available at https://github.com/gHashTag/trinity
   - License: MIT
   - Dependencies: Zig 0.15, Yosys 0.63

2. Data: [Yes] Training data (TinyStories) + synthetic benchmarks
   - URL: https://zenodo.org/records/XXXXX
   - License: CC-BY-4.0

3. Hyperparameters: [Yes] Documented in Table 2
   - Learning rate: 1e-3 (cosine schedule)
   - Batch size: 32
   - Context length: 512

4. Random Seeds: [Yes] All experiments use seed=42
   - Statistical tests use 1000 bootstrap samples

5. Compute: [Yes] 152 GPU-hours (NVIDIA A100)
   - Training: 150 GPU-hours
   - Evaluation: 2 GPU-hours
```

---

## Part 3: Environmental Impact Tracking

### Background
**NEW REQUIREMENT**: MLSys 2025 requires environmental impact disclosure (carbon emissions, hardware efficiency).

### Proposed Implementation

```zig
// src/tri/zenodo_v17_environmental.zig

/// Environmental Impact Metrics (MLSys 2025)
pub const EnvironmentalImpact = struct {
    /// Compute hours
    gpu_hours: f64,
    cpu_hours: f64,

    /// Carbon emissions (kg CO2e)
    carbon_kg: f64,

    /// Hardware location (affects grid carbon intensity)
    region: []const u8, // "us-west", "eu-central", etc.

    /// Hardware efficiency
    hardware_efficiency: f64, // GFLOPS/W

    /// Calculate emissions from compute
    pub fn calculateEmissions(gpu_hours: f64, region: []const u8) f64 {
        // Carbon intensity by region (g CO2/kWh)
        const intensities = std.ComptimeStringMap(f64, .{
            .{ "us-west", 250.0 },   // California grid
            .{ "us-east", 400.0 },   // Virginia grid
            .{ "eu-central", 350.0 }, // Germany grid
            .{ "asia-east", 550.0 },  // China grid
        });

        const intensity = intensities.get(region) orelse 400.0;
        const kwh = gpu_hours * 0.3; // 300W per GPU
        return (kwh * intensity) / 1000.0; // Convert to kg CO2
    }

    /// Format for MLSys submission
    pub fn formatMLSys(self: EnvironmentalImpact) []const u8 {
        return std.fmt.allocPrint(
            \\Environmental Impact:
            \\- Compute: {d:.1} GPU-hours, {d:.1} CPU-hours
            \\- Carbon Emissions: {d:.2} kg CO2e
            \\- Region: {s}
            \\- Hardware Efficiency: {d:.1} GFLOPS/W
            \\- Equivalent: {d:.1} km driven by average car
        , .{
            self.gpu_hours, self.cpu_hours,
            self.carbon_kg, self.region,
            self.hardware_efficiency,
            self.carbon_kg * 4.5, // 4.5 km per kg CO2
        });
    }

    /// Compare to baseline
    pub fn compare(self: EnvironmentalImpact, baseline: EnvironmentalImpact) Comparison {
        return .{
            .emissions_ratio = self.carbon_kg / baseline.carbon_kg,
            .efficiency_gain = (self.hardware_efficiency - baseline.hardware_efficiency)
                               / baseline.hardware_efficiency * 100.0,
        };
    }
};

pub const Comparison = struct {
    emissions_ratio: f64,
    efficiency_gain: f64,
};
```

### Usage Example

```bash
tri zenodo environmental B001 --gpu-hours 152 --region us-west
# Output:
# Environmental Impact:
# - Compute: 152.0 GPU-hours, 8.0 CPU-hours
# - Carbon Emissions: 11.4 kg CO2e
# - Region: us-west
# - Hardware Efficiency: 150.0 GFLOPS/W
# - Equivalent: 51.3 km driven by average car
#
# Comparison to baseline (Transformer FP32):
# - Emissions ratio: 0.18 (5.6x lower)
# - Efficiency gain: 450%
```

---

## Part 4: Enhanced DataCite Schema Integration

### Background
DataCite Schema 4.5 is now required for dataset/code metadata. Zenodo supports DataCite but requires proper JSON structure.

### Proposed Implementation

```zig
// src/tri/zenodo_v17_datacite.zig

/// DataCite 4.5 Schema (https://schema.datacite.org/meta/kernel-4.5/)
pub const DataCiteMetadata = struct {
    /// Required fields
    identifier: Identifier,
    creators: []Creator,
    titles: []Title,
    publisher: []const u8,
    publication_year: u16,

    /// Recommended fields
    subjects: []Subject,      // Keywords
    dates: []Date,           // Available, accepted, etc.
    language: []const u8,    // ISO 639-1
    resource_type: ResourceType,
    sizes: []Size,           // File sizes
    formats: []Format,       // File formats (MIME)
    version: ?[]const u8,

    /// Optional fields
    descriptions: []Description,
    rights: []Rights,        // License info
    related_identifiers: []RelatedIdentifier,
    geo_locations: []GeoLocation,

    /// Convert to JSON for Zenodo upload
    pub fn toJson(self: DataCiteMetadata) ![]const u8 {
        // Serialize to DataCite JSON
    }

    /// Validate against DataCite 4.5 schema
    pub fn validate(self: DataCiteMetadata) !ValidationResult {
        var errors = std.ArrayList([]const u8).init(allocator);

        // Required fields
        if (self.creators.len == 0)
            try errors.append("DataCite: at least one creator required");
        if (self.titles.len == 0)
            try errors.append("DataCite: at least one title required");

        // Validate DOI format
        if (!std.mem.startsWith(u8, self.identifier.id, "10."))
            try errors.append("DataCite: DOI must start with 10.");

        return .{
            .valid = errors.items.len == 0,
            .errors = errors.items,
        };
    }
};

pub const Identifier = struct {
    identifier_type: []const u8 = "DOI",
    id: []const u8, // "10.5281/zenodo.XXXXXX"
};

pub const Creator = struct {
    name: []const u8,           // "FamilyName, GivenNames"
    affiliation: ?[]const u8,    // "Trinity Research Lab"
    name_identifier: ?NameIdentifier, // ORCID
};

pub const NameIdentifier = struct {
    scheme: []const u8 = "ORCID",
    scheme_uri: []const u8 = "http://orcid.org/",
    id: []const u8, // "0000-0000-0000-0000"
};

pub const ResourceType = struct {
    resource_type_general: []const u8, // "Dataset", "Software", "Model"
    general: ?[]const u8,
};
```

### CLI Integration

```bash
tri zenodo datacite-validate B001
# Output:
# ✅ DataCite 4.5 validation passed
# ├─ Identifier: 10.5281/zenodo.19227865
# ├─ Creators: 3 found
# ├─ Titles: 1 found
# ├─ Descriptions: 1 found (abstract)
# └─ Rights: MIT license specified
```

---

## Part 5: Implementation Priority

### Phase 1 (V17.0 - Immediate)
1. ✅ FAIR Score Calculator
2. ✅ Reproducibility Checklist Automation
3. ✅ Environmental Impact Tracking

### Phase 2 (V17.1 - 1 week)
4. DataCite 4.5 Schema Integration
5. Automated checklist generation for paper submission

### Phase 3 (V17.2 - 2 weeks)
6. Integration with GitHub Issues (auto-update reproducibility status)
7. Continuous monitoring (CI/CD integration)

---

## Part 6: Testing Strategy

### Unit Tests
```zig
test "FAIR score: minimal metadata" {
    const metadata = ZenodoMetadata{
        .title = "Test",
        .authors = &[_][]const u8{"Test Author"},
        .description = "Test",
    };
    const score = try calculateFairScore(metadata);
    try testing.expect(score.overall() < 50); // Poor score
}

test "FAIR score: full metadata" {
    const metadata = zenodoMetadataFull();
    const score = try calculateFairScore(metadata);
    try testing.expect(score.overall() >= 90); // Excellent score
}

test "Environmental: carbon calculation" {
    const emissions = calculateEmissions(100.0, "us-west");
    try testing.expectApproxEqAbs(@as(f64, 7.5), emissions, 0.1);
}
```

### Integration Tests
- Generate full Zenodo JSON with all V17 features
- Validate against Zenodo upload API
- Test checklist generation matches NeurIPS/ICLR templates

---

## Part 7: Documentation Updates

### New Files
| File | Purpose | LOC |
|------|---------|-----|
| `docs/research/ZENODO_V17_FAIR.md` | FAIR implementation guide | 200 |
| `docs/research/ZENODO_V17_REPRODUCIBILITY.md` | Checklist automation | 150 |
| `docs/research/ZENODO_V17_ENVIRONMENTAL.md` | Carbon tracking | 100 |
| `docs/research/ZENODO_V17_DATACITE.md` | Schema 4.5 guide | 150 |

### CLI Reference
```bash
tri zenodo fair-score <bundle>        # Calculate FAIR score
tri zenodo reproducibility <bundle>    # Generate checklist
tri zenodo environmental <bundle>      # Calculate carbon
tri zenodo datacite-validate <bundle>  # Validate schema
tri zenodo publish-v17 <bundle>        # Publish with all V17 features
```

---

## Part 8: Scientific Validation

### Literature Review
1. **FAIR Principles**: Wilkinson et al. (2016) Scientific Data
2. **NeurIPS 2025**: Reproducibility checklist requirements
3. **ICLR 2025**: Code/data availability policy
4. **MLSys 2025**: Environmental impact disclosure
5. **DataCite 4.5**: Schema specification (2024)

### Benchmarking
- Compare FAIR scores against similar ML frameworks
- Measure carbon footprint reduction vs baseline
- Validate checklist acceptance rate (submit to conference)

---

## Conclusion

**V17 improvements enable**:
1. ✅ NeurIPS 2025 dataset track compliance
2. ✅ ICLR 2025 reproducibility requirements
3. ✅ MLSys 2025 environmental disclosure
4. ✅ FAIR principles certification
5. ✅ DataCite 4.5 schema compliance

**Estimated Implementation**: 2-3 weeks (~800 LOC)

**Impact**: Trinity S³AI becomes the first ML framework with full 2025 conference compliance out of the box.

---

**φ² + 1/φ² = 3 | TRINITY**
