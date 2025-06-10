const std = @import("std");
const Bus = @import("Bus.zig");
const Instruction = @import("Instruction.zig");
const Mode = Instruction.Mode;

const Assembler = @This();

bus: Bus,
ptr: u16,

pub fn init(bus: Bus, start: u16) Assembler {
    return .{
        .bus = bus,
        .ptr = start,
    };
}

pub fn lda(self: *Assembler, mode: Mode, args: anytype) void {
    switch (mode) {
        .immediate => {
            self.write(0xA9);
            self.write(args[0]);
        },
        .zero_page => {
            self.write(0xA5);
            self.write(args[0]);
        },
        .zero_page_x => {
            self.write(0xB5);
            self.write(args[0]);
        },
        .absolute => {
            self.write(0xAD);
            self.write(args[0]);
            self.write(args[1]);
        },
        .absolute_x => {
            self.write(0xBD);
            self.write(args[0]);
            self.write(args[1]);
        },
        .absolute_y => {
            self.write(0xB9);
            self.write(args[0]);
            self.write(args[1]);
        },
        .indirect_x => {
            self.write(0xA1);
            self.write(args[0]);
        },
        .indirect_y => {
            self.write(0xB1);
            self.write(args[0]);
        },
        else => {},
    }
}

fn write(self: *Assembler, value: u8) void {
    self.bus.write(self.ptr, value);
    self.ptr += 1;
}
