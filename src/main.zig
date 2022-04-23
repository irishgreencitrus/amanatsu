const lexer = @import("lexer.zig");
const preproc = @import("preproc.zig");
const cmdline = @import("cmdline.zig");
const executor = @import("executor.zig");
const parser = @import("parser.zig");
const std = @import("std");

pub const log_level: std.log.Level = .err;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    // const allocator = std.testing.allocator;
    // var log_gpa = std.heap.LoggingAllocator(std.log.Level.debug,std.log.Level.err){.parent_allocator = gpa_alloc};
    // const allocator = log_gpa.allocator();

    // var program_buffer: [655360]u8 = undefined;
    // var fba = std.heap.FixedBufferAllocator.init(&program_buffer);
    // const allocator = fba.allocator();

    var buffer: [8192]u8 = undefined;
    var flags = try cmdline.process(allocator);
    var source = try std.fs.cwd().openFile(flags.filename, .{});
    defer source.close();
    var bytes_read = try source.readAll(&buffer);
    var tokens = try lexer.tokenize(allocator, buffer[0..bytes_read]);

    var included_files = std.ArrayList([]const u8).init(allocator);
    var completed_tokens = std.ArrayList(parser.Token).init(allocator);
    defer included_files.deinit();
    defer completed_tokens.deinit();

    var final_tokens = try preproc.process(
        allocator,
        tokens,
        buffer[0..bytes_read],
        flags.filename,
        &included_files,
        &completed_tokens,
    );
    try executor.execute(allocator, final_tokens);
}
