const std = @import("std");
const errors = @import("errors.zig");
const mem = std.mem;
const math = std.math;
const testing = std.testing;
const unicode = std.unicode;
const LexerErrors = error{TokenizerError};
pub fn isIdentifier(c: u32) bool {
    return switch (c) {
        'a'...'z',
        'A'...'Z',
        '_',
        '0'...'9',
        => true,
        else => false,
    };
}
fn isWhitespace(c: u32) bool {
    return switch (c) {
        '\n', ' ', '\t', '\r' => true,
        else => false,
    };
}
fn expectTokens(source: []const u8, expected_tokens: []const Token.Id) !void {
    var source_with_space = std.ArrayList(u8).init(std.testing.allocator);
    defer source_with_space.deinit();
    try source_with_space.appendSlice(source);
    try source_with_space.append('\n');
    var tokenizer = Tokenizer{ .tokens = undefined, .it = .{
        .i = 0,
        .bytes = source_with_space.items,
    } };
    blk: {
        for (expected_tokens) |e_token| {
            const token = tokenizer.next() catch break :blk;
            try std.testing.expectEqual(e_token, token.id);
        }
        const last_token = tokenizer.next() catch break :blk;
        try std.testing.expect(last_token.id == .Eof);
        return;
    }
    @panic("Test failed");
}
pub const Token = struct {
    start: u32,
    end: u32,
    id: Id,
    pub const List = std.ArrayList(Token);
    pub const Index = u32;
    pub const Id = union(enum) {
        Atom,
        BracketLeft,
        BracketRight,
        BuiltinDefine,
        BuiltinLocalDefine,
        BuiltinDup,
        BuiltinAsType,
        BuiltinFor,
        BuiltinRange,
        BuiltinIf,
        BuiltinIfElse,
        BuiltinPrint,
        BuiltinReturn,
        BuiltinRequireStack,
        BuiltinSwap,
        BuiltinWhile,
        Comment,
        Eof,
        Number,
        Function,
        PreProcUse,
        OperatorDivide,
        OperatorEqual,
        OperatorGreaterThan,
        OperatorGreaterThanOrEqual,
        OperatorLessThan,
        OperatorLessThanOrEqual,
        OperatorMinus,
        OperatorModulo,
        OperatorMultiply,
        OperatorNotEqual,
        OperatorPlus,
        String,
    };
    pub const keywords = std.ComptimeStringMap(Id, .{
        .{ "local", .BuiltinLocalDefine },
        .{ "global", .BuiltinDefine },
        .{ "dup", .BuiltinDup },
        .{ "for", .BuiltinFor },
        .{ "if", .BuiltinIf },
        .{ "ifelse", .BuiltinIfElse },
        .{ "astype", .BuiltinAsType },
        .{ "print", .BuiltinPrint },
        .{ "range", .BuiltinRange },
        .{ "require_stack", .BuiltinRequireStack },
        .{ "return", .BuiltinReturn },
        .{ "swap", .BuiltinSwap },
        .{ "while", .BuiltinWhile },
    });
    pub const directives = std.ComptimeStringMap(Id, .{
        .{ "@use", .PreProcUse },
    });
};
pub const Tokenizer = struct {
    tokens: Token.List,
    it: unicode.Utf8Iterator,
    string: bool = false,
    comment: bool = false,
    fn reportError(self: *Tokenizer, message: []const u8, c: u32) LexerErrors {
        var character: [1]u8 = undefined;
        _ = unicode.utf8Encode(@truncate(u21, c), &character) catch unreachable;
        errors.lexer_panic(message, character);
        self.it.i = self.it.bytes.len;
        return LexerErrors.TokenizerError;
    }
    fn next(self: *Tokenizer) !Token {
        var start_index = self.it.i;
        var state: enum {
            Start,
            String,
            Colon,
            ColonedIdentifier,
            At,
            AtIdentifier,
            Minus,
            Identifier,
            Comment,
            Number,
            NumberDecimal,
            NumberFractional,
            Exclaimation,
            LessThan,
            GreaterThan,
        } = .Start;
        var res: Token.Id = .Eof;
        while (self.it.nextCodepoint()) |c| {
            switch (state) {
                .Start => switch (c) {
                    '#' => {
                        self.comment = true;
                        state = .Comment;
                    },
                    '\"' => {
                        self.string = true;
                        state = .String;
                    },
                    '[' => {
                        res = .BracketLeft;
                        break;
                    },
                    ']' => {
                        res = .BracketRight;
                        break;
                    },
                    ':' => {
                        state = .Colon;
                    },
                    '!' => {
                        state = .Exclaimation;
                    },
                    '+' => {
                        res = .OperatorPlus;
                        break;
                    },
                    '-' => {
                        state = .Minus;
                    },
                    '/' => {
                        res = .OperatorDivide;
                        break;
                    },
                    '*' => {
                        res = .OperatorMultiply;
                        break;
                    },
                    '%' => {
                        res = .OperatorModulo;
                        break;
                    },
                    '=' => {
                        res = .OperatorEqual;
                        break;
                    },
                    '@' => {
                        state = .At;
                    },
                    '<' => {
                        state = .LessThan;
                    },
                    '>' => {
                        state = .GreaterThan;
                    },
                    '0'...'9' => {
                        state = .Number;
                    },
                    else => {
                        if (isWhitespace(c)) {
                            start_index = self.it.i;
                        } else if (isIdentifier(c)) {
                            state = .Identifier;
                        } else {
                            return self.reportError("Invalid Character", c);
                        }
                    },
                },
                .String => {
                    if (c == '\"') {
                        self.string = false;
                        res = .String;
                        break;
                    }
                },
                .Comment => {
                    if (c == '#') {
                        self.comment = false;
                        res = .Comment;
                        break;
                    }
                },
                .Colon => switch (c) {
                    '0'...'9' => {
                        return self.reportError("Atomic name cannot start with number.", c);
                    },
                    else => {
                        if (isWhitespace(c)) {
                            return self.reportError("Colon requires valid name following it.", c);
                        } else if (isIdentifier(c)) {
                            state = .ColonedIdentifier;
                        }
                    },
                },
                .ColonedIdentifier => {
                    if (!isIdentifier(c)) {
                        self.it.i -= unicode.utf8CodepointSequenceLength(c) catch unreachable;
                        res = .Atom;
                        break;
                    }
                },
                .At => {
                    if (isWhitespace(c)) {
                        return self.reportError("At requires preprocessor statement following it.", c);
                    } else if (isIdentifier(c)) {
                        state = .AtIdentifier;
                    }
                },
                .AtIdentifier => {
                    if (!isIdentifier(c)) {
                        self.it.i -= unicode.utf8CodepointSequenceLength(c) catch unreachable;
                        const slice = self.it.bytes[start_index..self.it.i];
                        res = Token.directives.get(slice) orelse unreachable;
                        break;
                    }
                },
                .Minus => {
                    switch (c) {
                        '0'...'9' => {
                            state = .Number;
                        },
                        else => {
                            self.it.i = start_index + 1;
                            res = .OperatorMinus;
                            break;
                        },
                    }
                },
                .Identifier => {
                    if (!isIdentifier(c)) {
                        self.it.i -= unicode.utf8CodepointSequenceLength(c) catch unreachable;
                        const slice = self.it.bytes[start_index..self.it.i];
                        res = Token.keywords.get(slice) orelse .Function;
                        break;
                    }
                },
                .Number => switch (c) {
                    '0'...'9', '_' => {},
                    '.' => {
                        state = .NumberDecimal;
                    },
                    else => {
                        self.it.i -= unicode.utf8CodepointSequenceLength(c) catch unreachable;
                        res = .Number;
                        break;
                    },
                },
                .NumberDecimal => switch (c) {
                    '0'...'9' => {
                        state = .NumberFractional;
                    },
                    else => {
                        return self.reportError("Float number requires digits after decimal point.", c);
                    },
                },
                .NumberFractional => switch (c) {
                    '0'...'9', '_' => {},
                    else => {
                        self.it.i -= unicode.utf8CodepointSequenceLength(c) catch unreachable;
                        res = .Number;
                        break;
                    },
                },
                .Exclaimation => switch (c) {
                    '=' => {
                        res = .OperatorNotEqual;
                        break;
                    },
                    else => {
                        return self.reportError("Invalid Exclaimation Mark. Use 'not' function for boolean not.", c);
                    },
                },
                .GreaterThan => switch (c) {
                    '=' => {
                        res = .OperatorGreaterThanOrEqual;
                        break;
                    },
                    else => {
                        if (isWhitespace(c)) {
                            res = .OperatorGreaterThan;
                            break;
                        } else {
                            return self.reportError("Surround 'greater than' symbols in spaces.", c);
                        }
                    },
                },
                .LessThan => switch (c) {
                    '=' => {
                        res = .OperatorLessThanOrEqual;
                        break;
                    },
                    else => {
                        if (isWhitespace(c)) {
                            res = .OperatorLessThan;
                            break;
                        } else {
                            return self.reportError("Surround 'less than' symbols in spaces.", c);
                        }
                    },
                },
            }
        }
        return Token{ .id = res, .start = @truncate(u32, start_index), .end = @truncate(u32, self.it.i) };
    }
};
pub fn tokenize(alloc: std.mem.Allocator, source: []const u8) ![]const Token {
    var source_with_space = std.ArrayList(u8).init(alloc);
    defer source_with_space.deinit();
    try source_with_space.appendSlice(source);
    try source_with_space.append('\n');
    const estimated_tokens = source.len / 8;
    var tokenizer = Tokenizer{ .tokens = try Token.List.initCapacity(alloc, estimated_tokens), .it = .{
        .i = 0,
        .bytes = source_with_space.items,
    } };
    errdefer tokenizer.tokens.deinit();
    while (true) {
        const tok = try tokenizer.tokens.addOne();
        tok.* = try tokenizer.next();
        if (tok.id == .Eof) {
            return tokenizer.tokens.toOwnedSlice();
        }
    }
}
test "single_tokens" {
    try expectTokens("+ - / * [] = %", &[_]Token.Id{
        .OperatorPlus,
        .OperatorMinus,
        .OperatorDivide,
        .OperatorMultiply,
        .BracketLeft,
        .BracketRight,
        .OperatorEqual,
        .OperatorModulo,
    });
}
test "strings_n_things" {
    try expectTokens("\"Hello World\" + +", &[_]Token.Id{
        .String,
        .OperatorPlus,
        .OperatorPlus,
    });
}
test "average_hello_world" {
    try expectTokens("\"Hello World\" puts #This program prints HELLO WORLD!#", &[_]Token.Id{
        .String,
        .Function,
        .Comment,
    });
}
test "atomics" {
    try expectTokens(":hello_there :this_atomic", &[_]Token.Id{
        .Atom,
        .Atom,
    });
}
