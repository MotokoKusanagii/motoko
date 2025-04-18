const std = @import("std");
const contracts = @import("contracts");
const instructions = @import("mos_technology_6502/instructions.zig");
const TestBus = @import("mos_technology_6502/testing.zig").TestBus;

const BusInterface = contracts.Interface(struct {
    pub fn read(_: @This(), addr: u16) u8 {
        _ = addr;
    }
    pub fn write(_: @This(), addr: u16, value: u8) void {
        _ = addr;
        _ = value;
    }
});

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
        const mask = @intFromEnum(flag);
        if (value) {
            self.data |= mask;
        } else {
            self.data &= ~mask;
        }
    }
};

pub const Instruction = struct {
    pub const Type = enum {
        // Access
        lda,
        sta,
        // TODO: ldx,
        // TODO: stx,
        // TODO: ldy,
        // TODO: sty,
        // Transfer
        // TODO: tax,
        // TODO: txa,
        // TODO: tay,
        // TODO: tya,
        // Jump
        jmp,
        jsr,
        rts,
        brk,
        rti,
        // Stack
        pha,
        pla,
        php,
        plp,
        txs,
        tsx,
        // Flags
        clc,
        sec,
        cli,
        sei,
        cld,
        sed,
        clv,
        // Other
        nop,
        unknown,
    };

    pub const Mode = enum {
        implied,
        immediate,
        zero_page,
        zero_page_x,
        absolute,
        absolute_x,
        absolute_y,
        indirect,
        indirect_x,
        indirect_y,
        unknown,
    };

    type: Type = .unknown,
    mode: Mode = .unknown,
    cycles: u8,

    pub fn run(self: Instruction, comptime CpuT: type, cpu: *CpuT) bool {
        const address_return = switch (self.mode) {
            .implied => instructions.implied(cpu),
            .immediate => instructions.immediate(cpu),
            .zero_page => instructions.zeroPage(cpu),
            .zero_page_x => instructions.zeroPageX(cpu),
            .absolute => instructions.absolute(cpu),
            .absolute_x => instructions.absoluteX(cpu),
            .absolute_y => instructions.absoluteY(cpu),
            .indirect => instructions.indirect(cpu),
            .indirect_x => instructions.indirectX(cpu),
            .indirect_y => instructions.indirectY(cpu),
            .unknown => instructions.address_unknown(cpu),
        };

        return switch (self.type) {
            .lda => instructions.lda(cpu, address_return),
            .sta => instructions.sta(cpu, address_return),
            .jmp => instructions.jmp(cpu, address_return),
            .jsr => instructions.jsr(cpu, address_return),
            .rts => instructions.rts(cpu, address_return),
            .brk => instructions.brk(cpu, address_return),
            .rti => instructions.rti(cpu, address_return),
            .pha => instructions.pha(cpu, address_return),
            .pla => instructions.pla(cpu, address_return),
            .php => instructions.php(cpu, address_return),
            .plp => instructions.plp(cpu, address_return),
            .txs => instructions.txs(cpu, address_return),
            .tsx => instructions.tsx(cpu, address_return),
            .clc => instructions.clc(cpu, address_return),
            .sec => instructions.sec(cpu, address_return),
            .cli => instructions.cli(cpu, address_return),
            .sei => instructions.sei(cpu, address_return),
            .cld => instructions.cld(cpu, address_return),
            .sed => instructions.sed(cpu, address_return),
            .clv => instructions.clv(cpu, address_return),
            .nop => instructions.nop(cpu, address_return),
            .unknown => instructions.type_unknown(cpu, address_return),
        };
    }

    pub fn decode(opcode: u8) Instruction {
        return switch (opcode) {
            0x00 => .{
                .type = .brk,
                .mode = .implied,
                .cycles = 7,
            },
            0x08 => .{
                .type = .php,
                .mode = .implied,
                .cycles = 3,
            },
            0x18 => .{
                .type = .clc,
                .mode = .implied,
                .cycles = 2,
            },
            0x20 => .{
                .type = .jsr,
                .mode = .absolute,
                .cycles = 6,
            },
            0x28 => .{
                .type = .plp,
                .mode = .implied,
                .cycles = 4,
            },
            0x38 => .{
                .type = .sec,
                .mode = .implied,
                .cycles = 2,
            },
            0x40 => .{
                .type = .rti,
                .mode = .implied,
                .cycles = 6,
            },
            0x48 => .{
                .type = .pha,
                .mode = .implied,
                .cycles = 3,
            },
            0x4C => .{
                .type = .jmp,
                .mode = .absolute,
                .cycles = 3,
            },
            0x58 => .{
                .type = .cli,
                .mode = .implied,
                .cycles = 2,
            },
            0x60 => .{
                .type = .rts,
                .mode = .implied,
                .cycles = 6,
            },
            0x68 => .{
                .type = .pla,
                .mode = .implied,
                .cycles = 4,
            },
            0x6C => .{
                .type = .jmp,
                .mode = .indirect,
                .cycles = 5,
            },
            0x78 => .{
                .type = .sei,
                .mode = .implied,
                .cycles = 2,
            },
            0x81 => .{
                .type = .sta,
                .mode = .indirect_x,
                .cycles = 6,
            },
            0x85 => .{
                .type = .sta,
                .mode = .zero_page,
                .cycles = 3,
            },
            0x8D => .{
                .type = .sta,
                .mode = .absolute,
                .cycles = 4,
            },
            0x91 => .{
                .type = .sta,
                .mode = .indirect_y,
                .cycles = 6,
            },
            0x95 => .{
                .type = .sta,
                .mode = .zero_page_x,
                .cycles = 4,
            },
            0x99 => .{
                .type = .sta,
                .mode = .absolute_y,
                .cycles = 5,
            },
            0x9A => .{
                .type = .txs,
                .mode = .implied,
                .cycles = 2,
            },
            0x9D => .{
                .type = .sta,
                .mode = .absolute_x,
                .cycles = 5,
            },
            0xA1 => .{
                .type = .lda,
                .mode = .indirect_x,
                .cycles = 6,
            },
            0xA5 => .{
                .type = .lda,
                .mode = .zero_page,
                .cycles = 3,
            },
            0xA9 => .{
                .type = .lda,
                .mode = .immediate,
                .cycles = 2,
            },
            0xAD => .{
                .type = .lda,
                .mode = .absolute,
                .cycles = 4,
            },
            0xB1 => .{
                .type = .lda,
                .mode = .indirect_y,
                .cycles = 5,
            },
            0xB5 => .{
                .type = .lda,
                .mode = .zero_page_x,
                .cycles = 4,
            },
            0xB8 => .{
                .type = .clv,
                .mode = .implied,
                .cycles = 2,
            },
            0xB9 => .{
                .type = .lda,
                .mode = .absolute_y,
                .cycles = 4,
            },
            0xBA => .{
                .type = .tsx,
                .mode = .implied,
                .cycles = 2,
            },
            0xBD => .{
                .type = .lda,
                .mode = .absolute_x,
                .cycles = 4,
            },
            0xD8 => .{
                .type = .cld,
                .mode = .implied,
                .cycles = 2,
            },
            0xEA => .{
                .type = .nop,
                .mode = .implied,
                .cycles = 2,
            },
            0xF8 => .{
                .type = .sed,
                .mode = .implied,
                .cycles = 2,
            },
            else => .{
                .type = .unknown,
                .mode = .unknown,
                .cycles = 1,
            },
        };
    }
};

