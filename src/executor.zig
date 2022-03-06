const std = @import("std");
const errors = @import("errors.zig");
const fmt = std.fmt;
const print = std.debug.print;
const parser = @import("parser.zig");

const StackType = enum {
    String,
    Atom,
    Float,
    TokenList,
    FloatList,
};
const StackItem = struct { item_type: StackType, data: union {
    text: []const u8,
    float: f64,
    token_list: []parser.Token,
    float_list: []f64,
} };

const Stack = struct {
    list: std.ArrayList(StackItem) = undefined,
    variables: std.StringHashMap(StackItem) = undefined,
    stack_allocator: std.mem.Allocator = undefined,
    bracket_depth: u64 = 0,
    scope_depth: u64   = 0,
    fn init(self: *Stack, alloc: std.mem.Allocator) !void {
        self.stack_allocator = alloc;
        self.list = try std.ArrayList(StackItem).initCapacity(alloc, 1024);
        self.variables = std.StringHashMap(StackItem).init(alloc);
    }
    fn item_is(_: *Stack, item: StackItem, required_type: StackType) bool {
        if (item.item_type == required_type) {
            return true;
        } else {
            return false;
        }
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
        if (!self.item_is(key, .Atom)) {
            errors.executor_panic("'define' expected type Atom as key, got type ",key.item_type);
        }
        try self.variables.put(try self.stack_allocator.dupe(u8,key.data.text), value);
        //std.debug.print("{s} :: {any}\n",.{key.data.text,value});
    }
    fn builtin_local_define(self: *Stack) !void {
        if (self.scope_depth == 0) {
            errors.panic("'local' only valid inside functions.");
        }
        const value = self.list.pop();
        const key = self.list.pop();
        if (!self.item_is(key, .Atom)) {
            errors.executor_panic("'local' expected type Atom as key, got type ",key.item_type);
        }
        var key_string = std.ArrayList(u8).init(self.stack_allocator);
        defer key_string.deinit();
        var scope_as_str = try std.fmt.allocPrint(self.stack_allocator,"{}",.{self.scope_depth});
        try key_string.appendSlice(scope_as_str);
        try key_string.appendSlice(key.data.text);
        try self.variables.put(key_string.toOwnedSlice(), value);
        //std.debug.print("{s} :: {any}\n",.{key.data.text,value});
    }
    fn builtin_if(
        self: *Stack,
        current_token_list: *std.ArrayList(parser.Token),
    ) anyerror!void {
        const clause = self.list.pop();
        const condition = self.list.pop();
        if (!self.item_is(clause, .TokenList)) {
            errors.executor_panic("'if' expected type TokenList as clause, got type ",clause.item_type);
        }
        if (!self.item_is(condition, .Float)) {
            errors.executor_panic("'if' expected type Float as condition, got type ",condition.item_type);
        }
        if (condition.data.float == 1) {
            for (clause.data.token_list) |tok| {
                try execute_single_token(tok, current_token_list, self );
            }
        }
    }
    fn builtin_ifelse(
        self: *Stack,
        current_token_list: *std.ArrayList(parser.Token),
    ) anyerror!void {
        const elseclause = self.list.pop();
        const ifclause = self.list.pop();
        const condition = self.list.pop();
        if (!self.item_is(ifclause, .TokenList)) {
            errors.executor_panic("'ifelse' expected type TokenList as first clause, got type ",ifclause.item_type);
        }
        if (!self.item_is(elseclause, .TokenList)) {
            errors.executor_panic("'ifelse' expected type TokenList as second clause, got type ",elseclause.item_type);
        }
        if (!self.item_is(condition, .Float)) {
            errors.executor_panic("'ifelse' expected type Float as condition, got type ",condition.item_type);
        }
        if (condition.data.float == 1) {
            for (ifclause.data.token_list) |tok| {
                try execute_single_token(tok, current_token_list, self);
            }
        } else {
            for (elseclause.data.token_list) |tok| {
                try execute_single_token(tok, current_token_list, self);
            }
        }
    }
    fn builtin_while(
        self: *Stack,
        current_token_list: *std.ArrayList(parser.Token),
    ) anyerror!void {
        const clause = self.list.pop();
        const condition = self.list.pop();
        if (!self.item_is(clause, .TokenList)) {
            errors.executor_panic("'while' expected type TokenList as clause, got type ",clause.item_type);
        }
        if (!self.item_is(condition, .TokenList)) {
            errors.executor_panic("'while' expected type TokenList as condition, got type ",condition.item_type);
        }
        while (true) {
            for (condition.data.token_list) |tok| {
                try execute_single_token(tok, current_token_list, self);
            }
            if (self.list.pop().data.float == 0) {
                break;
            }
            for (clause.data.token_list) |tok| {
                try execute_single_token(tok, current_token_list, self);
            }
        }
    }
    fn builtin_range(self: *Stack) !void {
        const end = self.list.pop();
        const start = self.list.pop();
        if (!self.item_is(start, .Float)) {
            errors.executor_panic("'range' expected type Float as start, got type ",start.item_type);
        }
        if (!self.item_is(end, .Float)) {
            errors.executor_panic("'range' expected type Float as end, got type ",end.item_type);
        }
        var i = start.data.float;
        var float_list = std.ArrayList(f64).init(self.stack_allocator);
        while (i < end.data.float) : (i += 1) {
            try float_list.append(i);
        }
        try self.append(StackItem{ .item_type = .FloatList, .data = .{ .float_list = float_list.toOwnedSlice() } });
    }
    fn builtin_for(
        self: *Stack,
        current_token_list: *std.ArrayList(parser.Token),
    ) anyerror!void {
        const clause = self.list.pop();
        const var_name = self.list.pop();
        const list = self.list.pop();
        if (!self.item_is(clause, .TokenList)) {
            errors.executor_panic("'for' expected type TokenList as clause, got type ",clause.item_type);
        }
        if (!self.item_is(var_name, .Atom)) {
            errors.executor_panic("'for' expected type Atom as iterator variable, got type ",var_name.item_type);
        }
        if (!self.item_is(list, .FloatList)) {
            errors.executor_panic("'for' expected type FloatList as the list to iterate over, got type ",list.item_type);
        }
        switch (list.item_type) {
            .FloatList => {
                for (list.data.float_list) |fl| {
                    try self.variables.put(var_name.data.text, self.create_float(fl));
                    for (clause.data.token_list) |tok| {
                        try execute_single_token(tok, current_token_list, self);
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
        name: []const u8,
        current_token_list: *std.ArrayList(parser.Token),
    ) anyerror!void {
        var possible_func : ?StackItem = undefined;
        possible_func = self.variables.get(name);
        if (possible_func) |_| {} else {
            if (self.scope_depth != 0) {
                var key_string = std.ArrayList(u8).init(self.stack_allocator);
                defer key_string.deinit();
                var scope_as_str = try std.fmt.allocPrint(self.stack_allocator,"{}",.{self.scope_depth});
                try key_string.appendSlice(scope_as_str);
                try key_string.appendSlice(name);
                const new_name = key_string.toOwnedSlice();
                //print("Can find? {s}\n",.{key_string.items});
                possible_func = self.variables.get(new_name);
            }
            if (possible_func) |_| {} else errors.executor_panic("Unknown function ",name);
        }
        //print("FUNCITON WITH NAME {s}\n",.{name});
        if (possible_func) |function_contents| {
            switch (function_contents.item_type) {
                .TokenList => {
                    for (function_contents.data.token_list) |tok| {
                        self.scope_depth += 1;
                        // if (tok.id == .BuiltinReturn) {
                        //     bracket_depth = 0;
                        //     return;
                        // }
                        try execute_single_token(tok, current_token_list, self);
                        self.scope_depth -= 1;
                    }
                },
                else => {
                    try self.append(function_contents);
                },
            }
        } else unreachable;
    }
    fn builtin_float2int(self: *Stack) !void {
        const value = self.list.pop();
        if (!self.item_is(value,.Float)) {
            errors.executor_panic("float2int expected Float, got ",value.item_type);
        }
        try self.append(self.create_float(@floor(value.data.float)));
    }

    fn append(self: *Stack, value: StackItem) !void {
        try self.list.append(value);
    }
    fn operator_plus(self: *Stack) !void {
        const a = self.list.pop();
        const b = self.list.pop();
        if (!(self.item_is(a,.Float) and self.item_is(b,.Float))) {
            errors.executor_panic("Addition operator requires two numbers, got ",.{b.item_type, a.item_type});
        } 
        try self.append(self.create_float(b.data.float + a.data.float));
    }
    fn operator_minus(self: *Stack) !void {
        const a = self.list.pop();
        const b = self.list.pop();
        if (!(self.item_is(a,.Float) and self.item_is(b,.Float))) {
            errors.executor_panic("Subtraction operator requires two numbers, got ",.{b.item_type, a.item_type});
        } 
        try self.append(self.create_float(b.data.float - a.data.float));
    }
    fn operator_divide(self: *Stack) !void {
        const a = self.list.pop();
        const b = self.list.pop();
        if (!(self.item_is(a,.Float) and self.item_is(b,.Float))) {
            errors.executor_panic("Division operator requires two numbers, got ",.{b.item_type, a.item_type});
        } 
        try self.append(self.create_float(b.data.float / a.data.float));
    }
    fn operator_multiply(self: *Stack) !void {
        const a = self.list.pop();
        const b = self.list.pop();
        if (!(self.item_is(a,.Float) and self.item_is(b,.Float))) {
            errors.executor_panic("Multiplication operator requires two numbers, got ",.{b.item_type, a.item_type});
        } 
        try self.append(self.create_float(b.data.float * a.data.float));
    }
    fn operator_modulo(self: *Stack) !void {
        const a = self.list.pop();
        const b = self.list.pop();
        if (!(self.item_is(a,.Float) and self.item_is(b,.Float))) {
            errors.executor_panic("Modulus operator requires two numbers, got ",.{b.item_type, a.item_type});
        } 
        try self.append(self.create_float(@rem(b.data.float, a.data.float)));
    }
    fn operator_eq(self: *Stack) !void {
        const a = self.list.pop();
        const b = self.list.pop();
        if (!(self.item_is(a,.Float) and self.item_is(b,.Float))) {
            errors.executor_panic("Equality operator requires two numbers, got ",.{b.item_type, a.item_type});
        } 
        try self.append(self.create_float(@intToFloat(f64, @boolToInt(b.data.float == a.data.float))));
    }
    fn operator_neq(self: *Stack) !void {
        const a = self.list.pop();
        const b = self.list.pop();
        if (!(self.item_is(a,.Float) and self.item_is(b,.Float))) {
            errors.executor_panic("Not equal to operator requires two numbers, got ",.{b.item_type, a.item_type});
        } 
        try self.append(self.create_float(@intToFloat(f64, @boolToInt(b.data.float != a.data.float))));
    }
    fn operator_lt(self: *Stack) !void {
        const a = self.list.pop();
        const b = self.list.pop();
        if (!(self.item_is(a,.Float) and self.item_is(b,.Float))) {
            errors.executor_panic("Less than requires two numbers, got ",.{b.item_type, a.item_type});
        } 
        try self.append(self.create_float(@intToFloat(f64, @boolToInt(b.data.float < a.data.float))));
    }
    fn operator_gt(self: *Stack) !void {
        const a = self.list.pop();
        const b = self.list.pop();
        if (!(self.item_is(a,.Float) and self.item_is(b,.Float))) {
            errors.executor_panic("Greater than requires two numbers, got ",.{b.item_type, a.item_type});
        } 
        try self.append(self.create_float(@intToFloat(f64, @boolToInt(b.data.float > a.data.float))));
    }
    fn operator_lteq(self: *Stack) !void {
        const a = self.list.pop();
        const b = self.list.pop();
        if (!(self.item_is(a,.Float) and self.item_is(b,.Float))) {
            errors.executor_panic("Less than or equal operator requires two numbers, got ",.{b.item_type, a.item_type});
        } 
        try self.append(self.create_float(@intToFloat(f64, @boolToInt(b.data.float <= a.data.float))));
    }
    fn operator_gteq(self: *Stack) !void {
        const a = self.list.pop();
        const b = self.list.pop();
        if (!(self.item_is(a,.Float) and self.item_is(b,.Float))) {
            errors.executor_panic("Greater than or equal operator requires two numbers, got ",.{b.item_type, a.item_type});
        } 
        try self.append(self.create_float(@intToFloat(f64, @boolToInt(b.data.float >= a.data.float))));
    }
};
// Bracket Depth tells us if we're inside a quote
// Scope Depth tells us if we're executing a quote
fn execute_single_token(
    t: parser.Token,
    current_token_list: *std.ArrayList(parser.Token),
    stack: *Stack,
) !void {
    //print("DEBUG :: EXECUTE SINGLE TOKEN CALLED WITH {any} {any} {any} {any} {any}\n",.{t , raw_data, bracket_depth.*, current_token_list.*, stack.*});
    //std.debug.print("SCOPE, BRACKET DEPTH :: {}, {}, {}\n",.{stack.*.scope_depth,stack.*.bracket_depth , t.id});
    if (stack.*.bracket_depth == 0) {
        switch (t.id) {
            .Eof     => { return; },
            .Comment => { @panic("Comment was not parsed properly"); },
            .BracketLeft => {
                stack.*.bracket_depth += 1;
            },
            .BracketRight => {
                errors.panic("Brackets are not balanced. A left bracket must always precede a right one.");
            },
            .Float => {
                try stack.*.append(stack.*.create_float(t.data.num));
            },
            .BuiltinFloatToInt => {
                try stack.*.builtin_float2int();
            },
            .String => {
                try stack.*.append(stack.*.create_string(t.data.str));
            },
            .Atom => {
                try stack.*.append(stack.*.create_atom(t.data.str));
            },
            .Function => {
                try stack.*.execute_function(
                    t.data.str,
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
                    current_token_list,
                );
            },
            .BuiltinIfElse => {
                try stack.*.builtin_ifelse(
                    current_token_list,
                );
            },
            .BuiltinDefine => {
                try stack.*.builtin_define();
            },
            .BuiltinLocalDefine => {
                try stack.*.builtin_local_define();
            },
            .BuiltinRequireStack => {},
            .BuiltinFor => {
                try stack.*.builtin_for(
                    current_token_list,
                );
            },
            .BuiltinWhile => {
                try stack.*.builtin_while(
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
                stack.*.bracket_depth += 1;
                try current_token_list.*.append(t);
            },
            .BracketRight => {
                stack.*.bracket_depth -= 1;
                if (stack.*.bracket_depth == 0) {
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

pub fn execute(alloc: std.mem.Allocator, tokens: []const parser.Token) anyerror!void {
    var stack = Stack{};
    try stack.init(alloc);
    var current_token_list = std.ArrayList(parser.Token).init(alloc);
    for (tokens) |t| {
        try execute_single_token(t, &current_token_list, &stack);
    }
}
