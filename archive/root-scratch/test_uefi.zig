const std = @import("std");
const uefi = @import("uefi");

pub fn main() !void {
    const stdout = std.io.getStdErr();
    
    stdout.print("Testing UEFI SerialIo on macOS native...\n") catch {};
    
    const serial = uefi.SerialIo.open("/dev/null") catch |err| {
        stdout.print("Result: {any}\n", .{err}) catch {};
        return;
    };
    
    stdout.print("Done\n") catch {};
}
