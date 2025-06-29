const std = @import("std");
const dvui = @import("dvui");
const Engine = @import("Engine.zig");

const log = std.log.scoped(.ui);

pub fn onDraw(engine: *Engine, _: ?*anyopaque) void {
    menu(engine);
    canvas(engine);
}

fn menu(engine: *Engine) void {
    var m = dvui.menu(@src(), .horizontal, .{ .background = true, .expand = .horizontal });
    defer m.deinit();

    if (dvui.menuItemLabel(@src(), "Motoko", .{ .submenu = true }, .{ .expand = .none })) |r| {
        var fw = dvui.floatingMenu(@src(), .{ .from = r }, .{});
        defer fw.deinit();

        if (dvui.menuItemLabel(@src(), "Quit", .{}, .{}) != null) {
            m.close();
            engine.quit();
        }
    }

    dvui.label(@src(), "FPS: {d:.0}", .{dvui.FPS()}, .{ .gravity_x = 1 });
}

fn canvas(engine: *Engine) void {
    _ = engine;
}
