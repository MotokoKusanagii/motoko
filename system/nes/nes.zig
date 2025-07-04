const std = @import("std");
const Mos6502 = @import("mos_technology_6502");

const Nes = @This();

alloc: std.mem.Allocator,
cpu: Mos6502 = undefined,

pub fn init(self: *Nes, alloc: std.mem.Allocator) void {
    self.alloc = alloc;
    self.cpu = .init(self.bus());
}

pub fn startup(self: *Nes) void {
    self.cpu.reset();
}

fn read(_: *anyopaque, _: u16) u8 {}

fn write(_: *anyopaque, _: u16, _: u8) void {}

const bus_vtable: Mos6502.Bus.VTable = .{
    .read = read,
    .write = write,
};

fn bus(self: *Nes) Mos6502.Bus {
    return .{
        .ptr = self,
        .vtable = bus_vtable,
    };
}
