const std = @import("std");

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

pub const Cpu = struct {
    // Register
    status: Status,
    pc: u16,
    sp: u8,
    a: u8,
    x: u8,
    y: u8,

    pub const init = Cpu{
        .status = .init,
        .pc = 0x0000,
        .sp = 0x00,
        .a = 0x00,
        .x = 0x00,
        .y = 0x00,
    };

    pub fn powerOn(self: *Cpu) void {
        self.a = 0;
        self.x = 0;
        self.y = 0;
        self.pc = 0xFFFC;
        self.sp = 0xFD;

        self.status = .init;
        self.status.set(.i, true);
    }

    pub fn reset(self: *Cpu) void {
        self.pc = 0xFFFC;
        self.sp = 0xFD;
        self.status.set(.i, true);
    }
};
