const std = @import("std");

const tests = [_][]const u8{
    "src/chip/mos_technology_6502.zig",
};

const chips = [_]struct {
    name: []const u8,
    path: []const u8,
}{
    .{ .name = "mos6502", .path = "src/chip/mos_technology_6502.zig" },
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sdl_dep = b.dependency("sdl", .{
        .target = target,
        .optimize = optimize,
    });
    const sdl_lib = sdl_dep.artifact("SDL3");

    const gl_bindings = @import("zigglgen").generateBindingsModule(b, .{
        .api = .gl,
        .version = .@"4.5",
        .profile = .core,
        .extensions = &.{ .ARB_clip_control, .NV_scissor_exclusive },
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_mod.linkLibrary(sdl_lib);
    exe_mod.addImport("gl", gl_bindings);

    for (chips) |chip| {
        const chip_mod = b.createModule(.{
            .root_source_file = b.path(chip.path),
            .target = target,
            .optimize = optimize,
        });

        exe_mod.addImport(chip.name, chip_mod);
    }

    const exe = b.addExecutable(.{
        .name = "motoko",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const test_step = b.step("test", "Run unit tests");

    for (tests) |t| {
        const test_mod = b.createModule(.{
            .root_source_file = b.path(t),
            .target = target,
            .optimize = optimize,
        });

        const unit_tests = b.addTest(.{
            .root_module = test_mod,
            .target = target,
            .optimize = optimize,
        });

        const run_unit_tests = b.addRunArtifact(unit_tests);
        test_step.dependOn(&run_unit_tests.step);
    }
}
