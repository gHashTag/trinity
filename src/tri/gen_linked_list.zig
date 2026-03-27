//! tri/linked_list — Doubly linked list
//! Auto-generated from specs/tri/tri_linked_list.tri
//! TTT Dogfood v0.2 Stage 181

const std = @import("std");

/// List node
pub const ListNode = struct {
    value: i64,
    prev: ?*ListNode,
    next: ?*ListNode,
};

/// Doubly linked list
pub const LinkedList = struct {
    head: ?*ListNode,
    tail: ?*ListNode,
    length: usize,
    allocator: std.mem.Allocator,

    /// Create empty list
    pub fn init(allocator: std.mem.Allocator) LinkedList {
        return .{
            .head = null,
            .tail = null,
            .length = 0,
            .allocator = allocator,
        };
    }

    /// Add value to end
    pub fn append(list: *LinkedList, value: i64) !void {
        const node = try list.allocator.create(ListNode);
        node.* = .{
            .value = value,
            .prev = list.tail,
            .next = null,
        };

        if (list.tail) |tail| {
            tail.next = node;
        } else {
            list.head = node;
        }
        list.tail = node;
        list.length += 1;
    }

    /// Add value to front
    pub fn prepend(list: *LinkedList, value: i64) !void {
        const node = try list.allocator.create(ListNode);
        node.* = .{
            .value = value,
            .prev = null,
            .next = list.head,
        };

        if (list.head) |head| {
            head.prev = node;
        } else {
            list.tail = node;
        }
        list.head = node;
        list.length += 1;
    }

    /// Remove first occurrence
    pub fn remove(list: *LinkedList, value: i64) bool {
        var current = list.head;

        while (current) |node| {
            if (node.value == value) {
                if (node.prev) |prev| {
                    prev.next = node.next;
                } else {
                    list.head = node.next;
                }

                if (node.next) |next| {
                    next.prev = node.prev;
                } else {
                    list.tail = node.prev;
                }

                list.allocator.destroy(node);
                list.length -= 1;
                return true;
            }
            current = node.next;
        }

        return false;
    }

    /// Free all nodes
    pub fn deinit(list: *LinkedList) void {
        var current = list.head;
        while (current) |node| {
            current = node.next;
            list.allocator.destroy(node);
        }
    }
};

test "linked list append" {
    var list = LinkedList.init(std.testing.allocator);
    defer list.deinit();

    try list.append(1);
    try list.append(2);
    try list.append(3);

    try std.testing.expectEqual(@as(usize, 3), list.length);
    if (list.head) |h| {
        try std.testing.expectEqual(@as(i64, 1), h.value);
    }
}

test "linked list prepend" {
    var list = LinkedList.init(std.testing.allocator);
    defer list.deinit();

    try list.prepend(3);
    try list.prepend(2);
    try list.prepend(1);

    if (list.head) |h| {
        try std.testing.expectEqual(@as(i64, 1), h.value);
    }
}

test "linked list remove" {
    var list = LinkedList.init(std.testing.allocator);
    defer list.deinit();

    try list.append(1);
    try list.append(2);
    try list.append(3);

    try std.testing.expect(list.remove(2));
    try std.testing.expect(!list.remove(99));
    try std.testing.expectEqual(@as(usize, 2), list.length);
}
