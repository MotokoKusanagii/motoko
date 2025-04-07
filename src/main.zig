const std = @import("std");
const gl = @import("gl");
const c = @import("c.zig");
const sdl = c.sdl;

const Console = @import("ui.zig").Console;
const Cpu = @import("nes/cpu.zig").Cpu;

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
    defer {
        if (da.deinit() == .leak) {
            @panic("Errrrmmm leaks detected!");
        }
    }
    const allocator = da.allocator();

    var console = Console.init(allocator, renderer, 0, 0, 3, 5);
    defer console.deinit();
    try console.info("Console initialized.");

    main_loop: while (true) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event)) {
            switch (event.type) {
                c.SDL_EVENT_QUIT => {
                    break :main_loop;
                },
                c.SDL_EVENT_KEY_DOWN => {
                    switch (event.key.key) {
                        c.SDLK_UP => {
                            console.scale += 1;
                        },
                        c.SDLK_DOWN => {
                            console.scale -= 1;
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

test {
    _ = @import("nes/cpu.zig");
}
