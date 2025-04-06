const std = @import("std");
const c = @import("c.zig");
const sdl = c.sdl;

const char_size = c.SDL_DEBUG_TEXT_FONT_CHARACTER_SIZE;

pub const Level = enum(u8) {
    info = 0,
    warn = 1,
    critical = 2,
};

pub const Entry = struct {
    level: Level,
    text: [:0]const u8,
};

pub const Console = struct {
    allocator: std.mem.Allocator,

    // SDL stuff
    renderer: *c.SDL_Renderer,

    // Log Level
    comptime level: Level = .info,

    // Console stuff
    x: f32,
    y: f32,
    scale: f32,
    padding: f32,
    entries: std.ArrayList(Entry),

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
            .entries = std.ArrayList(Entry).init(allocator),
        };
    }

    pub fn deinit(self: *Console) void {
        for (self.entries.items) |entry| {
            const mutable_text = @constCast(entry.text);
            self.allocator.free(mutable_text);
        }
        self.entries.deinit();
    }

    pub fn draw(self: Console) !void {
        // TODO: Calculate how many entries can be rendered to fix potential
        // performance problems.
        var r: u8 = 0;
        var g: u8 = 0;
        var b: u8 = 0;
        var a: u8 = 0;
        var scale_x: f32 = 0;
        var scale_y: f32 = 0;
        try sdl(c.SDL_GetRenderDrawColor(self.renderer, &r, &g, &b, &a));
        try sdl(c.SDL_GetRenderScale(self.renderer, &scale_x, &scale_y));
        try sdl(c.SDL_SetRenderScale(self.renderer, self.scale, self.scale));

        var i: usize = self.entries.items.len;
        var iteration: usize = 0;
        while (i > 0) {
            i -= 1;

            const entry = self.entries.items[i];

            switch (entry.level) {
                .critical => {
                    try sdl(c.SDL_SetRenderDrawColor(
                        self.renderer,
                        255,
                        0,
                        0,
                        255,
                    ));
                    try sdl(c.SDL_RenderDebugTextFormat(
                        self.renderer,
                        self.x,
                        self.y + calcY(iteration, self.padding),
                        "Critical: %s",
                        entry.text.ptr,
                    ));
                },
                .warn => {
                    try sdl(c.SDL_SetRenderDrawColor(
                        self.renderer,
                        255,
                        128,
                        0,
                        255,
                    ));
                    try sdl(c.SDL_RenderDebugTextFormat(
                        self.renderer,
                        self.x,
                        self.y + calcY(iteration, self.padding),
                        "Warn: %s",
                        entry.text.ptr,
                    ));
                },
                .info => {
                    try sdl(c.SDL_SetRenderDrawColor(
                        self.renderer,
                        255,
                        255,
                        255,
                        255,
                    ));
                    try sdl(c.SDL_RenderDebugTextFormat(
                        self.renderer,
                        self.x,
                        self.y + calcY(iteration, self.padding),
                        "Info: %s",
                        entry.text.ptr,
                    ));
                },
            }

            iteration += 1;
        }
        try sdl(c.SDL_SetRenderDrawColor(self.renderer, r, g, b, a));
        try sdl(c.SDL_SetRenderScale(self.renderer, scale_x, scale_y));
    }

    // TODO: Discard a % of entries after reaching a specific number of entries
    // Otherwise the memory will grow unchecked.
    pub fn addEntry(self: *Console, entry: Entry) !void {
        const level_min: u8 = @intFromEnum(self.level);
        const level_num: u8 = @intFromEnum(entry.level);

        if (level_min > level_num) {
            return;
        }

        try self.entries.append(entry);
    }

    pub fn info(self: *Console, text: [:0]const u8) !void {
        try self.addEntry(.{
            .level = .info,
            .text = try self.allocator.dupeZ(u8, text),
        });
    }

    pub fn warn(self: *Console, text: [:0]const u8) !void {
        try self.addEntry(.{
            .level = .warn,
            .text = try self.allocator.dupeZ(u8, text),
        });
    }

    pub fn critical(self: *Console, text: [:0]const u8) !void {
        try self.addEntry(.{
            .level = .warn,
            .text = try self.allocator.dupeZ(u8, text),
        });
    }

    fn calcY(index: usize, padding: f32) f32 {
        return (char_size + padding) * @as(f32, @floatFromInt(index));
    }
};
