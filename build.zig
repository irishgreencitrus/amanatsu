const std = @import("std");
const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const compile_all = b.option(bool, "compile-all", "Compiles all supported targets") orelse false;
    const mode = b.standardReleaseOptions();

    const local_target = b.standardTargetOptions(.{});
    const linux_amd64_t = std.zig.CrossTarget{
        .cpu_arch = .x86_64,
        .os_tag = .linux,
        .abi = .gnu
    };
    const linux_aarch64_t = std.zig.CrossTarget{
        .cpu_arch = .aarch64,
        .os_tag = .linux,
        .abi = .gnu
    };
    const windows_amd64_t = std.zig.CrossTarget{
        .cpu_arch = .x86_64,
        .os_tag = .windows,
        .abi = .gnu
    };
    const windows_aarch64_t = std.zig.CrossTarget{
        .cpu_arch = .aarch64,
        .os_tag = .windows,
        .abi = .gnu
    };
    const macos_amd64_t = std.zig.CrossTarget{
        .cpu_arch = .x86_64,
        .os_tag = .macos,
        .abi = .gnu
    };
    const macos_aarch64_t = std.zig.CrossTarget{
        .cpu_arch = .aarch64,
        .os_tag = .macos,
        .abi = .gnu
    };

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const local = b.addExecutable("amanatsu", "src/main.zig");
    const linux_amd64 = b.addExecutable("amanatsu-linux-amd64", "src/main.zig");
    const linux_aarch64 = b.addExecutable("amanatsu-linux-aarch64", "src/main.zig");
    const windows_amd64 = b.addExecutable("amanatsu-windows-amd64", "src/main.zig");
    const windows_aarch64 = b.addExecutable("amanatsu-windows-aarch64", "src/main.zig");
    const macos_amd64 = b.addExecutable("amanatsu-macos-amd64", "src/main.zig");
    const macos_aarch64 = b.addExecutable("amanatsu-macos-aarch64", "src/main.zig");

    if (compile_all) {
        linux_amd64.setBuildMode(mode);
        linux_amd64.setTarget(linux_amd64_t);
        linux_amd64.install();

        linux_aarch64.setBuildMode(mode);
        linux_aarch64.setTarget(linux_aarch64_t);
        linux_aarch64.install();

        windows_amd64.setBuildMode(mode);
        windows_amd64.setTarget(windows_amd64_t);
        windows_amd64.install();

        windows_aarch64.setBuildMode(mode);
        windows_aarch64.setTarget(windows_aarch64_t);
        windows_aarch64.install();

        macos_amd64.setBuildMode(mode);
        macos_amd64.setTarget(macos_amd64_t);
        macos_amd64.install();

        macos_aarch64.setBuildMode(mode);
        macos_aarch64.setTarget(macos_aarch64_t);
        macos_aarch64.install();
    } else {
        local.setBuildMode(mode);
        local.setTarget(local_target);
        local.install();
    }

    const run_cmd = local.run();
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
