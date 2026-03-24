const std = @import("std");

pub const Foo = struct {
    x: usize,

    pub fn bar(self: *const Foo) void {
        _ = self;
    }
};

test "minimal" {
    const foo = Foo{ .x = 42 };
    foo.bar();
}
