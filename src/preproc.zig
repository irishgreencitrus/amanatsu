const std = @import("std");
const lexer = @import("lexer.zig");
const parser = @import("parser.zig");
const entry = @import("entrypoint.zig");
pub const ProcessDetails = struct { included_files: [][]const u8 };

pub fn process(
    alloc: std.mem.Allocator,
    tokens: []const lexer.Token,
    raw_data: []const u8,
    filename: []const u8,
    included_files: *std.ArrayList([]const u8),
    completed_tokens: *std.ArrayList(parser.Token),
) anyerror![]parser.Token {
    _ = filename;
    var last_token: lexer.Token = undefined;
    for (tokens) |t| {
        try process_token(
            t,
            last_token,
            raw_data,
            alloc,
            included_files,
            completed_tokens,
        );
        last_token = t;
    }
    try completed_tokens.appendSlice(try parser.parseTokens(alloc,tokens,raw_data));
    try completed_tokens.append(parser.Token{ .start = 0,.id = .Eof, .data = .{.single_token = 0} });
    return completed_tokens.toOwnedSlice(); }
fn process_token(
    token: lexer.Token,
    last_token: lexer.Token,
    raw_data: []const u8,
    alloc: std.mem.Allocator,
    included_files: *std.ArrayList([]const u8),
    completed_tokens: *std.ArrayList(parser.Token),
) anyerror!void {
    _ = completed_tokens;
    switch (token.id) {
        .Atom => if (last_token.id == .PreProcUse) {
            std.debug.print("PREPROC GLOBAL: {s}\n", .{raw_data[token.start..token.end]});
            @panic("Unimplemented.");
        },
        .String => if (last_token.id == .PreProcUse) {
            const to_import = raw_data[token.start + 1 .. token.end - 1];
            for (included_files.items) |f| {
                if (std.mem.eql(u8, f, to_import)) {
                    return;
                }
            }
            // std.debug.print("PREPROC LOCAL: {s}\n",.{raw_data[token.start+1..token.end-1]});
            var buffer: [8192]u8 = undefined;
            var source = try std.fs.cwd().openFile(to_import, .{});
            defer source.close();
            var bytes_read = try source.readAll(&buffer);
            var subtokens = try lexer.tokenize(alloc, buffer[0..bytes_read]);
            // for (subtokens) |t| {
            //     std.debug.print("TOKEN: {}\n", .{t.id});
            // }
            const file_contains_preproc = contains_preproc(subtokens);
            if (file_contains_preproc) {
                @panic("Nested Imports Unimplemented.");
            }
            try included_files.*.append(to_import);
            try completed_tokens.*.appendSlice(try parser.parseTokens(alloc,subtokens,buffer[0..bytes_read]));
        },
        else => {},
    }
}
fn contains_preproc(tokens: []const lexer.Token) bool {
    for (tokens) |t| {
        if (t.id == .PreProcUse) {
            return true;
        }
    }
    return false;
}
