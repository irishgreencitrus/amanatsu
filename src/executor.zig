const std = @import("std");
const fmt = std.fmt;
const print = std.debug.print;
const lexer = @import("lexer.zig");

const StackItem = struct { item_type: enum {
    String,
    Atom,
    Float,
    TokenList,
    FloatList,
}, data: union {
    text: []const u8,
    float: f64,
    token_list: []lexer.Token,
    float_list: []f64,
} };

const Stack = struct {
    list: std.ArrayList(StackItem) = undefined,
    variables: std.StringHashMap(StackItem) = undefined,
    stack_allocator: std.mem.Allocator = undefined,
    fn init(self: *Stack, alloc: std.mem.Allocator) !void {
        self.stack_allocator = alloc;
        self.list = try std.ArrayList(StackItem).initCapacity(alloc, 1024);
        self.variables = std.StringHashMap(StackItem).init(alloc);
    }
    fn create_float(_: *Stack, value: f64) StackItem {
        return StackItem{ .item_type = .Float, .data = .{ .float = value } };
    }
    fn create_string(_: *Stack, value: []const u8) StackItem {
        return StackItem{ .item_type = .String, .data = .{ .text = value } };
    }
    fn create_atom(_: *Stack, value: []const u8) StackItem {
        return StackItem{ .item_type = .Atom, .data = .{ .text = value } };
    }
    fn builtin_define(self: *Stack) !void {
        const value = self.list.pop();
        const key = self.list.pop();
        try self.variables.put(key.data.text, value);
    }
    fn builtin_if(
        self: *Stack,
        raw_data: []const u8,
        bracket_depth: *u64,
        current_token_list: *std.ArrayList(lexer.Token),
    ) anyerror!void {
        const clause = self.list.pop();
        const condition = self.list.pop();
        if (condition.data.float == 1) {
            for (clause.data.token_list) |tok| {
                try execute_single_token(tok, raw_data, bracket_depth, current_token_list, self);
            }
        }
    }
    fn builtin_ifelse(
        self: *Stack,
        raw_data: []const u8,
        bracket_depth: *u64,
        current_token_list: *std.ArrayList(lexer.Token),
    ) anyerror!void {
        const elseclause = self.list.pop();
        const ifclause = self.list.pop();
        const condition = self.list.pop();
        if (condition.data.float == 1) {
            for (ifclause.data.token_list) |tok| {
                try execute_single_token(tok, raw_data, bracket_depth, current_token_list, self);
            }
        } else {
            for (elseclause.data.token_list) |tok| {
                try execute_single_token(tok, raw_data, bracket_depth, current_token_list, self);
            }
        }
    }
    fn builtin_while(
        self: *Stack,
        raw_data: []const u8,
        bracket_depth: *u64,
        current_token_list: *std.ArrayList(lexer.Token),
    ) anyerror!void {
        const clause = self.list.pop();
        const condition = self.list.pop();
        while (true) {
            for (condition.data.token_list) |tok| {
                try execute_single_token(tok, raw_data, bracket_depth, current_token_list, self);
            }
            if (self.list.pop().data.float == 0) {
                break;
            }
            for (clause.data.token_list) |tok| {
                try execute_single_token(tok, raw_data, bracket_depth, current_token_list, self);
            }
        }
    }
    fn builtin_range(self: *Stack) !void {
        const end = self.list.pop().data.float;
        const start = self.list.pop();
        var i = start.data.float;
        var float_list = std.ArrayList(f64).init(self.stack_allocator);
        while (i < end) : (i += 1) {
            try float_list.append(i);
        }
        try self.append(StackItem{ .item_type = .FloatList, .data = .{ .float_list = float_list.toOwnedSlice() } });
    }
    fn builtin_for(
        self: *Stack,
        raw_data: []const u8,
        bracket_depth: *u64,
        current_token_list: *std.ArrayList(lexer.Token),
    ) anyerror!void {
        const clause = self.list.pop();
        const var_name = self.list.pop();
        const list = self.list.pop();
        switch (list.item_type) {
            .FloatList => {
                for (list.data.float_list) |fl| {
                    try self.variables.put(var_name.data.text, self.create_float(fl));
                    for (clause.data.token_list) |tok| {
                        try execute_single_token(tok, raw_data, bracket_depth, current_token_list, self);
                    }
                }
            },
            else => unreachable,
        }
    }
    fn builtin_print(self: *Stack) !void {
        const top = self.list.pop();
        switch (top.item_type) {
            .Atom, .String => {
                print("{s}", .{top.data.text});
            },
            .Float => {
                if (std.math.floor(top.data.float) == top.data.float) {
                    print("{}", .{@floatToInt(i128, top.data.float)});
                } else {
                    print("{}", .{top.data.float});
                }
            },
            else => {},
        }
        print("\n", .{});
    }
    fn builtin_dup(self: *Stack) !void {
        const top = self.list.pop();
        try self.append(top);
        try self.append(top);
    }
    fn builtin_swap(self: *Stack) !void {
        const a = self.list.pop();
        const b = self.list.pop();
        try self.append(a);
        try self.append(b);
    }
    fn execute_function(
        self: *Stack,
        raw_data: []const u8,
        name: []const u8,
        bracket_depth: *u64,
        current_token_list: *std.ArrayList(lexer.Token),
    ) anyerror!void {
        var function_contents = self.variables.get(name).?;
        switch (function_contents.item_type) {
            .TokenList => {
                for (function_contents.data.token_list) |tok| {
                    if (tok.id == .BuiltinReturn) {
                        bracket_depth.* = 0;
                        return;
                    }
                    try execute_single_token(tok, raw_data, bracket_depth, current_token_list, self);
                }
            },
            else => {
                try self.append(function_contents);
            },
        }
    }

    fn append(self: *Stack, value: StackItem) !void {
        try self.list.append(value);
    }
    fn operator_plus(self: *Stack) !void {
        const a = self.list.pop();
        const b = self.list.pop();
        try self.append(self.create_float(b.data.float + a.data.float));
    }
    fn operator_minus(self: *Stack) !void {
        const a = self.list.pop();
        const b = self.list.pop();
        try self.append(self.create_float(b.data.float - a.data.float));
    }
    fn operator_divide(self: *Stack) !void {
        const a = self.list.pop();
        const b = self.list.pop();
        try self.append(self.create_float(b.data.float / a.data.float));
    }
    fn operator_multiply(self: *Stack) !void {
        const a = self.list.pop();
        const b = self.list.pop();
        try self.append(self.create_float(b.data.float * a.data.float));
    }
    fn operator_modulo(self: *Stack) !void {
        const a = self.list.pop();
        const b = self.list.pop();
        try self.append(self.create_float(@rem(b.data.float, a.data.float)));
    }
    fn operator_eq(self: *Stack) !void {
        const a = self.list.pop();
        const b = self.list.pop();
        try self.append(self.create_float(@intToFloat(f64, @boolToInt(b.data.float == a.data.float))));
    }
    fn operator_neq(self: *Stack) !void {
        const a = self.list.pop();
        const b = self.list.pop();
        try self.append(self.create_float(@intToFloat(f64, @boolToInt(b.data.float != a.data.float))));
    }
    fn operator_lt(self: *Stack) !void {
        const a = self.list.pop();
        const b = self.list.pop();
        try self.append(self.create_float(@intToFloat(f64, @boolToInt(b.data.float < a.data.float))));
    }
    fn operator_gt(self: *Stack) !void {
        const a = self.list.pop();
        const b = self.list.pop();
        try self.append(self.create_float(@intToFloat(f64, @boolToInt(b.data.float > a.data.float))));
    }
    fn operator_lteq(self: *Stack) !void {
        const a = self.list.pop();
        const b = self.list.pop();
        try self.append(self.create_float(@intToFloat(f64, @boolToInt(b.data.float <= a.data.float))));
    }
    fn operator_gteq(self: *Stack) !void {
        const a = self.list.pop();
        const b = self.list.pop();
        try self.append(self.create_float(@intToFloat(f64, @boolToInt(b.data.float >= a.data.float))));
    }
};
fn execute_single_token(
    t: lexer.Token,
    raw_data: []const u8,
    bracket_depth: *u64,
    current_token_list: *std.ArrayList(lexer.Token),
    stack: *Stack,
) !void {
    if (bracket_depth.* == 0) {
        switch (t.id) {
            .Eof, .Comment => {},
            .BracketLeft => {
                bracket_depth.* += 1;
            },
            .BracketRight => {
                unreachable;
            },
            .Float => {
                try stack.*.append(stack.*.create_float(try fmt.parseFloat(f64, raw_data[t.start..t.end])));
            },
            .String => {
                try stack.*.append(stack.*.create_string(raw_data[t.start + 1 .. t.end - 1]));
            },
            .Atom => {
                try stack.*.append(stack.*.create_atom(raw_data[t.start + 1 .. t.end]));
            },
            .Function => {
                try stack.*.execute_function(
                    raw_data,
                    raw_data[t.start..t.end],
                    bracket_depth,
                    current_token_list,
                );
            },
            .BuiltinRange => {
                try stack.*.builtin_range();
            },
            .BuiltinPrint => {
                try stack.*.builtin_print();
            },
            .BuiltinIf => {
                try stack.*.builtin_if(
                    raw_data,
                    bracket_depth,
                    current_token_list,
                );
            },
            .BuiltinIfElse => {
                try stack.*.builtin_ifelse(
                    raw_data,
                    bracket_depth,
                    current_token_list,
                );
            },
            .BuiltinDefine => {
                try stack.*.builtin_define();
            },
            .BuiltinRequireStack => {},
            .BuiltinFor => {
                try stack.*.builtin_for(
                    raw_data,
                    bracket_depth,
                    current_token_list,
                );
            },
            .BuiltinWhile => {
                try stack.*.builtin_while(
                    raw_data,
                    bracket_depth,
                    current_token_list,
                );
            },
            .BuiltinDup => {
                try stack.*.builtin_dup();
            },
            .BuiltinSwap => {
                try stack.*.builtin_swap();
            },
            .OperatorPlus => {
                try stack.*.operator_plus();
            },
            .OperatorMinus => {
                try stack.*.operator_minus();
            },
            .OperatorDivide => {
                try stack.*.operator_divide();
            },
            .OperatorMultiply => {
                try stack.*.operator_multiply();
            },
            .OperatorModulo => {
                try stack.*.operator_modulo();
            },
            .OperatorEqual => {
                try stack.*.operator_eq();
            },
            .OperatorNotEqual => {
                try stack.*.operator_neq();
            },
            .OperatorLessThan => {
                try stack.*.operator_lt();
            },
            .OperatorGreaterThan => {
                try stack.*.operator_gt();
            },
            .OperatorLessThanOrEqual => {
                try stack.*.operator_lteq();
            },
            .OperatorGreaterThanOrEqual => {
                try stack.*.operator_gteq();
            },
            else => {},
        }
    } else {
        switch (t.id) {
            .BracketLeft => {
                bracket_depth.* += 1;
                try current_token_list.*.append(t);
            },
            .BracketRight => {
                bracket_depth.* -= 1;
                if (bracket_depth.* == 0) {
                    try stack.*.append(StackItem{
                        .item_type = .TokenList,
                        .data = .{
                            .token_list = current_token_list.toOwnedSlice(),
                        },
                    });
                } else {
                    try current_token_list.*.append(t);
                }
            },
            else => {
                try current_token_list.*.append(t);
            },
        }
    }
}

pub fn execute(alloc: std.mem.Allocator, tokens: []const lexer.Token, raw_data: []const u8) anyerror!void {
    var stack = Stack{};
    try stack.init(alloc);
    var bracket_depth: u64 = 0;
    var current_token_list = std.ArrayList(lexer.Token).init(alloc);
    for (tokens) |t| {
        try execute_single_token(t, raw_data, &bracket_depth, &current_token_list, &stack);
    }
}