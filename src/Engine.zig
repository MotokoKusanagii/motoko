const std = @import("std");
const dvui = @import("dvui");
const Backend = dvui.backend;
comptime {
    std.debug.assert(@hasDecl(Backend, "SDLBackend"));
}

const Engine = @This();

const log = std.log.scoped(.engine);

alloc: std.mem.Allocator,
dispatcher: Dispatcher,
width: f32,
height: f32,
title: [:0]const u8,
should_close: bool,
window: dvui.Window,

pub const WindowOptions = struct {
    width: f32,
    height: f32,
    title: [:0]const u8,
};

pub fn init(alloc: std.mem.Allocator, options: WindowOptions) !Engine {
    log.info("Initialize", .{});
    return Engine{
        .alloc = alloc,
        .dispatcher = try Dispatcher.init(alloc),
        .width = options.width,
        .height = options.height,
        .title = options.title,
        .should_close = false,
        .window = undefined,
    };
}

pub fn deinit(self: *Engine) void {
    log.info("Deinitialize", .{});
    self.dispatcher.deinit();
}

pub fn run(self: *Engine) !void {
    log.info("Starting engine loop", .{});
    self.dispatcher.dispatch(.load, .{});

    var backend = try Backend.initWindow(.{
        .allocator = self.alloc,
        .size = .{ .w = self.width, .h = self.height },
        .vsync = false,
        .title = self.title,
    });

    defer backend.deinit();

    self.window = try dvui.Window.init(@src(), self.alloc, backend.backend(), .{});
    defer self.window.deinit();

    try self.window.begin(self.window.frame_time_ns);
    self.dispatcher.dispatch(.dvui_setup, .{self});
    _ = try self.window.end(.{});

    var interrupted = false;

    while (!self.should_close) {
        const nstime = self.window.beginWait(interrupted);
        try self.window.begin(nstime);

        self.should_close = try backend.addAllEvents(&self.window);

        _ = Backend.c.SDL_SetRenderDrawColor(backend.renderer, 0, 0, 0, 255);
        _ = Backend.c.SDL_RenderClear(backend.renderer);

        self.dispatcher.dispatch(.draw, .{self});

        const end_micros = try self.window.end(.{});

        try backend.setCursor(self.window.cursorRequested());
        try backend.textInputRect(self.window.textInputRequested());

        try backend.renderPresent();

        const wait_event_micros = self.window.waitTime(end_micros, 150);
        interrupted = try backend.waitEventTimeout(wait_event_micros);
    }
    log.info("Shutting down", .{});
    self.dispatcher.dispatch(.shutdown, .{});
}

pub const Event = enum {
    load,
    dvui_setup,
    draw,
    shutdown,
    pub fn Signature(comptime event: Event) type {
        return switch (event) {
            .load => *const fn (data: ?*anyopaque) void,
            .dvui_setup => *const fn (engine: *Engine, data: ?*anyopaque) void,
            .draw => *const fn (engine: *Engine, data: ?*anyopaque) void,
            .shutdown => *const fn (data: ?*anyopaque) void,
        };
    }
};

/// Quit the application after rendering the current frame
pub fn quit(self: *Engine) void {
    self.should_close = true;
}

pub const Dispatcher = struct {
    alloc: std.mem.Allocator,
    load: std.ArrayList(Pair(.load)),
    dvui_setup: std.ArrayList(Pair(.dvui_setup)),
    draw: std.ArrayList(Pair(.draw)),
    shutdown: std.ArrayList(Pair(.shutdown)),

    pub fn init(alloc: std.mem.Allocator) !Dispatcher {
        return Dispatcher{
            .alloc = alloc,
            .load = std.ArrayList(Pair(.load)).init(alloc),
            .dvui_setup = std.ArrayList(Pair(.dvui_setup)).init(alloc),
            .draw = std.ArrayList(Pair(.draw)).init(alloc),
            .shutdown = std.ArrayList(Pair(.shutdown)).init(alloc),
        };
    }

    pub fn deinit(self: *Dispatcher) void {
        self.load.deinit();
        self.dvui_setup.deinit();
        self.draw.deinit();
        self.shutdown.deinit();
    }

    // TODO: figure out arbitrary arguments
    pub fn dispatch(self: Dispatcher, comptime event: Event, args: anytype) void {
        for (@field(self, @tagName(event)).items) |pair| {
            switch (event) {
                .load, .shutdown => pair.func(pair.data),
                .dvui_setup, .draw => pair.func(args[0], pair.data),
            }
        }
    }

    pub fn Pair(comptime event: Event) type {
        return struct {
            func: Event.Signature(event),
            data: ?*anyopaque,
        };
    }
};

pub fn registerEvent(
    self: *Engine,
    comptime event: Event,
    func: Event.Signature(event),
    data: ?*anyopaque,
) !void {
    try @field(self.dispatcher, @tagName(event)).append(Dispatcher.Pair(event){
        .func = func,
        .data = data,
    });
}
