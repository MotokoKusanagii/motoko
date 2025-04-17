const std = @import("std");
const testing = std.testing;

pub const TestBus = struct {
    data: [64 * 1024]u8,

    pub fn read(self: TestBus, addr: u16) u8 {
        return self.data[addr];
    }
    pub fn write(self: *TestBus, addr: u16, value: u8) void {
        self.data[addr] = value;
    }

    pub fn setup(instruction: []const u8) TestBus {
        var bus = TestBus{
            .data = undefined,
        };
        @memset(&bus.data, 0xAA);

        // Set pc 0xF000
        bus.data[0xFFFC] = 0x00;
        bus.data[0xFFFD] = 0xF0;

        for (instruction, 0..) |data, index| {
            bus.data[0xF000 + index] = data;
        }

        return bus;
    }
};
