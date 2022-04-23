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

pub fn print(comptime format: []const u8, args: anytype) void {
    const stdout = std.io.getStdOut().writer();
    nosuspend stdout.print(format, args) catch return;
}

pub fn execute(alloc: std.mem.Allocator, tokens: []const parser.Token) anyerror!void {
    var stack = Stack{};
    try stack.init(alloc);
    for (tokens) |t| {
        try stack.execute_single_token(t);
    }
}

// Everything beyond this is part of the `Stack` struct
const Stack = @This();

list: std.ArrayList(StackItem) = undefined,

variables: std.StringHashMap(StackItem) = undefined,

stack_allocator: std.mem.Allocator = undefined,

current_bracket_tokens: std.ArrayList(parser.Token) = undefined,
bracket_depth: u64 = 0,
scope_depth: u64 = 0,

return_flag: bool = false,

fn init(self: *Stack, alloc: std.mem.Allocator) !void {
    self.stack_allocator = alloc;
    self.list = try std.ArrayList(StackItem).initCapacity(alloc, 1024);
    self.variables = std.StringHashMap(StackItem).init(alloc);
    self.current_bracket_tokens = std.ArrayList(parser.Token).init(alloc);
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
    const functions = std.ComptimeStringMap(StackType, .{
        .{ "Atom", .Atom },
        .{ "String", .String },
        .{ "Number", .Number },
        .{ "TokenList", .TokenList },
        .{ "NumberList", .NumberList },
    });
    return functions.get(atom.data.text) orelse null;
}
fn execute_function(
    self: *Stack,
    name: []const u8,
) anyerror!void {
    var possible_func: ?StackItem = undefined;
    // Try find a global variable. This is simple as the name is not mangled.
    possible_func = self.variables.get(name);
    if (possible_func) |_| {} else {
        if (self.scope_depth != 0) { // We can't have a local variable if we are in the global scope
            // Try find a local variable.
            // This is more complex as we need to modify the name by adding the scope_depth to the start
            var key_string = std.ArrayList(u8).init(self.stack_allocator);
            defer key_string.deinit();

            var scope_as_str = try std.fmt.allocPrint(self.stack_allocator, "{}", .{self.scope_depth});
            try key_string.appendSlice(scope_as_str); // Put the scope depth on the buffer first
            try key_string.appendSlice(name); // And then the actual function name
            const new_name = key_string.toOwnedSlice();
            possible_func = self.variables.get(new_name);
        }
        if (possible_func) |_| {} else errors.executor_panic("Unknown function ", name); // Still don't have a function? Then it doesn't exist.
    }
    if (possible_func) |function_contents| {
        switch (function_contents.item_type) {
            .TokenList => {
                var prog_pointer: i64 = 0;
                // We loop like this so we can modify the `prog_pointer` and can jump back to the beginning of the function if and when we need to.
                while (prog_pointer < function_contents.data.token_list.len) : (prog_pointer += 1) {
                    var tok = function_contents.data.token_list[@intCast(usize, prog_pointer)];
                    self.scope_depth += 1;
                    defer self.scope_depth -= 1;

                    if (tok.id == .Function) {
                        if (std.mem.eql(u8, tok.data.text, name)) {
                            // Executes on recursion
                            if (prog_pointer == function_contents.data.token_list.len - 1) {
                                // Executes on some forms of tail call recursion where the function name is the exact last token
                                prog_pointer = -1; // The for loop still increments by 1 so we need this to reset the prog_pointer to 0
                                continue;
                            }
                        }
                    }
                    try self.execute_single_token(tok);
                    if (self.return_flag) {
                        // If self.return_flag is active, the `return` keyword was used somewhere in the function which ignores all instructions after it is called.
                        // This needs to be reset before calling another function.
                        self.return_flag = false;
                        return;
                    }
                }
            },
            else => {
                // If it is not a TokenList, we don't need to bother looping as there is only one possible thing that can happen.
                try self.append(function_contents);
            },
        }
    } else unreachable;
}
fn append(self: *Stack, value: StackItem) !void {
    try self.list.append(value);
}
// Bracket Depth tells us if we're inside a quote
// Scope Depth tells us if we're executing a quote
fn execute_single_token(
    self: *Stack,
    t: parser.Token,
) !void {
    if (self.return_flag) return;
    if (self.bracket_depth == 0) {
        switch (t.id) {
            .Eof => {
                return;
            },
            .PreProcUse, .Comment => unreachable,
            .BracketLeft => self.bracket_depth += 1,
            .BracketRight => errors.panic("Brackets are not balanced. A left bracket must always precede a right one."),
            .Number => try self.append(self.create_number(t.data.number)),
            .String => try self.append(self.create_string(t.data.text)),
            .Atom => try self.append(self.create_atom(t.data.text)),
            .Function => try self.execute_function(t.data.text),
            // zig fmt: off
            .BuiltinAsType              => try self.builtin_as_type(),
            .BuiltinDefine              => try self.builtin_define(),
            .BuiltinDup                 => try self.builtin_dup(),
            .BuiltinFor                 => try self.builtin_for(),
            .BuiltinIf                  => try self.builtin_if(),
            .BuiltinIfElse              => try self.builtin_ifelse(),
            .BuiltinLocalDefine         => try self.builtin_local_define(),
            .BuiltinPrint               => try self.builtin_print(),
            .BuiltinRange               => try self.builtin_range(),
            .BuiltinSwap                => try self.builtin_swap(),
            .BuiltinWhile               => try self.builtin_while(),
            .OperatorDivide             => try self.operator_divide(),
            .OperatorEqual              => try self.operator_eq(),
            .OperatorGreaterThan        => try self.operator_gt(),
            .OperatorGreaterThanOrEqual => try self.operator_gteq(),
            .OperatorLessThan           => try self.operator_lt(),
            .OperatorLessThanOrEqual    => try self.operator_lteq(),
            .OperatorMinus              => try self.operator_minus(),
            .OperatorModulo             => try self.operator_modulo(),
            .OperatorMultiply           => try self.operator_multiply(),
            .OperatorNotEqual           => try self.operator_neq(),
            .OperatorPlus               => try self.operator_plus(),
            // zig fmt: on
            .BuiltinRequireStack => {},
            .BuiltinReturn => self.return_flag = true,
        }
    } else {
        switch (t.id) {
            .BracketLeft => {
                self.bracket_depth += 1;
                try self.current_bracket_tokens.append(t);
            },
            .BracketRight => {
                self.bracket_depth -= 1;
                if (self.bracket_depth == 0) {
                    try self.append(StackItem{
                        .item_type = .TokenList,
                        .data = .{
                            .token_list = self.current_bracket_tokens.toOwnedSlice(),
                        },
                    });
                } else {
                    try self.current_bracket_tokens.append(t);
                }
            },
            else => {
                try self.current_bracket_tokens.append(t);
            },
        }
    }
}

