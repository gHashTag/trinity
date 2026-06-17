//! VSA wrapper — resolves vm.zig imports to vsa.zig
pub const vsa = @import("vsa_core/root.zig");
pub use vsa.*;
