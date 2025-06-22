//! Mos Technology 6502 bus interface.

const Bus = @This();

ptr: *anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    read: *const fn (*anyopaque, address: u16) u8,
    write: *const fn (*anyopaque, address: u16, value: u8) void,
};

/// Read one byte at `address`
pub fn read(bus: Bus, address: u16) u8 {
    return bus.vtable.read(bus.ptr, address);
}

/// Write `value` at `address`
pub fn write(bus: Bus, address: u16, value: u8) void {
    bus.vtable.write(bus.ptr, address, value);
}
