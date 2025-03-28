const std = @import("std");
const gl = @import("gl");
const c = @import("c.zig");
const sdl = c.sdl;

pub fn main() !void {
    c.SDL_SetMainReady();
}