pub fn Chip(Bus: type) type {
    BusInterface.validate(Bus);

    return struct {
        pub const Self = @This();

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

            const pc_lo: u16 = self.read(0xFFFC);
            const pc_hi: u16 = self.read(0xFFFD);
            self.pc = (pc_hi << 8) | pc_lo;

            self.sp = 0xFD;

            self.status = .init;
            self.status.set(.i, true);
        }

        pub fn reset(self: *Self) void {
            const pc_lo: u16 = self.read(0xFFFC);
            const pc_hi: u16 = self.read(0xFFFD);
            self.pc = (pc_hi << 8) | pc_lo;
            self.sp = 0xFD;
            self.status.set(.i, true);

            self.cycles_left = 8;
        }

        pub fn clock(self: *Self) void {
            if (self.cycles_left == 0) {
                const opcode = self.read(self.pc);
                self.pc += 1;

                const decode = Instruction.decode(opcode);

                self.cycles_left = decode.cycles;

                self.cycles_left += if (decode.run(Self, self)) 1 else 0;
            }

            self.cycles_left -= 1;
        }

        pub fn write(self: *Self, addr: u16, value: u8) void {
            self.bus.write(addr, value);
        }

        pub fn read(self: Self, addr: u16) u8 {
            return self.bus.read(addr);
        }
    };
}

test "cpu read/write" {
    var bus = TestBus{
        .data = undefined,
    };
    @memset(&bus.data, 0);

    var cpu = Chip(TestBus).init(&bus);
    cpu.write(0x00FF, 0x17);
    cpu.write(0x5978, 0x69);

    try std.testing.expectEqual(bus.data[0x00FF], 0x17);
    try std.testing.expectEqual(bus.data[0x5978], 0x69);
}

test "cpu register" {
    var bus = TestBus{
        .data = undefined,
    };
    @memset(&bus.data, 0);

    var cpu = Chip(TestBus).init(&bus);
    cpu.status.set(.d, true);
    cpu.status.set(.v, true);

    try std.testing.expect(cpu.status.isSet(.d));
    try std.testing.expectEqual(cpu.status.data, 0b01001000);

    cpu.status.set(.d, false);
    try std.testing.expect(!cpu.status.isSet(.d));
}

test "instructions" {
    std.testing.refAllDecls(@import("mos_technology_6502/testing.zig"));
}
