const std = @import("std");
const contracts = @import("../contracts.zig");

pub const Status = struct {
    data: u8,

    pub const init = Status{ .data = 0 };

    pub const Flags = enum(u8) {
        c = 0b00000001,
        z = 0b00000010,
        i = 0b00000100,
        d = 0b00001000,
        b = 0b00010000,
        u = 0b00100000,
        v = 0b01000000,
        n = 0b10000000,
    };

    pub fn isSet(self: Status, flag: Flags) bool {
        return self.data & @intFromEnum(flag) != 0;
    }

    pub fn set(self: *Status, comptime flag: Flags, value: bool) void {
        const flag_value = @intFromEnum(flag);
        self.data = (self.data & ~flag_value) | (flag_value * @intFromBool(value));
    }
};

const BusInterface = contracts.Interface(struct {
    pub fn read(_: @This(), addr: u16) u8 {
        _ = addr;
    }
    pub fn write(_: @This(), addr: u16, value: u8) void {
        _ = addr;
        _ = value;
    }
});

pub fn Cpu(Bus: type) type {
    BusInterface.validate(Bus);

    return struct {
        const Self = @This();

        // Register
        status: Status,
        pc: u16,
        sp: u8,
        a: u8,
        x: u8,
        y: u8,

        // Bus
        bus: ?*Bus,

        pub const init = Self{
            .status = .init,
            .pc = 0x0000,
            .sp = 0x00,
            .a = 0x00,
            .x = 0x00,
            .y = 0x00,
            .bus = null,
        };

        pub fn powerOn(self: *Self) void {
            self.a = 0;
            self.x = 0;
            self.y = 0;
            self.pc = 0xFFFC;
            self.sp = 0xFD;

            self.status = .init;
            self.status.set(.i, true);
        }

        pub fn reset(self: *Self) void {
            self.pc = 0xFFFC;
            self.sp = 0xFD;
            self.status.set(.i, true);
        }

        pub fn clock(self: Self) void {
            _ = self;
            // Check if self.cycles is zero
            // Read instruction at self.pc
            // address mode
            // instruction
            // check extra cycle

        }
    };
}

const TestBus = struct {
    pub fn read(self: TestBus, addr: u16) u8 {
        _ = self;
        _ = addr;
    }
    pub fn write(self: TestBus, addr: u16, value: u8) void {
        _ = self;
        _ = addr;
        _ = value;
    }
};

test "cpu init" {
    const cpu = Cpu(TestBus).init;
    _ = cpu;
}
