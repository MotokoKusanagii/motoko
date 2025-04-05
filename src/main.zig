const std = @import("std");
const gl = @import("gl");
const c = @import("c.zig");
const Console = @import("console.zig").Console;
const sdl = c.sdl;

const text_scale = 2.5;
const char_size = c.SDL_DEBUG_TEXT_FONT_CHARACTER_SIZE;

pub fn main() !void {
    c.SDL_SetMainReady();

    try sdl(c.SDL_Init(c.SDL_INIT_VIDEO));

    const window_flags = c.SDL_WINDOW_RESIZABLE;
    const window: *c.SDL_Window = try sdl(c.SDL_CreateWindow("Motoko", 800, 400, window_flags));
    defer c.SDL_DestroyWindow(window);
    const renderer: *c.SDL_Renderer = try sdl(c.SDL_CreateRenderer(window, null));
    defer c.SDL_DestroyRenderer(renderer);

    var da = std.heap.DebugAllocator(.{}).init;
    const allocator = da.allocator();

    var console = Console.init(allocator, renderer, 0, 0, 2, 5);
    defer console.deinit();

    main_loop: while (true) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event)) {
            switch (event.type) {
                c.SDL_EVENT_QUIT => {
                    break :main_loop;
                },
                c.SDL_EVENT_KEY_DOWN => {
                    switch (event.key.key) {
                        c.SDLK_A => {
                            try console.addEntry("this is an entry");
                        },
                        c.SDLK_D => {
                            try console.addEntry("another entry");
                        },
                        else => {},
                    }
                },
                else => {},
            }
        }

        try sdl(c.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255));
        try sdl(c.SDL_RenderClear(renderer));

        // Text
        try console.draw();

        try sdl(c.SDL_SetRenderScale(renderer, 1, 1));
        try sdl(c.SDL_RenderPresent(renderer));
    }
}
