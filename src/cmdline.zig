const std = @import("std");
const abort = @import("errors.zig");
pub const CommandFlags = struct {
    filename: []const u8,
};

pub fn process(alloc: std.mem.Allocator) !CommandFlags {
    var args_iter = try std.process.argsWithAllocator(alloc);
    _ = args_iter.skip(); // SKIP PROGRAM NAME
    var program = args_iter.next();
    if (program) |p| {
        return CommandFlags{.filename = p};
    } else {
        abort.panic("Add a program to run.");
    }
}
