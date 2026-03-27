//! tri/async — Future and promise selector

const generated = @import("gen_async.zig");
pub const Future = generated.Future;
pub const Promise = generated.Promise;
pub const await = generated.await;