fn builtin_as_type(stack: *Stack) !void {
    // Converting types to other types.
    // This is a complex process as there are a lot of branches.
    const result_type_atom = stack.list.pop();
    const to_convert = stack.list.pop();
    if (!stack.item_is(result_type_atom, .Atom)) {
        errors.executor_panic("'as_type' expected type Atom as resulting type, got type ", result_type_atom.item_type);
    }
    const result_type = stack.atom_to_type(result_type_atom) orelse
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
            .String => result = stack.create_string(to_convert.data.text),
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
                    if (!@import("lexer.zig").isIdentifier(n)) { // We may as well use the lexer function here, because it saves us writing another function just for the executor
                        errors.panic("Failed to convert type String to Atom. String does not conform to Atom naming requirements.");
                    }
                }
                result = stack.create_atom(to_convert.data.text);
            },
            .Number => {
                result = stack.create_number(std.fmt.parseFloat(StackNumberType, to_convert.data.text) catch errors.panic("Failed to convert type String to Number. String is not a valid Number"));
            },
            .NumberList => {
                // Strings are converted to `NumberList`s as the ASCII codes of their values.
                var number_list = std.ArrayList(StackNumberType).init(stack.stack_allocator);
                for (to_convert.data.text) |n| {
                    try number_list.append(@intToFloat(StackNumberType, n));
                }
                result = stack.create_numberlist(number_list.toOwnedSlice());
            },
            else => {},
        },
        .Number => switch (result_type) {
            .String => result = stack.create_string(try std.fmt.allocPrint(stack.stack_allocator, "{d}", .{to_convert.data.number})),
            else => {},
        },
        .TokenList => switch (result_type) {
            .NumberList => {
                // `TokenList`s are converted to `NumberList`s if they only contain `Number` tokens.
                var number_list = std.ArrayList(StackNumberType).init(stack.stack_allocator);
                for (to_convert.data.token_list) |t| {
                    if (t.id != .Number) errors.panic("Failed to convert type TokenList to NumberList. List contains more than just numbers");
                    try number_list.append(t.data.number);
                }
                result = stack.create_numberlist(number_list.toOwnedSlice());
            },
            else => {},
        },
        .NumberList => switch (result_type) {
            .TokenList => {
                // NumberLists are always converted back to TokenLists properly (unless something like OOM occurs in which case we cannot do anything reasonable and panic)
                var token_list = std.ArrayList(parser.Token).init(stack.stack_allocator);
                for (to_convert.data.number_list) |num| {
                    try token_list.append(parser.Token{ .id = .Number, .start = 0, .data = .{ .number = num } });
                }
                result = StackItem{ .item_type = .TokenList, .data = .{ .token_list = token_list.toOwnedSlice() } };
            },
            else => {},
        },
    }
    if (result) |r| {
        try stack.list.append(r);
    } else {
        errors.executor_panic("Unable to convert types ", .{ current_type, result_type });
    }
}
fn builtin_define(stack: *Stack) !void {
    // This function uses the keyword `global` but I'm not sure if I'm a fan so this may be converted back to the keyword `define` at some later date.
    // Either that or `define` becomes global in global scope and local in local scope
    const value = stack.list.pop();
    const key = stack.list.pop();
    if (!stack.item_is(key, .Atom)) {
        errors.executor_panic("'define' expected type Atom as key, got type ", key.item_type);
    }
    // Defines a global variable. Will overwrite.
    try stack.variables.put(try stack.stack_allocator.dupe(u8, key.data.text), value);
}
fn builtin_local_define(stack: *Stack) !void {
    if (stack.scope_depth == 0) { // If we are in global scope
        errors.panic("'local' only valid inside functions.");
    }
    const value = stack.list.pop();
    const key = stack.list.pop();
    if (!stack.item_is(key, .Atom)) {
        errors.executor_panic("'local' expected type Atom as key, got type ", key.item_type);
    }
    // Mangles the name to add the scope value before the actual function name.
    // We do this to allow functions to not overwrite global scope variables (but shadowing may become an error soon)
    // as well as making functions lower down the call stack not overwrite ones higher up the call stack.
    // Because functions are variables you are allowed to have local functions which are not exposed globally.
    var key_string = std.ArrayList(u8).init(stack.stack_allocator);
    defer key_string.deinit();
    var scope_as_str = try std.fmt.allocPrint(stack.stack_allocator, "{}", .{stack.scope_depth});
    try key_string.appendSlice(scope_as_str);
    try key_string.appendSlice(key.data.text);
    try stack.variables.put(key_string.toOwnedSlice(), value);
}
fn builtin_if(stack: *Stack) anyerror!void {
    const clause = stack.list.pop();
    const condition = stack.list.pop();
    if (!stack.item_is(clause, .TokenList)) {
        errors.executor_panic("'if' expected type TokenList as clause, got type ", clause.item_type);
    }
    if (!stack.item_is(condition, .Number)) {
        errors.executor_panic("'if' expected type Float as condition, got type ", condition.item_type);
    }
    if (condition.data.number == 1) { // There are no booleans so `1` is effectively `true` and any other number is false
        for (clause.data.token_list) |tok| {
            try stack.execute_single_token(tok);
        }
    }
}
fn builtin_ifelse(stack: *Stack) anyerror!void {
    const elseclause = stack.list.pop();
    const ifclause = stack.list.pop();
    const condition = stack.list.pop();
    if (!stack.item_is(ifclause, .TokenList)) {
        errors.executor_panic("'ifelse' expected type TokenList as first clause, got type ", ifclause.item_type);
    }
    if (!stack.item_is(elseclause, .TokenList)) {
        errors.executor_panic("'ifelse' expected type TokenList as second clause, got type ", elseclause.item_type);
    }
    if (!stack.item_is(condition, .Number)) {
        errors.executor_panic("'ifelse' expected type Number as condition, got type ", condition.item_type);
    }
    if (condition.data.number == 1) {
        for (ifclause.data.token_list) |tok| {
            try stack.execute_single_token(tok);
        }
    } else {
        for (elseclause.data.token_list) |tok| {
            try stack.execute_single_token(tok);
        }
    }
}
fn builtin_while(stack: *Stack) anyerror!void {
    const clause = stack.list.pop();
    const condition = stack.list.pop();
    if (!stack.item_is(clause, .TokenList)) {
        errors.executor_panic("'while' expected type TokenList as clause, got type ", clause.item_type);
    }
    if (!stack.item_is(condition, .TokenList)) {
        errors.executor_panic("'while' expected type TokenList as condition, got type ", condition.item_type);
    }
    while (true) {
        for (condition.data.token_list) |tok| {
            try stack.execute_single_token(tok);
        }
        if (stack.list.pop().data.number == 0) {
            break;
        }
        for (clause.data.token_list) |tok| {
            try stack.execute_single_token(tok);
        }
    }
}
fn builtin_range(stack: *Stack) !void {
    const end = stack.list.pop();
    const start = stack.list.pop();
    if (!stack.item_is(start, .Number)) {
        errors.executor_panic("'range' expected type Number as start, got type ", start.item_type);
    }
    if (!stack.item_is(end, .Number)) {
        errors.executor_panic("'range' expected type Number as end, got type ", end.item_type);
    }
    var i = start.data.number;
    var number_list = std.ArrayList(StackNumberType).init(stack.stack_allocator);
    while (i < end.data.number) : (i += 1) {
        try number_list.append(i);
    }
    try stack.append(stack.create_numberlist(number_list.toOwnedSlice()));
}
fn builtin_for(stack: *Stack) anyerror!void {
    const clause = stack.list.pop();
    const var_name = stack.list.pop();
    const list = stack.list.pop();
    if (!stack.item_is(clause, .TokenList)) {
        errors.executor_panic("'for' expected type TokenList as clause, got type ", clause.item_type);
    }
    if (!stack.item_is(var_name, .Atom)) {
        errors.executor_panic("'for' expected type Atom as iterator variable, got type ", var_name.item_type);
    }
    if (!stack.item_is(list, .NumberList)) {
        errors.executor_panic("'for' expected type NumberList as the list to iterate over, got type ", list.item_type);
    }
    switch (list.item_type) {
        .NumberList => {
            for (list.data.number_list) |fl| {
                try stack.variables.put(var_name.data.text, stack.create_number(fl));
                for (clause.data.token_list) |tok| {
                    try stack.execute_single_token(tok);
                }
            }
        },
        else => unreachable,
    }
}
fn builtin_print(stack: *Stack) !void {
    const top = stack.list.pop();
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
fn builtin_dup(stack: *Stack) !void {
    const top = stack.list.pop();
    try stack.append(top);
    try stack.append(top);
}
fn builtin_swap(stack: *Stack) !void {
    const a = stack.list.pop();
    const b = stack.list.pop();
    try stack.append(a);
    try stack.append(b);
}
//
// Arithmetic Operators
//
fn operator_plus(stack: *Stack) !void {
    const a = stack.list.pop();
    const b = stack.list.pop();
    if (!(stack.item_is(a, .Number) and stack.item_is(b, .Number))) {
        errors.executor_panic("Addition operator requires two numbers, got ", .{ b.item_type, a.item_type });
    }
    try stack.append(stack.create_number(b.data.number + a.data.number));
}
fn operator_minus(stack: *Stack) !void {
    const a = stack.list.pop();
    const b = stack.list.pop();
    if (!(stack.item_is(a, .Number) and stack.item_is(b, .Number))) {
        errors.executor_panic("Subtraction operator requires two numbers, got ", .{ b.item_type, a.item_type });
    }
    try stack.append(stack.create_number(b.data.number - a.data.number));
}
fn operator_divide(stack: *Stack) !void {
    const a = stack.list.pop();
    const b = stack.list.pop();
    if (!(stack.item_is(a, .Number) and stack.item_is(b, .Number))) {
        errors.executor_panic("Division operator requires two numbers, got ", .{ b.item_type, a.item_type });
    }
    try stack.append(stack.create_number(b.data.number / a.data.number));
}
fn operator_multiply(stack: *Stack) !void {
    const a = stack.list.pop();
    const b = stack.list.pop();
    if (!(stack.item_is(a, .Number) and stack.item_is(b, .Number))) {
        errors.executor_panic("Multiplication operator requires two numbers, got ", .{ b.item_type, a.item_type });
    }
    try stack.append(stack.create_number(b.data.number * a.data.number));
}
fn operator_modulo(stack: *Stack) !void {
    const a = stack.list.pop();
    const b = stack.list.pop();
    if (!(stack.item_is(a, .Number) and stack.item_is(b, .Number))) {
        errors.executor_panic("Modulus operator requires two numbers, got ", .{ b.item_type, a.item_type });
    }
    try stack.append(stack.create_number(@rem(b.data.number, a.data.number)));
}
//
// Boolean Operators
//
fn operator_eq(stack: *Stack) !void {
    const a = stack.list.pop();
    const b = stack.list.pop();
    if (!(stack.item_is(a, .Number) and stack.item_is(b, .Number))) {
        errors.executor_panic("Equality operator requires two numbers, got ", .{ b.item_type, a.item_type });
    }
    try stack.append(stack.create_number(@intToFloat(StackNumberType, @boolToInt(b.data.number == a.data.number))));
}
fn operator_neq(stack: *Stack) !void {
    const a = stack.list.pop();
    const b = stack.list.pop();
    if (!(stack.item_is(a, .Number) and stack.item_is(b, .Number))) {
        errors.executor_panic("Not equal to operator requires two numbers, got ", .{ b.item_type, a.item_type });
    }
    try stack.append(stack.create_number(@intToFloat(StackNumberType, @boolToInt(b.data.number != a.data.number))));
}
fn operator_lt(stack: *Stack) !void {
    const a = stack.list.pop();
    const b = stack.list.pop();
    if (!(stack.item_is(a, .Number) and stack.item_is(b, .Number))) {
        errors.executor_panic("Less than requires two numbers, got ", .{ b.item_type, a.item_type });
    }
    try stack.append(stack.create_number(@intToFloat(StackNumberType, @boolToInt(b.data.number < a.data.number))));
}
fn operator_gt(stack: *Stack) !void {
    const a = stack.list.pop();
    const b = stack.list.pop();
    if (!(stack.item_is(a, .Number) and stack.item_is(b, .Number))) {
        errors.executor_panic("Greater than requires two numbers, got ", .{ b.item_type, a.item_type });
    }
    try stack.append(stack.create_number(@intToFloat(StackNumberType, @boolToInt(b.data.number > a.data.number))));
}
fn operator_lteq(stack: *Stack) !void {
    const a = stack.list.pop();
    const b = stack.list.pop();
    if (!(stack.item_is(a, .Number) and stack.item_is(b, .Number))) {
        errors.executor_panic("Less than or equal operator requires two numbers, got ", .{ b.item_type, a.item_type });
    }
    try stack.append(stack.create_number(@intToFloat(StackNumberType, @boolToInt(b.data.number <= a.data.number))));
}
fn operator_gteq(stack: *Stack) !void {
    const a = stack.list.pop();
    const b = stack.list.pop();
    if (!(stack.item_is(a, .Number) and stack.item_is(b, .Number))) {
        errors.executor_panic("Greater than or equal operator requires two numbers, got ", .{ b.item_type, a.item_type });
    }
    try stack.append(stack.create_number(@intToFloat(StackNumberType, @boolToInt(b.data.number >= a.data.number))));
}
// TODO bitwise operations but that may require an int type
