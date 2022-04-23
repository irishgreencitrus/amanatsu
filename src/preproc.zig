const std = @import("std");
const path = std.fs.path;
const lexer = @import("lexer.zig");
const parser = @import("parser.zig");
const errors = @import("errors.zig");
pub const ProcessDetails = struct { included_files: [][]const u8 };

pub fn process(
    alloc: std.mem.Allocator,
    tokens: []const lexer.Token,
    raw_data: []const u8,
    filename: []const u8,
    included_files: *std.ArrayList([]const u8),
    completed_tokens: *std.ArrayList(parser.Token),
) anyerror![]parser.Token {
    const containing_dir_path = path.dirname(filename);
    var containing_dir = std.fs.cwd();
    if (containing_dir_path) |dir| {
        containing_dir = try containing_dir.openDir(dir, .{});
    }
    var last_token: lexer.Token = undefined;
    for (tokens) |t| {
        try process_token(
            t,
            last_token,
            raw_data,
            alloc,
            included_files,
            completed_tokens,
            containing_dir,
            // containing_dir_path,
        ) catch |err| switch (err) {
            error.FileNotFound => errors.executor_panic("Unable to preproc file due to preproc @use statement not finding file. Try checking the spelling. File failed on: ", filename),
            else => err,
        };
        last_token = t;
    }
    try completed_tokens.appendSlice(try parser.parseTokens(alloc, tokens, raw_data));
    try completed_tokens.append(parser.Token{ .start = 0, .id = .Eof, .data = .{ .single_token = 0 } });
    return completed_tokens.toOwnedSlice();
}
fn process_token(
    token: lexer.Token,
    last_token: lexer.Token,
    raw_data: []const u8,
    alloc: std.mem.Allocator,
    included_files: *std.ArrayList([]const u8),
    completed_tokens: *std.ArrayList(parser.Token),
    src_directory: std.fs.Dir,
    // src_directory_path: []const u8,
) anyerror!void {
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

            var buffer = try alloc.create([8192]u8);

            var source = try src_directory.openFile(to_import, .{}) catch |err| switch (err) {
                error.FileNotFound => errors.executor_panic("Unable to find file", to_import),
                else => err,
            };
            defer source.close();

            var bytes_read = try source.readAll(buffer);
            var complete_src = buffer[0..bytes_read];
            var lexed_tokens = try lexer.tokenize(alloc, complete_src);
            const file_contains_preproc = contains_preproc(lexed_tokens);
            if (file_contains_preproc) {
                var last_token_nested: lexer.Token = undefined;
                var relative_dir_path = path.dirname(to_import);
                var relative_dir = src_directory;
                if (relative_dir_path) |relative_dir_path_exist| {
                    relative_dir = try src_directory.openDir(relative_dir_path_exist, .{});
                }
                for (lexed_tokens) |t| {
                    try process_token(
                        t,
                        last_token_nested,
                        complete_src,
                        alloc,
                        included_files,
                        completed_tokens,
                        relative_dir,
                    );
                    last_token_nested = t;
                }
            }

            var parsed_tokens = try parser.parseTokens(alloc, lexed_tokens, complete_src);
            try included_files.*.append(to_import);
            try completed_tokens.*.appendSlice(parsed_tokens);
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
