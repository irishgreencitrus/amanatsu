const std = @import("std");

pub fn panic(message: []const u8) noreturn {
    const stderr = std.io.getStdErr().writer();
    stderr.print("\x1b[1;31mERROR: {s}\x1b[0m\n",.{message}) catch unreachable;
    std.os.exit(1);
}
pub fn lexer_panic(message: []const u8, character: [1] u8) noreturn {
    const stderr = std.io.getStdErr().writer();
    stderr.print("\x1b[1;31mERROR: {s} '{s}'\x1b[0m\n",.{message, character}) catch unreachable;
    std.os.exit(1);
}
pub fn executor_panic(message: []const u8, message2: anytype) noreturn {
    const stderr = std.io.getStdErr().writer();
    stderr.print("\x1b[1;31mERROR: {s} '{s}'\x1b[0m\n",.{message, message2}) catch unreachable;
    std.os.exit(1);
}
