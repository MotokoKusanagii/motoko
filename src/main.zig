const std = @import("std");
const Engine = @import("Engine.zig");
const dvui = @import("dvui");

const Ui = @import("Ui.zig");

pub const std_options: std.Options = .{
    .log_level = .debug,
    .logFn = logFn,
};

pub fn logFn(
    comptime level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    const scope_prefix = "(" ++ @tagName(scope) ++ "): ";
    const prefix = "[" ++ comptime level.asText() ++ "] " ++ scope_prefix;

    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();
    const stderr = std.io.getStdErr().writer();
    nosuspend stderr.print(prefix ++ format ++ "\n", args) catch return;
}

const log = std.log.scoped(.app);

pub fn main() !void {
    var da = std.heap.DebugAllocator(.{}).init;
    defer {
        if (da.deinit() == .leak) {
            log.err("Program exited with leaks", .{});
        }
    }

    const alloc = da.allocator();

    var engine: Engine = try .init(alloc, .{
        .width = 800,
        .height = 600,
        .title = "Motoko Emulator",
    });
    defer engine.deinit();

    try engine.registerEvent(.dvui_init, Ui.onDvuiInit, null);
    try engine.registerEvent(.draw, Ui.onDraw, null);
    try engine.run();
}
