const std = @import("std");
const contracts = @import("../contracts.zig");
const instruction = @import("instruction.zig");

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
        bus: *Bus,

        // Meta
        cycles_left: u8,

        pub fn init(bus: *Bus) Self {
            return .{
                .status = .init,
                .pc = 0x0000,
                .sp = 0x00,
                .a = 0x00,
                .x = 0x00,
                .y = 0x00,
                .bus = bus,
                .cycles_left = 0x00,
            };
        }

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

        pub fn clock(self: *Self) void {
            if (self.cycles_left == 0) {
                const opcode = self.readPc();
                const decode = instruction.table[opcode];

                self.cycles_left = decode.cycles;

                const c1 = decode.addr_mode(self);
                const c2 = decode.instruction(self);

                if (c1 and c2) {
                    self.cycles_left += 1;
                }
            }

            self.cycles_left -= 1;

            // Check if self.cycles is zero
            // Read instruction at self.pc
            // address mode
            // instruction
            // check extra cycle

        }

        pub fn write(self: Self, addr: u16, value: u8) void {
            self.bus.write(addr, value);
        }

        pub fn read(self: Self, addr: u16) u8 {
            return self.bus.read(addr);
        }

        /// Read ad addr pc and inc pc by 1
        pub fn readPc(self: *Self) u8 {
            const value = self.read(self.pc);
            self.pc += 1;
            return value;
        }
    };
}

pub const ActiveBus = TestBus;

const TestBus = struct {
    data: [65535]u8,

    pub fn read(self: TestBus, addr: u16) u8 {
        return self.data[addr];
    }
    pub fn write(self: *TestBus, addr: u16, value: u8) void {
        self.data[addr] = value;
    }
};

test "cpu init" {
    var bus = TestBus{
        .data = undefined,
    };
    @memset(&bus.data, 0);

    var cpu = Cpu(TestBus).init(&bus);
    cpu.write(0x00FF, 0x17);
    cpu.write(0x5978, 0x69);

    cpu.clock();

    try std.testing.expectEqual(bus.data[0x00FF], 0x17);
    try std.testing.expectEqual(bus.data[0x5978], 0x69);
}
