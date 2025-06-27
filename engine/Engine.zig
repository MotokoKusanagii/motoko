const std = @import("std");
const glfw = @import("zglfw");
const opengl = @import("zopengl");

const Engine = @This();

const gl = opengl.bindings;

const log = std.log.scoped(.engine);

alloc: std.mem.Allocator,
dispatcher: Dispatcher,
width: i32,
height: i32,
title: [:0]const u8,

pub const WindowOptions = struct {
    width: i32,
    height: i32,
    title: [:0]const u8,
};

pub fn init(alloc: std.mem.Allocator, options: WindowOptions) !Engine {
    log.info("Initialize", .{});
    return .{
        .alloc = alloc,
        .dispatcher = try Dispatcher.init(alloc),
        .width = options.width,
        .height = options.height,
        .title = options.title,
    };
}

pub fn deinit(self: *Engine) void {
    log.info("Deinitialize", .{});
    self.dispatcher.deinit();
}

pub fn run(self: Engine) !void {
    log.info("Starting engine loop", .{});
    self.dispatcher.dispatch(.boot);

    try glfw.init();
    defer glfw.terminate();

    const gl_major = 4;
    const gl_minor = 0;
    glfw.windowHint(.context_version_major, gl_major);
    glfw.windowHint(.context_version_minor, gl_minor);
    glfw.windowHint(.opengl_profile, .opengl_core_profile);
    glfw.windowHint(.opengl_forward_compat, true);
    glfw.windowHint(.client_api, .opengl_api);
    glfw.windowHint(.doublebuffer, true);

    const window = try glfw.Window.create(
        self.width,
        self.height,
        self.title,
        null,
    );
    defer window.destroy();

    glfw.makeContextCurrent(window);

    try opengl.loadCoreProfile(glfw.getProcAddress, gl_major, gl_minor);

    glfw.swapInterval(1);

    while (!window.shouldClose()) {
        glfw.pollEvents();

        self.dispatcher.dispatch(.tick);

        gl.clearBufferfv(gl.COLOR, 0, &[_]f32{ 0.102, 0.106, 0.149, 1.0 });

        window.swapBuffers();
    }
    log.info("Shutting down", .{});
    self.dispatcher.dispatch(.shutdown);
}

pub const Event = enum {
    boot,
    shutdown,
    tick,
    pub fn Signature(comptime event: Event) type {
        return switch (event) {
            .boot => *const fn (data: *anyopaque) void,
            .shutdown => *const fn (data: *anyopaque) void,
            .tick => *const fn (data: *anyopaque) void,
        };
    }
};

pub const Dispatcher = struct {
    alloc: std.mem.Allocator,
    boot: std.ArrayList(Pair(.boot)),
    shutdown: std.ArrayList(Pair(.shutdown)),
    tick: std.ArrayList(Pair(.tick)),

    pub fn init(alloc: std.mem.Allocator) !Dispatcher {
        return .{
            .alloc = alloc,
            .boot = std.ArrayList(Pair(.boot)).init(alloc),
            .shutdown = std.ArrayList(Pair(.shutdown)).init(alloc),
            .tick = std.ArrayList(Pair(.tick)).init(alloc),
        };
    }

    pub fn deinit(self: *Dispatcher) void {
        self.boot.deinit();
        self.shutdown.deinit();
        self.tick.deinit();
    }

    pub fn dispatch(self: Dispatcher, comptime event: Event) void {
        for (@field(self, @tagName(event)).items) |pair| {
            pair.func(pair.data);
        }
    }

    pub fn Pair(comptime event: Event) type {
        return struct {
            func: Event.Signature(event),
            data: *anyopaque,
        };
    }
};

pub fn registerEvent(
    self: *Engine,
    comptime event: Event,
    func: Event.Signature(event),
    data: *anyopaque,
) !void {
    try @field(self.dispatcher, @tagName(event)).append(Dispatcher.Pair(event){
        .func = func,
        .data = data,
    });
}
