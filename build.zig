const std = @import("std");

const tests = [_][]const u8{
    "src/chip/mos_technology_6502.zig",
};

const chips = [_]struct {
    name: []const u8,
    path: []const u8,
}{
    .{
        .name = "mos_technology_6502.zig",
        .path = "chip/mos_technology_6502.zig",
    },
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zglfw = b.dependency("zglfw", .{
        .x11 = false,
    });

    const zopengl = b.dependency("zopengl", .{});

    const zgui = b.dependency("zgui", .{
        .backend = .glfw_opengl3,
        .shared = false,
        .with_implot = true,
        .target = target,
    });

    const engine_mod = b.createModule(.{
        .root_source_file = b.path("engine/Engine.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zopengl", .module = zopengl.module("root") },
            .{ .name = "zgui", .module = zgui.module("root") },
            .{ .name = "zglfw", .module = zglfw.module("root") },
        },
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "Engine", .module = engine_mod },
        },
    });

    exe_mod.linkLibrary(zglfw.artifact("glfw"));
    exe_mod.linkLibrary(zgui.artifact("imgui"));

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
