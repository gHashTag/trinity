//! tri/signal_handler — Signal handling
//! TTT Dogfood v0.2 Stage 270

const std = @import("std");

pub const SignalHandler = struct {
    handler: *const fn (i32) void,

    pub fn init(handler: *const fn (i32) void) SignalHandler {
        return .{ .handler = handler };
    }

    pub fn register(sh: *SignalHandler, sig: i32) !void {
        _ = sh;
        _ = sig;
    }
};

fn dummyHandler(sig: i32) void {
    _ = sig;
}

test "signal handler" {
    var sh = SignalHandler.init(dummyHandler);
    try sh.register(1);
}
