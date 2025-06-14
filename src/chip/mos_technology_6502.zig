const std = @import("std");
pub const instructions = @import("mos_technology_6502/instructions.zig");
pub const parser = @import("mos_technology_6502/parser.zig");
pub const Instruction = @import("mos_technology_6502/Instruction.zig");
pub const Bus = @import("mos_technology_6502/Bus.zig");
pub const TestBus = @import("mos_technology_6502/testing.zig").TestBus;
pub const Assembler = @import("mos_technology_6502/Assembler.zig");

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

pub const Chip = struct {
    // Register
    status: Status,
    pc: u16,
    sp: u8,
    a: u8,
    x: u8,
    y: u8,

    // Bus
    bus: Bus,

    // Meta
    cycles_left: u8,

    pub fn init(bus: Bus) Chip {
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

    pub fn powerOn(self: *Chip) void {
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

    pub fn reset(self: *Chip) void {
        const pc_lo: u16 = self.read(0xFFFC);
        const pc_hi: u16 = self.read(0xFFFD);
        self.pc = (pc_hi << 8) | pc_lo;
        self.sp = 0xFD;
        self.status.set(.i, true);

        self.cycles_left = 8;
    }

    pub fn clock(self: *Chip) void {
        if (self.cycles_left == 0) {
            const opcode = self.read(self.pc);
            self.pc += 1;

            const decode = Instruction.decode(opcode);

            self.cycles_left = decode.cycles;

            const cycle_request = decode.run(self);

            self.cycles_left += if (cycle_request) 1 else 0;
        }
        self.cycles_left -= 1;
    }

    pub fn write(self: *Chip, addr: u16, value: u8) void {
        self.bus.write(addr, value);
    }

    pub fn read(self: Chip, addr: u16) u8 {
        return self.bus.read(addr);
    }
};

pub fn bufPrintCurInstr(chip: Chip, buf: []u8) ![]u8 {
    const print = std.fmt.bufPrint;
    const opcode = chip.read(chip.pc);
    const decode = Instruction.decode(opcode);

    const name = switch (decode.type) {
        .lda => "LDA",
        .sta => "STA",
        .ldx => "LDX",
        .stx => "STX",
        .ldy => "LDY",
        .sty => "STY",
        .tax => "TAX",
        .txa => "TXA",
        .tay => "TAY",
        .tya => "TYA",
        .adc => "ADC",
        .sbc => "SBC",
        .inc => "INC",
        .dec => "DEC",
        .inx => "INX",
        .dex => "DEX",
        .iny => "INY",
        .dey => "DEY",
        .asl => "ASL",
        .lsr => "LSR",
        .rol => "ROL",
        .ror => "ROR",
        .@"and" => "AND",
        .ora => "ORA",
        .eor => "EOR",
        .bit => "BIT",
        .cmp => "CMP",
        .cpx => "CPX",
        .cpy => "CPY",
        .bcc => "BCC",
        .bcs => "BCS",
        .beq => "BEQ",
        .bne => "BNE",
        .bpl => "BPL",
        .bmi => "BMI",
        .bvc => "BVC",
        .bvs => "BVS",
        .jmp => "JMP",
        .jsr => "JSR",
        .rts => "RTS",
        .brk => "BRK",
        .rti => "RTI",
        .pha => "PHA",
        .pla => "PLA",
        .php => "PHP",
        .plp => "PLP",
        .txs => "TXS",
        .tsx => "TSX",
        .clc => "CLC",
        .sec => "SEC",
        .cli => "CLI",
        .sei => "SEI",
        .cld => "CLD",
        .sed => "SED",
        .clv => "CLV",
        .nop => "NOP",
        else => "TODO",
    };

    return switch (decode.mode) {
        .accumulator, .implied => try print(buf, "{s}", .{name}),
        .immediate => blk: {
            const value = chip.read(chip.pc + 1);
            break :blk try print(buf, "{s} #${X:0>2}", .{ name, value });
        },
        .zero_page => blk: {
            const value = chip.read(chip.pc + 1);
            break :blk try print(buf, "{s} ${X:0>2}", .{ name, value });
        },
        .zero_page_x => blk: {
            const value = chip.read(chip.pc + 1);
            break :blk try print(buf, "{s} ${X:0>2},X", .{ name, value });
        },
        .zero_page_y => blk: {
            const value = chip.read(chip.pc + 1);
            break :blk try print(buf, "{s} ${X:0>2},Y", .{ name, value });
        },
        .absolute => blk: {
            const lo = chip.read(chip.pc + 1);
            const hi = chip.read(chip.pc + 2);
            break :blk try print(buf, "{s} ${X:0>2}{X:0>2}", .{ name, hi, lo });
        },
        .absolute_x => blk: {
            const lo = chip.read(chip.pc + 1);
            const hi = chip.read(chip.pc + 2);
            break :blk try print(buf, "{s} ${X:0>2}{X:0>2},X", .{ name, hi, lo });
        },
        .absolute_y => blk: {
            const lo = chip.read(chip.pc + 1);
            const hi = chip.read(chip.pc + 2);
            break :blk try print(buf, "{s} ${X:0>2}{X:0>2},Y", .{ name, hi, lo });
        },
        .indirect => blk: {
            const lo = chip.read(chip.pc + 1);
            const hi = chip.read(chip.pc + 2);
            break :blk try print(buf, "{s} (${X}{X})", .{ name, hi, lo });
        },
        .indirect_x => blk: {
            const value = chip.read(chip.pc + 1);
            break :blk try print(buf, "{s} (${X},X)", .{ name, value });
        },
        .indirect_y => blk: {
            const value = chip.read(chip.pc + 1);
            break :blk try print(buf, "{s} (${X}),Y", .{ name, value });
        },
        .relative => blk: {
            const value = chip.read(chip.pc + 1);
            break :blk try print(buf, "{s} ${X:0>2}", .{ name, value });
        },
        else => try print(buf, "{s}: no format", .{name}),
    };
}

test "cpu read/write" {
    var bus = TestBus{
        .data = undefined,
    };
    @memset(&bus.data, 0);

    var cpu = Chip.init(bus.bus());
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

    var cpu = Chip.init(bus.bus());
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
