const std = @import("std");
const errors = @import("errors.zig");
const fmt = std.fmt;
const data_types = @import("data_types.zig");
const parser = @import("parser.zig");

const StackNumberType = data_types.UsedNumberType;
const StackType = enum {
    String,
    Atom,
    Number,
    TokenList,
    NumberList,
};
const StackItem = struct { item_type: StackType, data: union {
    text: []const u8,
    number: StackNumberType,
    token_list: []parser.Token,
    number_list: []StackNumberType,
} };

fn dprint(comptime format: []const u8, args: anytype) void {
    std.log.debug(format, args);
}
fn print(comptime format: []const u8, args: anytype) void {
    const stdout = std.io.getStdOut().writer();
    nosuspend stdout.print(format, args) catch return;
}

const Stack = struct {
    list: std.ArrayList(StackItem) = undefined,
    variables: std.StringHashMap(StackItem) = undefined,
    stack_allocator: std.mem.Allocator = undefined,
    bracket_depth: u64 = 0,
    scope_depth: u64 = 0,
    return_flag: bool = false,
    fn init(self: *Stack, alloc: std.mem.Allocator) !void {
        self.stack_allocator = alloc;
        self.list = try std.ArrayList(StackItem).initCapacity(alloc, 1024);
        self.variables = std.StringHashMap(StackItem).init(alloc);
    }
    fn item_is(_: *Stack, item: StackItem, required_type: StackType) bool {
        return item.item_type == required_type;
    }
    fn create_numberlist(_: *Stack, value: []StackNumberType) StackItem {
        return StackItem{ .item_type = .NumberList, .data = .{ .number_list = value } };
    }
    fn create_number(_: *Stack, value: StackNumberType) StackItem {
        return StackItem{ .item_type = .Number, .data = .{ .number = value } };
    }
    fn create_string(_: *Stack, value: []const u8) StackItem {
        return StackItem{ .item_type = .String, .data = .{ .text = value } };
    }
    fn create_atom(_: *Stack, value: []const u8) StackItem {
        return StackItem{ .item_type = .Atom, .data = .{ .text = value } };
    }
    fn atom_to_type(_: *Stack, atom: StackItem) ?StackType {
        if (atom.item_type != .Atom) @panic("atom_to_type called with wrong arguments");
        if (std.mem.eql(u8, atom.data.text, "Atom")) {
            return .Atom;
        }
        if (std.mem.eql(u8, atom.data.text, "String")) {
            return .String;
        }
        if (std.mem.eql(u8, atom.data.text, "Number")) {
            return .Number;
        }
        if (std.mem.eql(u8, atom.data.text, "TokenList")) {
            return .TokenList;
        }
        if (std.mem.eql(u8, atom.data.text, "NumberList")) {
            return .NumberList;
        }
        return null;
    }
    fn builtin_as_type(self: *Stack) !void {
        const result_type_atom = self.list.pop();
        const to_convert = self.list.pop();
        if (!self.item_is(result_type_atom, .Atom)) {
            errors.executor_panic("'as_type' expected type Atom as resulting type, got type ", result_type_atom.item_type);
        }
        const result_type = self.atom_to_type(result_type_atom) orelse
            errors.panic("Invalid type for 'astype' conversion. Expected one of `Atom` `String` `Number` `TokenList` `NumberList`. Perhaps you misspelt?");

        const current_type = to_convert.item_type;

        // Rules for conversion
        // t = always
        // ? = sometimes
        // Atom =>
        //   String t
        // String =>
        //   Atom ?
        //   Number ?
        //   NumberList t :: Get ASCII codes of string value
        // Number =>
        //   String t
        // TokenList =>
        //   NumberList ?
        // NumberList =>
        //   TokenList t
        //   String t :: Convert back to string using ASCII values
        var result: ?StackItem = null;
        switch (current_type) {
            .Atom => switch (result_type) {
                .String => result = self.create_string(to_convert.data.text),
                else => {},
            },
            .String => switch (result_type) {
                .Atom => {
                    // Check if the String is a valid Atom.
                    switch (to_convert.data.text[0]) {
                        '0'...'9' => errors.panic("Failed to convert type String to Atom. String starts with Number, this is invalid in an Atom."),
                        else => {},
                    }
                    for (to_convert.data.text) |n| {
                        if (!@import("lexer.zig").isIdentifier(n)) {
                            errors.panic("Failed to convert type String to Atom. String does not conform to Atom naming requirements.");
                        }
                    }
                    result = self.create_atom(to_convert.data.text);
                },
                .Number => {
                    result = self.create_number(std.fmt.parseFloat(StackNumberType, to_convert.data.text) catch errors.panic("Failed to convert type String to Number. String is not a valid Number"));
                },
                .NumberList => {
                    var number_list = std.ArrayList(StackNumberType).init(self.stack_allocator);
                    for (to_convert.data.text) |n| {
                        try number_list.append(@intToFloat(StackNumberType, n));
                    }
                    result = self.create_numberlist(number_list.toOwnedSlice());
                },
                else => {},
            },
            .Number => switch (result_type) {
                .String => result = self.create_string(try std.fmt.allocPrint(self.stack_allocator, "{d}", .{to_convert.data.number})),
                else => {},
            },
            .TokenList => switch (result_type) {
                .NumberList => {
                    var number_list = std.ArrayList(StackNumberType).init(self.stack_allocator);
                    for (to_convert.data.token_list) |t| {
                        if (t.id != .Number) errors.panic("Failed to convert type TokenList to NumberList. List contains more than just numbers");
                        try number_list.append(t.data.number);
                    }
                    result = self.create_numberlist(number_list.toOwnedSlice());
                },
                else => {},
            },
            .NumberList => switch (result_type) {
                .TokenList => {
                    var token_list = std.ArrayList(parser.Token).init(self.stack_allocator);
                    for (to_convert.data.number_list) |num| {
                        try token_list.append(parser.Token{ .id = .Number, .start = 0, .data = .{ .number = num } });
                    }
                    result = StackItem{ .item_type = .TokenList, .data = .{ .token_list = token_list.toOwnedSlice() } };
                },
                else => {},
            },
        }
        if (result) |r| {
            try self.list.append(r);
        } else {
            errors.executor_panic("Unable to convert types ", .{ current_type, result_type });
        }
    }
    fn builtin_define(self: *Stack) !void {
        const value = self.list.pop();
        const key = self.list.pop();
        if (!self.item_is(key, .Atom)) {
            errors.executor_panic("'define' expected type Atom as key, got type ", key.item_type);
        }
        if (key.data.text[0] == 0) {
            var iter = self.variables.keyIterator();
            while (iter.next()) |item| {
                dprint("KEY :: {s}", .{item.*});
            }
            @panic("NULL BYTE DETECTED IN DEFINE. THIS IS A BUG IN THE INTERPRETER.");
        }
        try self.variables.put(try self.stack_allocator.dupe(u8, key.data.text), value);
        dprint("DEFINE {any} :: {any}", .{ key.data.text, value });
    }
    fn builtin_local_define(self: *Stack) !void {
        if (self.scope_depth == 0) {
            errors.panic("'local' only valid inside functions.");
        }
        const value = self.list.pop();
        const key = self.list.pop();
        dprint("LOCALDEFINE {any} :: {any}", .{ key.data.text, value });
        if (!self.item_is(key, .Atom)) {
            errors.executor_panic("'local' expected type Atom as key, got type ", key.item_type);
        }
        if (key.data.text[0] == 0) {
            var iter = self.variables.keyIterator();
            while (iter.next()) |item| {
                dprint("KEY :: {any}", .{item.*});
                dprint("VALUE :: {any}", .{self.variables.get(item.*)});
            }
            @panic("NULL BYTE DETECTED IN LOCALDEFINE. THIS IS A BUG IN THE INTERPRETER.");
        }
        var key_string = std.ArrayList(u8).init(self.stack_allocator);
        defer key_string.deinit();
        var scope_as_str = try std.fmt.allocPrint(self.stack_allocator, "{}", .{self.scope_depth});
        try key_string.appendSlice(scope_as_str);
        try key_string.appendSlice(key.data.text);
        try self.variables.put(key_string.toOwnedSlice(), value);
    }
    fn builtin_if(
        self: *Stack,
        current_token_list: *std.ArrayList(parser.Token),
    ) anyerror!void {
        const clause = self.list.pop();
        const condition = self.list.pop();
        if (!self.item_is(clause, .TokenList)) {
            errors.executor_panic("'if' expected type TokenList as clause, got type ", clause.item_type);
        }
        if (!self.item_is(condition, .Number)) {
            errors.executor_panic("'if' expected type Float as condition, got type ", condition.item_type);
        }
        if (condition.data.number == 1) {
            for (clause.data.token_list) |tok| {
                try execute_single_token(tok, current_token_list, self);
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
            errors.executor_panic("'ifelse' expected type TokenList as first clause, got type ", ifclause.item_type);
        }
        if (!self.item_is(elseclause, .TokenList)) {
            errors.executor_panic("'ifelse' expected type TokenList as second clause, got type ", elseclause.item_type);
        }
        if (!self.item_is(condition, .Number)) {
            errors.executor_panic("'ifelse' expected type Number as condition, got type ", condition.item_type);
        }
        if (condition.data.number == 1) {
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
            errors.executor_panic("'while' expected type TokenList as clause, got type ", clause.item_type);
        }
        if (!self.item_is(condition, .TokenList)) {
            errors.executor_panic("'while' expected type TokenList as condition, got type ", condition.item_type);
        }
        while (true) {
            for (condition.data.token_list) |tok| {
                try execute_single_token(tok, current_token_list, self);
            }
            if (self.list.pop().data.number == 0) {
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
        if (!self.item_is(start, .Number)) {
            errors.executor_panic("'range' expected type Number as start, got type ", start.item_type);
        }
        if (!self.item_is(end, .Number)) {
            errors.executor_panic("'range' expected type Number as end, got type ", end.item_type);
        }
        var i = start.data.number;
        var number_list = std.ArrayList(StackNumberType).init(self.stack_allocator);
        while (i < end.data.number) : (i += 1) {
            try number_list.append(i);
        }
        try self.append(self.create_numberlist(number_list.toOwnedSlice()));
    }
    fn builtin_for(
        self: *Stack,
        current_token_list: *std.ArrayList(parser.Token),
    ) anyerror!void {
        const clause = self.list.pop();
        const var_name = self.list.pop();
        const list = self.list.pop();
        if (!self.item_is(clause, .TokenList)) {
            errors.executor_panic("'for' expected type TokenList as clause, got type ", clause.item_type);
        }
        if (!self.item_is(var_name, .Atom)) {
            errors.executor_panic("'for' expected type Atom as iterator variable, got type ", var_name.item_type);
        }
        if (!self.item_is(list, .NumberList)) {
            errors.executor_panic("'for' expected type NumberList as the list to iterate over, got type ", list.item_type);
        }
        switch (list.item_type) {
            .NumberList => {
                for (list.data.number_list) |fl| {
                    try self.variables.put(var_name.data.text, self.create_number(fl));
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
            .Number => {
                print("{d}", .{top.data.number});
            },
            .NumberList => {
                print("[", .{});
                for (top.data.number_list) |n| {
                    print("{d}, ", .{n});
                }
                print("]", .{});
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
        var possible_func: ?StackItem = undefined;
        possible_func = self.variables.get(name);
        dprint("Can find? {any}", .{name});
        if (possible_func) |data| {
            dprint("FOUND AS {any}", .{data});
        } else {
            dprint("NO", .{});
        }
        if (possible_func) |_| {} else {
            if (self.scope_depth != 0) {
                var key_string = std.ArrayList(u8).init(self.stack_allocator);
                defer key_string.deinit();
                var scope_as_str = try std.fmt.allocPrint(self.stack_allocator, "{}", .{self.scope_depth});
                try key_string.appendSlice(scope_as_str);
                try key_string.appendSlice(name);
                dprint("Can find LOCAL? {any}", .{key_string.items});
                const new_name = key_string.toOwnedSlice();
                possible_func = self.variables.get(new_name);
            }
            if (possible_func) |_| {} else errors.executor_panic("Unknown function ", name);
        }
        //print("FUNCITON WITH NAME {s}\n",.{name});
        if (possible_func) |function_contents| {
            switch (function_contents.item_type) {
                .TokenList => {
                    var prog_pointer: i64 = 0;
                    while (prog_pointer < function_contents.data.token_list.len) : (prog_pointer += 1) {
                        var tok = function_contents.data.token_list[@intCast(usize, prog_pointer)];
                        self.scope_depth += 1;
                        defer self.scope_depth -= 1;

                        // if (tok.id == .BuiltinReturn and self.bracket_depth != self.scope_depth) {
                        //    std.debug.print("RETURN CALLED WITH :: {} {}\n",.{self.bracket_depth, self.scope_depth});
                        // }
                        if (tok.id == .Function) {
                            if (std.mem.eql(u8, tok.data.text, name)) {
                                // Executes on recursion
                                dprint("RECURSION DETECTED\n", .{});
                                if (prog_pointer == function_contents.data.token_list.len - 1) {
                                    dprint("ASSUME TAIL CALL\n", .{});
                                    prog_pointer = -1;
                                    continue;
                                }
                            }
                        }
                        try execute_single_token(tok, current_token_list, self);
                        if (self.return_flag) {
                            self.return_flag = false;
                            return;
                        }
                    }
                },
                else => {
                    try self.append(function_contents);
                },
            }
        } else unreachable;
    }
    // fn builtin_float2int(self: *Stack) !void {
    //    const value = self.list.pop();
    //    if (!self.item_is(value, .Number)) {
    //        errors.executor_panic("float2int expected Float, got ", value.item_type);
    //    }
    //    try self.append(self.create_number(@floor(value.data.number)));
    //}

    fn append(self: *Stack, value: StackItem) !void {
        try self.list.append(value);
    }
    fn operator_plus(self: *Stack) !void {
        const a = self.list.pop();
        const b = self.list.pop();
        if (!(self.item_is(a, .Number) and self.item_is(b, .Number))) {
            errors.executor_panic("Addition operator requires two numbers, got ", .{ b.item_type, a.item_type });
        }
        try self.append(self.create_number(b.data.number + a.data.number));
    }
    fn operator_minus(self: *Stack) !void {
        const a = self.list.pop();
        const b = self.list.pop();
        if (!(self.item_is(a, .Number) and self.item_is(b, .Number))) {
            errors.executor_panic("Subtraction operator requires two numbers, got ", .{ b.item_type, a.item_type });
        }
        try self.append(self.create_number(b.data.number - a.data.number));
    }
    fn operator_divide(self: *Stack) !void {
        const a = self.list.pop();
        const b = self.list.pop();
        if (!(self.item_is(a, .Number) and self.item_is(b, .Number))) {
            errors.executor_panic("Division operator requires two numbers, got ", .{ b.item_type, a.item_type });
        }
        try self.append(self.create_number(b.data.number / a.data.number));
    }
    fn operator_multiply(self: *Stack) !void {
        const a = self.list.pop();
        const b = self.list.pop();
        if (!(self.item_is(a, .Number) and self.item_is(b, .Number))) {
            errors.executor_panic("Multiplication operator requires two numbers, got ", .{ b.item_type, a.item_type });
        }
        try self.append(self.create_number(b.data.number * a.data.number));
    }
    fn operator_modulo(self: *Stack) !void {
        const a = self.list.pop();
        const b = self.list.pop();
        if (!(self.item_is(a, .Number) and self.item_is(b, .Number))) {
            errors.executor_panic("Modulus operator requires two numbers, got ", .{ b.item_type, a.item_type });
        }
        try self.append(self.create_number(@rem(b.data.number, a.data.number)));
    }
    fn operator_eq(self: *Stack) !void {
        const a = self.list.pop();
        const b = self.list.pop();
        if (!(self.item_is(a, .Number) and self.item_is(b, .Number))) {
            errors.executor_panic("Equality operator requires two numbers, got ", .{ b.item_type, a.item_type });
        }
        try self.append(self.create_number(@intToFloat(StackNumberType, @boolToInt(b.data.number == a.data.number))));
    }
    fn operator_neq(self: *Stack) !void {
        const a = self.list.pop();
        const b = self.list.pop();
        if (!(self.item_is(a, .Number) and self.item_is(b, .Number))) {
            errors.executor_panic("Not equal to operator requires two numbers, got ", .{ b.item_type, a.item_type });
        }
        try self.append(self.create_number(@intToFloat(StackNumberType, @boolToInt(b.data.number != a.data.number))));
    }
    fn operator_lt(self: *Stack) !void {
        const a = self.list.pop();
        const b = self.list.pop();
        if (!(self.item_is(a, .Number) and self.item_is(b, .Number))) {
            errors.executor_panic("Less than requires two numbers, got ", .{ b.item_type, a.item_type });
        }
        try self.append(self.create_number(@intToFloat(StackNumberType, @boolToInt(b.data.number < a.data.number))));
    }
    fn operator_gt(self: *Stack) !void {
        const a = self.list.pop();
        const b = self.list.pop();
        if (!(self.item_is(a, .Number) and self.item_is(b, .Number))) {
            errors.executor_panic("Greater than requires two numbers, got ", .{ b.item_type, a.item_type });
        }
        try self.append(self.create_number(@intToFloat(StackNumberType, @boolToInt(b.data.number > a.data.number))));
    }
    fn operator_lteq(self: *Stack) !void {
        const a = self.list.pop();
        const b = self.list.pop();
        if (!(self.item_is(a, .Number) and self.item_is(b, .Number))) {
            errors.executor_panic("Less than or equal operator requires two numbers, got ", .{ b.item_type, a.item_type });
        }
        try self.append(self.create_number(@intToFloat(StackNumberType, @boolToInt(b.data.number <= a.data.number))));
    }
    fn operator_gteq(self: *Stack) !void {
        const a = self.list.pop();
        const b = self.list.pop();
        if (!(self.item_is(a, .Number) and self.item_is(b, .Number))) {
            errors.executor_panic("Greater than or equal operator requires two numbers, got ", .{ b.item_type, a.item_type });
        }
        try self.append(self.create_number(@intToFloat(StackNumberType, @boolToInt(b.data.number >= a.data.number))));
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
    if (stack.*.return_flag) return;
    if (stack.*.bracket_depth == 0) {
        switch (t.id) {
            .Eof => {
                return;
            },
            .PreProcUse, .Comment => unreachable,
            .BracketLeft => stack.*.bracket_depth += 1,
            .BracketRight => errors.panic("Brackets are not balanced. A left bracket must always precede a right one."),
            .Number => {
                try stack.*.append(stack.*.create_number(t.data.number));
            },
            //.BuiltinFloatToInt => {
            //    try stack.*.builtin_float2int();
            //},
            .String => {
                try stack.*.append(stack.*.create_string(t.data.text));
            },
            .Atom => {
                try stack.*.append(stack.*.create_atom(t.data.text));
            },
            .Function => {
                try stack.*.execute_function(
                    t.data.text,
                    current_token_list,
                );
            },
            .BuiltinAsType => {
                try stack.*.builtin_as_type();
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
            .BuiltinReturn => {
                stack.*.return_flag = true;
            },
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
