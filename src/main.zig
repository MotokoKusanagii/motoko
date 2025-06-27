const std = @import("std");
const Engine = @import("Engine");

pub const std_options: std.Options = .{
    .log_level = .info,
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

const Data = struct {
    int: u32,
};

fn boot(data_opaque: *anyopaque) void {
    const data: *Data = @ptrCast(@alignCast(data_opaque));
    log.info("Boot was called with value: {d}", .{data.int});
    data.int = 30;
}

pub fn main() !void {
    var da = std.heap.DebugAllocator(.{}).init;
    defer {
        if (da.deinit() == .leak) {
            log.err("Program exited with leaks", .{});
        }
    }

    var data: Data = .{
        .int = 42,
    };

    const alloc = da.allocator();

    var engine: Engine = try .init(alloc, .{
        .width = 800,
        .height = 600,
        .title = "Motoko Emulator",
    });
    defer engine.deinit();

    try engine.registerEvent(.boot, boot, &data);
    try engine.run();
}
