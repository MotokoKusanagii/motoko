const std = @import("std");
const c = @import("c.zig");
const sdl = c.sdl;

const char_size = c.SDL_DEBUG_TEXT_FONT_CHARACTER_SIZE;

pub const Console = struct {
    allocator: std.mem.Allocator,

    // SDL stuff
    renderer: *c.SDL_Renderer,

    // Console stuff
    x: f32,
    y: f32,
    scale: f32,
    padding: f32,
    entries: std.ArrayList([:0]const u8),

    pub fn init(
        allocator: std.mem.Allocator,
        renderer: *c.SDL_Renderer,
        x: f32,
        y: f32,
        scale: f32,
        padding: f32,
    ) Console {
        return .{
            .allocator = allocator,
            .renderer = renderer,
            .x = x,
            .y = y,
            .scale = scale,
            .padding = padding,
            .entries = std.ArrayList([:0]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *Console) void {
        self.entries.deinit();
    }

    pub fn draw(self: Console) !void {
        var r: u8 = 0;
        var g: u8 = 0;
        var b: u8 = 0;
        var a: u8 = 0;
        var scale_x: f32 = 0;
        var scale_y: f32 = 0;
        try sdl(c.SDL_GetRenderDrawColor(self.renderer, &r, &g, &b, &a));
        try sdl(c.SDL_GetRenderScale(self.renderer, &scale_x, &scale_y));
        try sdl(c.SDL_SetRenderDrawColor(self.renderer, 255, 255, 255, 255));
        try sdl(c.SDL_SetRenderScale(self.renderer, self.scale, self.scale));

        var i: usize = self.entries.items.len;
        var iteration: usize = 0;
        while (i > 0) : (iteration += 1) {
            i -= 1;
            try sdl(c.SDL_RenderDebugText(
                self.renderer,
                self.x,
                self.y + calcY(iteration, self.padding),
                self.entries.items[i],
            ));
        }
        try sdl(c.SDL_SetRenderDrawColor(self.renderer, r, g, b, a));
        try sdl(c.SDL_SetRenderScale(self.renderer, scale_x, scale_y));
    }

    pub fn addEntry(self: *Console, text: [:0]const u8) !void {
        try self.entries.append(text);
    }

    fn calcY(index: usize, padding: f32) f32 {
        return (char_size + padding) * @as(f32, @floatFromInt(index));
    }
};
