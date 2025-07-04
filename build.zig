const std = @import("std");

const tests = [_][]const u8{
    "chip/mos_technology_6502/mos_technology_6502.zig",
};

const chips = [_]struct {
    name: []const u8,
    path: []const u8,
}{
    .{
        .name = "mos_technology_6502",
        .path = "chip/mos_technology_6502/mos_technology_6502.zig",
    },
};

const Test = struct {};

const systems = [_]struct {
    name: []const u8,
    path: []const u8,
    chips: []const []const u8,
}{
    .{
        .name = "nes",
        .path = "system/nes/nes.zig",
        .chips = &.{
            "mos_technology_6502",
        },
    },
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const dvui = b.dependency("dvui", .{
        .target = target,
        .optimize = optimize,
        .backend = .sdl3,
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "dvui", .module = dvui.module("dvui_sdl3") },
        },
    });

    var chip_hm = std.StringHashMap(*std.Build.Module).init(b.allocator);
    defer chip_hm.deinit();

    for (chips) |chip| {
        const chip_mod = b.createModule(.{
            .root_source_file = b.path(chip.path),
            .target = target,
            .optimize = optimize,
        });

        exe_mod.addImport(chip.name, chip_mod);

        try chip_hm.put(chip.name, chip_mod);
    }

    for (systems) |system| {
        const mod = b.createModule(.{
            .root_source_file = b.path(system.path),
            .target = target,
            .optimize = optimize,
        });

        exe_mod.addImport(system.name, mod);

        for (system.chips) |chip| {
            mod.addImport(chip, chip_hm.get(chip).?);
        }
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
