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
        ldx,
        stx,
        ldy,
        sty,
        // Transfer
        tax,
        txa,
        tay,
        tya,
        // Arithmetic
        adc,
        sbc,
        inc,
        dec,
        inx,
        dex,
        iny,
        dey,
        // Shift
        asl,
        lsr,
        rol,
        ror,
        // Bitwise
        @"and",
        ora,
        eor,
        bit,
        // Compare
        cmp,
        cpx,
        cpy,
        // TODO: Branch
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
        accumulator,
        implied,
        immediate,
        zero_page,
        zero_page_x,
        zero_page_y,
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
            .accumulator => instructions.accumulator(cpu),
            .implied => instructions.implied(cpu),
            .immediate => instructions.immediate(cpu),
            .zero_page => instructions.zeroPage(cpu),
            .zero_page_x => instructions.zeroPageX(cpu),
            .zero_page_y => instructions.zeroPageY(cpu),
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
            .ldx => instructions.ldx(cpu, address_return),
            .stx => instructions.stx(cpu, address_return),
            .ldy => instructions.ldy(cpu, address_return),
            .sty => instructions.sty(cpu, address_return),
            .tax => instructions.tax(cpu, address_return),
            .txa => instructions.txa(cpu, address_return),
            .tay => instructions.tay(cpu, address_return),
            .tya => instructions.tya(cpu, address_return),
            .adc => instructions.adc(cpu, address_return),
            .sbc => instructions.sbc(cpu, address_return),
            .inc => instructions.inc(cpu, address_return),
            .dec => instructions.dec(cpu, address_return),
            .inx => instructions.inx(cpu, address_return),
            .dex => instructions.dex(cpu, address_return),
            .iny => instructions.iny(cpu, address_return),
            .dey => instructions.dey(cpu, address_return),
            .asl => instructions.asl(cpu, address_return),
            .lsr => instructions.lsr(cpu, address_return),
            .rol => instructions.rol(cpu, address_return),
            .ror => instructions.ror(cpu, address_return),
            .@"and" => instructions.@"and"(cpu, address_return),
            .ora => instructions.ora(cpu, address_return),
            .eor => instructions.eor(cpu, address_return),
            .bit => instructions.bit(cpu, address_return),
            .cmp => instructions.cmp(cpu, address_return),
            .cpx => instructions.cpx(cpu, address_return),
            .cpy => instructions.cpy(cpu, address_return),
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
            0x01 => .{
                .type = .ora,
                .mode = .indirect_x,
                .cycles = 6,
            },
            0x05 => .{
                .type = .ora,
                .mode = .zero_page,
                .cycles = 3,
            },
            0x06 => .{
                .type = .asl,
                .mode = .zero_page,
                .cycles = 5,
            },
            0x08 => .{
                .type = .php,
                .mode = .implied,
                .cycles = 3,
            },
            0x09 => .{
                .type = .ora,
                .mode = .immediate,
                .cycles = 2,
            },
            0x0A => .{
                .type = .asl,
                .mode = .accumulator,
                .cycles = 2,
            },
            0x0D => .{
                .type = .ora,
                .mode = .absolute,
                .cycles = 4,
            },
            0x0E => .{
                .type = .asl,
                .mode = .absolute,
                .cycles = 6,
            },
            0x11 => .{
                .type = .ora,
                .mode = .indirect_y,
                .cycles = 5,
            },
            0x15 => .{
                .type = .ora,
                .mode = .zero_page_x,
                .cycles = 4,
            },
            0x16 => .{
                .type = .asl,
                .mode = .zero_page_x,
                .cycles = 6,
            },
            0x18 => .{
                .type = .clc,
                .mode = .implied,
                .cycles = 2,
            },
            0x19 => .{
                .type = .ora,
                .mode = .absolute_y,
                .cycles = 4,
            },
            0x1D => .{
                .type = .ora,
                .mode = .absolute_x,
                .cycles = 4,
            },
            0x1E => .{
                .type = .asl,
                .mode = .absolute_x,
                .cycles = 7,
            },
            0x20 => .{
                .type = .jsr,
                .mode = .absolute,
                .cycles = 6,
            },
            0x21 => .{
                .type = .@"and",
                .mode = .indirect_x,
                .cycles = 6,
            },
            0x24 => .{
                .type = .bit,
                .mode = .zero_page,
                .cycles = 3,
            },
            0x25 => .{
                .type = .@"and",
                .mode = .zero_page,
                .cycles = 3,
            },
            0x26 => .{
                .type = .rol,
                .mode = .zero_page,
                .cycles = 5,
            },
            0x28 => .{
                .type = .plp,
                .mode = .implied,
                .cycles = 4,
            },
            0x29 => .{
                .type = .@"and",
                .mode = .immediate,
                .cycles = 2,
            },
            0x2A => .{
                .type = .rol,
                .mode = .accumulator,
                .cycles = 2,
            },
            0x2C => .{
                .type = .bit,
                .mode = .absolute,
                .cycles = 4,
            },
            0x2D => .{
                .type = .@"and",
                .mode = .absolute,
                .cycles = 4,
            },
            0x2E => .{
                .type = .rol,
                .mode = .absolute,
                .cycles = 6,
            },
            0x31 => .{
                .type = .@"and",
                .mode = .indirect_y,
                .cycles = 5,
            },
            0x35 => .{
                .type = .@"and",
                .mode = .zero_page_x,
                .cycles = 4,
            },
            0x36 => .{
                .type = .rol,
                .mode = .zero_page_x,
                .cycles = 6,
            },
            0x38 => .{
                .type = .sec,
                .mode = .implied,
                .cycles = 2,
            },
            0x39 => .{
                .type = .@"and",
                .mode = .absolute_y,
                .cycles = 4,
            },
            0x3D => .{
                .type = .@"and",
                .mode = .absolute_x,
                .cycles = 4,
            },
            0x3E => .{
                .type = .rol,
                .mode = .absolute_x,
                .cycles = 7,
            },
            0x40 => .{
                .type = .rti,
                .mode = .implied,
                .cycles = 6,
            },
            0x41 => .{
                .type = .eor,
                .mode = .indirect_x,
                .cycles = 6,
            },
            0x45 => .{
                .type = .eor,
                .mode = .zero_page,
                .cycles = 3,
            },
            0x46 => .{
                .type = .lsr,
                .mode = .zero_page,
                .cycles = 5,
            },
            0x48 => .{
                .type = .pha,
                .mode = .implied,
                .cycles = 3,
            },
            0x49 => .{
                .type = .eor,
                .mode = .immediate,
                .cycles = 2,
            },
            0x4A => .{
                .type = .lsr,
                .mode = .accumulator,
                .cycles = 2,
            },
            0x4C => .{
                .type = .jmp,
                .mode = .absolute,
                .cycles = 3,
            },
            0x4D => .{
                .type = .eor,
                .mode = .absolute,
                .cycles = 4,
            },
            0x4E => .{
                .type = .lsr,
                .mode = .absolute,
                .cycles = 6,
            },
            0x51 => .{
                .type = .eor,
                .mode = .indirect_y,
                .cycles = 5,
            },
            0x55 => .{
                .type = .eor,
                .mode = .zero_page_x,
                .cycles = 4,
            },
            0x56 => .{
                .type = .lsr,
                .mode = .zero_page_x,
                .cycles = 6,
            },
            0x58 => .{
                .type = .cli,
                .mode = .implied,
                .cycles = 2,
            },
            0x59 => .{
                .type = .eor,
                .mode = .absolute_y,
                .cycles = 4,
            },
            0x5D => .{
                .type = .eor,
                .mode = .absolute_x,
                .cycles = 4,
            },
            0x5E => .{
                .type = .lsr,
                .mode = .absolute_x,
                .cycles = 7,
            },
            0x60 => .{
                .type = .rts,
                .mode = .implied,
                .cycles = 6,
            },
            0x61 => .{
                .type = .adc,
                .mode = .indirect_x,
                .cycles = 6,
            },
            0x65 => .{
                .type = .adc,
                .mode = .zero_page,
                .cycles = 3,
            },
            0x66 => .{
                .type = .ror,
                .mode = .zero_page,
                .cycles = 5,
            },
            0x68 => .{
                .type = .pla,
                .mode = .implied,
                .cycles = 4,
            },
            0x69 => .{
                .type = .adc,
                .mode = .immediate,
                .cycles = 2,
            },
            0x6A => .{
                .type = .ror,
                .mode = .accumulator,
                .cycles = 2,
            },
            0x6C => .{
                .type = .jmp,
                .mode = .indirect,
                .cycles = 5,
            },
            0x6D => .{
                .type = .adc,
                .mode = .absolute,
                .cycles = 4,
            },
            0x6E => .{
                .type = .ror,
                .mode = .absolute,
                .cycles = 6,
            },
            0x71 => .{
                .type = .adc,
                .mode = .indirect_y,
                .cycles = 5,
            },
            0x75 => .{
                .type = .adc,
                .mode = .zero_page_x,
                .cycles = 4,
            },
            0x76 => .{
                .type = .ror,
                .mode = .zero_page_x,
                .cycles = 6,
            },
            0x78 => .{
                .type = .sei,
                .mode = .implied,
                .cycles = 2,
            },
            0x79 => .{
                .type = .adc,
                .mode = .absolute_y,
                .cycles = 4,
            },
            0x7D => .{
                .type = .adc,
                .mode = .absolute_x,
                .cycles = 4,
            },
            0x7E => .{
                .type = .ror,
                .mode = .absolute_x,
                .cycles = 7,
            },
            0x81 => .{
                .type = .sta,
                .mode = .indirect_x,
                .cycles = 6,
            },
            0x84 => .{
                .type = .sty,
                .mode = .zero_page,
                .cycles = 3,
            },
            0x85 => .{
                .type = .sta,
                .mode = .zero_page,
                .cycles = 3,
            },
            0x86 => .{
                .type = .stx,
                .mode = .zero_page,
                .cycles = 3,
            },
            0x88 => .{
                .type = .dey,
                .mode = .implied,
                .cycles = 2,
            },
            0x8A => .{
                .type = .txa,
                .mode = .implied,
                .cycles = 2,
            },
            0x8C => .{
                .type = .sty,
                .mode = .absolute,
                .cycles = 4,
            },
            0x8D => .{
                .type = .sta,
                .mode = .absolute,
                .cycles = 4,
            },
            0x8E => .{
                .type = .stx,
                .mode = .absolute,
                .cycles = 4,
            },
            0x91 => .{
                .type = .sta,
                .mode = .indirect_y,
                .cycles = 6,
            },
            0x94 => .{
                .type = .sty,
                .mode = .zero_page_x,
                .cycles = 4,
            },
            0x95 => .{
                .type = .sta,
                .mode = .zero_page_x,
                .cycles = 4,
            },
            0x96 => .{
                .type = .stx,
                .mode = .zero_page_y,
                .cycles = 4,
            },
            0x98 => .{
                .type = .tya,
                .mode = .implied,
                .cycles = 2,
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
            0xA0 => .{
                .type = .ldy,
                .mode = .immediate,
                .cycles = 2,
            },
            0xA1 => .{
                .type = .lda,
                .mode = .indirect_x,
                .cycles = 6,
            },
            0xA2 => .{
                .type = .ldx,
                .mode = .immediate,
                .cycles = 2,
            },
            0xA4 => .{
                .type = .ldy,
                .mode = .zero_page,
                .cycles = 3,
            },
            0xA5 => .{
                .type = .lda,
                .mode = .zero_page,
                .cycles = 3,
            },
            0xA6 => .{
                .type = .ldx,
                .mode = .zero_page,
                .cycles = 3,
            },
            0xA8 => .{
                .type = .tay,
                .mode = .implied,
                .cycles = 2,
            },
            0xA9 => .{
                .type = .lda,
                .mode = .immediate,
                .cycles = 2,
            },
            0xAA => .{
                .type = .tax,
                .mode = .implied,
                .cycles = 2,
            },
            0xAC => .{
                .type = .ldy,
                .mode = .absolute,
                .cycles = 4,
            },
            0xAD => .{
                .type = .lda,
                .mode = .absolute,
                .cycles = 4,
            },
            0xAE => .{
                .type = .ldx,
                .mode = .absolute,
                .cycles = 4,
            },
            0xB1 => .{
                .type = .lda,
                .mode = .indirect_y,
                .cycles = 5,
            },
            0xB4 => .{
                .type = .ldy,
                .mode = .zero_page_x,
                .cycles = 4,
            },
            0xB5 => .{
                .type = .lda,
                .mode = .zero_page_x,
                .cycles = 4,
            },
            0xB6 => .{
                .type = .ldx,
                .mode = .zero_page_y,
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
            0xBC => .{
                .type = .ldy,
                .mode = .absolute_x,
                .cycles = 4,
            },
            0xBD => .{
                .type = .lda,
                .mode = .absolute_x,
                .cycles = 4,
            },
            0xBE => .{
                .type = .ldx,
                .mode = .absolute_y,
                .cycles = 4,
            },
            0xC0 => .{
                .type = .cpy,
                .mode = .immediate,
                .cycles = 2,
            },
            0xC1 => .{
                .type = .cmp,
                .mode = .indirect_x,
                .cycles = 6,
            },
            0xC4 => .{
                .type = .cpy,
                .mode = .zero_page,
                .cycles = 3,
            },
            0xC5 => .{
                .type = .cmp,
                .mode = .zero_page,
                .cycles = 3,
            },
            0xC6 => .{
                .type = .dec,
                .mode = .zero_page,
                .cycles = 5,
            },
            0xC8 => .{
                .type = .iny,
                .mode = .implied,
                .cycles = 2,
            },
            0xC9 => .{
                .type = .cmp,
                .mode = .immediate,
                .cycles = 2,
            },
            0xCA => .{
                .type = .dex,
                .mode = .implied,
                .cycles = 2,
            },
            0xCC => .{
                .type = .cpy,
                .mode = .absolute,
                .cycles = 4,
            },
            0xCD => .{
                .type = .cmp,
                .mode = .absolute,
                .cycles = 4,
            },
            0xCE => .{
                .type = .dec,
                .mode = .absolute,
                .cycles = 6,
            },
            0xD1 => .{
                .type = .cmp,
                .mode = .indirect_y,
                .cycles = 5,
            },
            0xD5 => .{
                .type = .cmp,
                .mode = .zero_page_x,
                .cycles = 4,
            },
            0xD6 => .{
                .type = .dec,
                .mode = .zero_page_x,
                .cycles = 6,
            },
            0xD8 => .{
                .type = .cld,
                .mode = .implied,
                .cycles = 2,
            },
            0xD9 => .{
                .type = .cmp,
                .mode = .absolute_y,
                .cycles = 4,
            },
            0xDD => .{
                .type = .cmp,
                .mode = .absolute_x,
                .cycles = 4,
            },
            0xDE => .{
                .type = .dec,
                .mode = .absolute_x,
                .cycles = 7,
            },
            0xE0 => .{
                .type = .cpx,
                .mode = .immediate,
                .cycles = 2,
            },
            0xE1 => .{
                .type = .sbc,
                .mode = .indirect_x,
                .cycles = 6,
            },
            0xE4 => .{
                .type = .cpx,
                .mode = .zero_page,
                .cycles = 3,
            },
            0xE6 => .{
                .type = .inc,
                .mode = .zero_page,
                .cycles = 5,
            },
            0xE5 => .{
                .type = .sbc,
                .mode = .zero_page,
                .cycles = 3,
            },
            0xE8 => .{
                .type = .inx,
                .mode = .implied,
                .cycles = 2,
            },
            0xE9 => .{
                .type = .sbc,
                .mode = .immediate,
                .cycles = 2,
            },
            0xEA => .{
                .type = .nop,
                .mode = .implied,
                .cycles = 2,
            },
            0xEC => .{
                .type = .cpx,
                .mode = .absolute,
                .cycles = 4,
            },
            0xED => .{
                .type = .sbc,
                .mode = .absolute,
                .cycles = 4,
            },
            0xEE => .{
                .type = .inc,
                .mode = .absolute,
                .cycles = 6,
            },
            0xF1 => .{
                .type = .sbc,
                .mode = .indirect_y,
                .cycles = 5,
            },
            0xF5 => .{
                .type = .sbc,
                .mode = .zero_page_x,
                .cycles = 4,
            },
            0xF6 => .{
                .type = .inc,
                .mode = .zero_page_x,
                .cycles = 6,
            },
            0xF8 => .{
                .type = .sed,
                .mode = .implied,
                .cycles = 2,
            },
            0xF9 => .{
                .type = .sbc,
                .mode = .absolute_y,
                .cycles = 4,
            },
            0xFD => .{
                .type = .sbc,
                .mode = .absolute_x,
                .cycles = 4,
            },
            0xFE => .{
                .type = .inc,
                .mode = .absolute_x,
                .cycles = 7,
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
