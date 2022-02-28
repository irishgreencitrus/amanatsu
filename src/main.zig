const lexer = @import("lexer.zig");
const cmdline = @import("cmdline.zig");
const executor = @import("executor.zig");
const std = @import("std");
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var buffer : [8192]u8 = undefined;
    var flags = try cmdline.process(allocator);
    var source = try std.fs.cwd().openFile(flags.filename, .{});
    defer source.close();
    var bytes_read = try source.readAll(&buffer);

    var tokens = try lexer.tokenize(allocator, buffer[0..bytes_read]);
    try executor.execute(allocator, tokens, buffer[0..bytes_read]);
}
