//! tri/list — Immutable linked list
//! Auto-generated from specs/tri/tri_list.tri
//! TTT Dogfood v0.2 Stage 72

const std = @import("std");

/// Immutable linked list node
pub fn List(comptime T: type) type {
    return struct {
        is_empty: bool,
        head_val: T,
        tail_ptr: ?*const List(T),

        const Self = @This();

        /// Create empty list
        pub fn empty() Self {
            return .{ .is_empty = true, .head_val = undefined, .tail_ptr = null };
        }

        /// Prepend element to list
        pub fn cons(head_val: T, tail_ptr: *const Self) Self {
            return .{ .is_empty = false, .head_val = head_val, .tail_ptr = tail_ptr };
        }

        /// Get first element
        pub fn head(self: Self) ?T {
            if (self.is_empty) return null;
            return self.head_val;
        }

        /// Get rest of list
        pub fn tail(self: Self) ?*const Self {
            if (self.is_empty) return null;
            return self.tail_ptr;
        }

        /// Get length
        pub fn len(self: Self) usize {
            if (self.is_empty) return 0;
            const tail_ptr = self.tail_ptr orelse return 1;
            return 1 + tail_ptr.len();
        }

        /// Transform each element
        pub fn map(self: Self, comptime U: type, mapper: *const fn (T) U, allocator: std.mem.Allocator) !List(U) {
            if (self.is_empty) return List(U).empty();

            const new_head = mapper(self.head_val);
            const tail_ptr = self.tail_ptr orelse return List(U).cons(new_head, try allocator.create(List(U)));

            var mapped_tail = try tail_ptr.map(U, mapper, allocator);
            const node = try allocator.create(List(U));
            node.* = List(U).cons(new_head, &mapped_tail);
            return node.*;
        }

        /// Keep matching elements
        pub fn filter(self: Self, pred: *const fn (T) bool, allocator: std.mem.Allocator) !Self {
            if (self.is_empty) return self;

            if (pred(self.head_val)) {
                const tail_ptr = self.tail_ptr orelse {
                    return List(T).cons(self.head_val, try allocator.create(Self));
                };
                const filtered_tail = try tail_ptr.filter(pred, allocator);
                const node = try allocator.create(Self);
                node.* = List(T).cons(self.head_val, &filtered_tail);
                return node.*;
            } else {
                const tail_ptr = self.tail_ptr orelse return List(T).empty();
                return tail_ptr.filter(pred, allocator);
            }
        }

        /// Reduce list to single value
        pub fn fold(self: Self, comptime U: type, init_val: U, folder: *const fn (U, T) U) U {
            if (self.is_empty) return init_val;

            const acc = folder(init_val, self.head_val);
            const tail_ptr = self.tail_ptr orelse return acc;
            return tail_ptr.fold(U, acc, folder);
        }

        /// Check if element exists
        pub fn contains(self: Self, val: T) bool {
            if (self.is_empty) return false;
            if (std.meta.eql(val, self.head_val)) return true;
            const tail_ptr = self.tail_ptr orelse return false;
            return tail_ptr.contains(val);
        }
    };
}

test "List.empty" {
    const list = List(i32).empty();
    try std.testing.expect(list.is_empty);
    try std.testing.expectEqual(@as(usize, 0), list.len());
}

test "List.cons" {
    const empty = List(i32).empty();
    const single = List(i32).cons(1, &empty);
    try std.testing.expect(!single.is_empty);
    try std.testing.expectEqual(@as(i32, 1), single.head().?);
    try std.testing.expectEqual(@as(usize, 1), single.len());
}

test "List.cons multiple" {
    const empty = List(i32).empty();
    const node1 = List(i32).cons(1, &empty);
    const node2 = List(i32).cons(2, &node1);
    try std.testing.expectEqual(@as(usize, 2), node2.len());
    try std.testing.expectEqual(@as(i32, 2), node2.head().?);
}

test "List.fold" {
    const empty = List(i32).empty();
    const node1 = List(i32).cons(1, &empty);
    const node2 = List(i32).cons(2, &node1);
    const node3 = List(i32).cons(3, &node2);

    const sum = node3.fold(i32, 0, struct {
        fn add(acc: i32, x: i32) i32 {
            return acc + x;
        }
    }.add);

    try std.testing.expectEqual(@as(i32, 6), sum);
}

test "List.contains" {
    const empty = List(i32).empty();
    const node1 = List(i32).cons(1, &empty);
    const node2 = List(i32).cons(2, &node1);
    const node3 = List(i32).cons(3, &node2);

    try std.testing.expect(node3.contains(2));
    try std.testing.expect(!node3.contains(99));
}

test "List.map" {
    const empty = List(i32).empty();
    const node1 = List(i32).cons(1, &empty);
    const node2 = List(i32).cons(2, &node1);

    const mapped = try node2.map(i32, struct {
        fn double(x: i32) i32 {
            return x * 2;
        }
    }.double, std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), mapped.len());
}
