const std = @import("std");
const glfw = @import("zglfw");
const opengl = @import("zopengl");
const gui = @import("zgui");

const mos6502 = @import("mos6502");
const asm_test = @embedFile("test.s");

pub fn main() !void {
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

    const window = try glfw.Window.create(800, 600, "Motoko Emulator", null);
    defer window.destroy();

    glfw.makeContextCurrent(window);

    try opengl.loadCoreProfile(glfw.getProcAddress, gl_major, gl_minor);

    const gl = opengl.bindings;

    glfw.swapInterval(1);

    var da = std.heap.GeneralPurposeAllocator(.{}).init;
    const allocator = da.allocator();

    gui.init(allocator);
    defer gui.deinit();

    gui.backend.init(window);
    defer gui.backend.deinit();

    var bus = mos6502.TestBus.setup(&.{});

    try mos6502.parser.parse(allocator, asm_test, bus.bus());

    var chip = mos6502.Chip.init(bus.bus());
    chip.powerOn();

    while (!window.shouldClose()) {
        glfw.pollEvents();

        // GL
        gl.clearBufferfv(gl.COLOR, 0, &[_]f32{ 0.102, 0.106, 0.149, 1.0 });

        // GUI
        const fb_size = window.getFramebufferSize();
        gui.backend.newFrame(@intCast(fb_size[0]), @intCast(fb_size[1]));

        if (gui.begin("Emulator", .{})) {
            if (gui.button("Test!", .{ .w = 200 })) {
                std.debug.print("Test!\n", .{});
            }
            if (gui.button("clock", .{ .w = 200 })) {
                chip.clock();
            }
            if (gui.button("reset", .{ .w = 200 })) {
                chip.reset();
            }
            gui.text("Register: ", .{});

            gui.text("A: {X}, X: {X}, Y: {X}", .{ chip.a, chip.x, chip.y });
            gui.text("PC: {X}, SP: {X}", .{ chip.pc, chip.sp });
            gui.text("(PC): {X}", .{chip.read(chip.pc)});
            gui.text("Status: {b:0>8}", .{chip.status.data});
            gui.text("cycles left: {x}", .{chip.cycles_left});
            gui.spacing();

            var buffer: [30]u8 = undefined;
            gui.text("Instruction: {s}", .{try mos6502.bufPrintCurInstr(chip, &buffer)});
        }
        gui.end();

        gui.backend.draw();

        window.swapBuffers();
    }
}
