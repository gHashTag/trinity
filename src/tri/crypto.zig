//! TRI Crypto Module Selector
//! φ² + 1/φ² = 3 | TRINITY

pub const HashResult = @import("gen_crypto.zig").HashResult;
pub const Base64Error = @import("gen_crypto.zig").Base64Error;

pub const simpleHash = @import("gen_crypto.zig").simpleHash;
pub const sha256 = @import("gen_crypto.zig").sha256;
pub const xorBytes = @import("gen_crypto.zig").xorBytes;
pub const xorRepeat = @import("gen_crypto.zig").xorRepeat;
pub const base64Encode = @import("gen_crypto.zig").base64Encode;
pub const base64Decode = @import("gen_crypto.zig").base64Decode;
