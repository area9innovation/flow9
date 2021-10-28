const std = @import("std");

const Allocator = std.mem.Allocator;

pub fn i2s(allocator: *Allocator, i : i32) !std.ArrayList(u8) {
    var list = std.ArrayList(u8).init(allocator);
    try list.writer().print("{d}", .{i});
    return list;
}

pub fn main() !void {
    var memory: [2 * 1024 * 1024]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(&memory).allocator;

    const i : i32 = 1;
    const number = try i2s(allocator, i);

    const stdout = std.io.getStdOut().writer();
    try stdout.print("{s}", .{number.items});
    return;
}
