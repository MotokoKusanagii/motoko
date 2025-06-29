const std = @import("std");
const dvui = @import("dvui");
const Engine = @import("Engine.zig");

const log = std.log.scoped(.ui);

pub fn onDvuiSetup(engine: *Engine, _: ?*anyopaque) void {
    _ = engine;
    var theme = dvui.themeGet();

    //TODO: Redo from scratch
    theme.name = "Motoko Theme";
    theme.color_fill_window = .fromHex("#1a1b26"); // deep night background
    theme.color_fill = .fromHex("#24283b"); // text background (darker panel)
    theme.color_fill_control = .fromHex("#414868"); // controls (buttons etc.)
    theme.color_fill_hover = .fromHex("#565f89"); // hover state (subtle highlight)
    theme.color_fill_press = .fromHex("#7aa2f7"); // press state (blue-ish action)
    theme.color_border = .fromHex("#7dcfff"); // borders (cyan-ish)

    theme.color_text = .fromHex("#a9b1d6"); // main text (foreground)
    theme.color_text_press = .fromHex("#c0caf5"); // text when pressed
    theme.color_accent = .fromHex("#bb9af7"); // for focus (magenta keyword style)
    theme.color_err = .fromHex("#f7768e"); // error highlight

    dvui.themeSet(theme);
}

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

    if (dvui.menuItemLabel(@src(), "View", .{ .submenu = true }, .{ .expand = .none })) |r| {
        var fw = dvui.floatingMenu(@src(), .{ .from = r }, .{});
        defer fw.deinit();

        _ = dvui.checkbox(@src(), &dvui.Examples.show_demo_window, "Demo Window", .{});
    }

    dvui.label(@src(), "FPS: {d:.0}", .{dvui.FPS()}, .{ .gravity_x = 1 });
}

fn canvas(engine: *Engine) void {
    dvui.Examples.demo();
    _ = engine;
}
