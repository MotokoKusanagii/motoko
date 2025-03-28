const std = @import("std");
const c = @cImport({
    @cInclude("SDL3/SDL.h");
    @cDefine("SDL_MAIN_HANDLED", {});
    @cInclude("SDL3/SDL_main.h");
});

pub fn main() !void {
    std.debug.print("Hello world!\n", .{});
    c.SDL_SetMainReady();
}
