// ═══════════════════════════════════════════════════════════════════════════════
// Content Registry (SOURCE OF TRUTH SELECTOR)
// ═══════════════════════════════════════════════════════════════════════════════
//
// TTT Dogfood v0.1: Flip this one line to switch between manual/generated
//
// Self-hosted ENABLED — using generated code from Tri spec:

// Import generated code and re-export all public symbols
const gen = @import("gen_content_registry.zig");

pub const FunctionLocation = gen.FunctionLocation;
pub const DuplicateInfo = gen.DuplicateInfo;
pub const ContentRegistry = gen.ContentRegistry;
pub const DEFAULT_REGISTRY_PATH = gen.DEFAULT_REGISTRY_PATH;
pub const loadFromFile = gen.loadFromFile;
pub const saveToFile = gen.saveToFile;
pub const parseFromJson = gen.parseFromJson;
pub const toJson = gen.toJson;

// Manual (disabled):
// const manual = @import("content_registry_manual.zig");
// pub const FunctionLocation = manual.FunctionLocation;
// ... etc
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════
