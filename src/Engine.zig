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

    var win = try dvui.Window.init(@src(), self.alloc, backend.backend(), .{});
    defer win.deinit();

    var interrupted = false;

    while (!self.should_close) {
        const nstime = win.beginWait(interrupted);
        try win.begin(nstime);

        self.should_close = try backend.addAllEvents(&win);

        _ = Backend.c.SDL_SetRenderDrawColor(backend.renderer, 0, 0, 0, 255);
        _ = Backend.c.SDL_RenderClear(backend.renderer);

        self.dispatcher.dispatch(.draw, .{self});

        const end_micros = try win.end(.{});

        try backend.setCursor(win.cursorRequested());
        try backend.textInputRect(win.textInputRequested());

        try backend.renderPresent();

        const wait_event_micros = win.waitTime(end_micros, 150);
        interrupted = try backend.waitEventTimeout(wait_event_micros);
    }
    log.info("Shutting down", .{});
    self.dispatcher.dispatch(.shutdown, .{});
}

pub const Event = enum {
    load,
    shutdown,
    draw,
    pub fn Signature(comptime event: Event) type {
        return switch (event) {
            .load => *const fn (data: ?*anyopaque) void,
            .shutdown => *const fn (data: ?*anyopaque) void,
            .draw => *const fn (engine: *Engine, data: ?*anyopaque) void,
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
    shutdown: std.ArrayList(Pair(.shutdown)),
    draw: std.ArrayList(Pair(.draw)),

    pub fn init(alloc: std.mem.Allocator) !Dispatcher {
        return .{
            .alloc = alloc,
            .load = std.ArrayList(Pair(.load)).init(alloc),
            .shutdown = std.ArrayList(Pair(.shutdown)).init(alloc),
            .draw = std.ArrayList(Pair(.draw)).init(alloc),
        };
    }

    pub fn deinit(self: *Dispatcher) void {
        self.load.deinit();
        self.shutdown.deinit();
        self.draw.deinit();
    }

    // TODO: figure out arbitrary arguments
    pub fn dispatch(self: Dispatcher, comptime event: Event, args: anytype) void {
        for (@field(self, @tagName(event)).items) |pair| {
            switch (event) {
                .load, .shutdown => pair.func(pair.data),
                .draw => pair.func(args[0], pair.data),
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
