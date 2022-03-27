const std = @import("std");
const lexer = @import("lexer.zig");
const data_types = @import("data_types.zig");
const UsedNumberType = data_types.UsedNumberType;

pub const Token = struct { id: lexer.Token.Id, start: u32, data: union {
    text: []const u8,
    number: UsedNumberType,
    single_token: u0,
} };

pub fn parseTokens(
    alloc: std.mem.Allocator,
    tokens: []const lexer.Token,
    raw_data: []const u8,
) ![]const Token {
    var new_token_list = try std.ArrayList(Token).initCapacity(alloc, raw_data.len / 8);
    defer new_token_list.deinit();
    var last_token: lexer.Token = undefined;
    for (tokens) |tok| {
        switch (tok.id) {
            .Comment, .Eof => {},
            .PreProcUse => {},
            .String => {
                if (last_token.id != .PreProcUse) {
                    try new_token_list.append(Token{
                        .id = tok.id,
                        .start = tok.start,
                        .data = .{ .text = raw_data[tok.start + 1 .. tok.end - 1] },
                    });
                }
            },
            .Atom => {
                if (last_token.id != .PreProcUse) {
                    try new_token_list.append(Token{
                        .id = tok.id,
                        .start = tok.start,
                        .data = .{ .text = raw_data[tok.start + 1 .. tok.end] },
                    });
                }
            },
            .Number => {
                try new_token_list.append(Token{
                    .id = tok.id,
                    .start = tok.start,
                    .data = .{ .number = std.fmt.parseFloat(UsedNumberType, raw_data[tok.start..tok.end]) catch unreachable },
                });
            },
            .Function => {
                try new_token_list.append(Token{
                    .id = tok.id,
                    .start = tok.start,
                    .data = .{ .text = raw_data[tok.start..tok.end] },
                });
            },
            else => {
                try new_token_list.append(Token{
                    .id = tok.id,
                    .start = tok.start,
                    .data = .{ .single_token = 0 },
                });
            },
        }
        last_token = tok;
    }
    return new_token_list.toOwnedSlice();
}
