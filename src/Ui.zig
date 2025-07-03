const std = @import("std");
const dvui = @import("dvui");
const Engine = @import("Engine.zig");

const log = std.log.scoped(.ui);

const Ui = @This();

const Pixel = packed struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,
};

var image: [256 * 240]Pixel = blk: {
    @setEvalBranchQuota(256 * 240);
    var pixels: [256 * 240]Pixel = undefined;

    for (&pixels, 0..) |*p, i| {
        p.r = i % 255;
        p.g = i % 255 / i % 10;
        p.b = i % 255;
        p.a = 255;
    }
    break :blk pixels;
};

pub fn onDvuiInit(_: *Engine, _: ?*anyopaque) void {
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
    canvas();
    dvui.Examples.demo();
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

fn canvas() void {
    _ = dvui.image(
        @src(),
        .{
            .bytes = .{
                .pixels = .{
                    .bytes = .cast(std.mem.sliceAsBytes(&image)),
                    .width = 256,
                    .height = 240,
                },
            },
            .interpolation = .nearest,
            .name = "canvas",
        },
        .{
            .gravity_x = 0.5,
            .gravity_y = 0.5,
            .expand = .ratio,
        },
    );
}
