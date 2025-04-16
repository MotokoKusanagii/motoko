const std = @import("std");
const testing = std.testing;

pub const TestBus = struct {
    data: [65535]u8,

    pub fn read(self: TestBus, addr: u16) u8 {
        return self.data[addr];
    }
    pub fn write(self: *TestBus, addr: u16, value: u8) void {
        self.data[addr] = value;
    }
};
