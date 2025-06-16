const std = @import("std");
const Bus = @import("Bus.zig");
const Assembler = @import("Assembler.zig");
const Instruction = @import("Instruction.zig");

pub fn parse(allocator: std.mem.Allocator, text: []const u8, bus: Bus) !void {
    var assembler = Assembler.init(bus, 0xF000, allocator);
    defer assembler.deinit();

    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line_unstripped| {
        var line = stripComment(line_unstripped);
        line = std.mem.trimLeft(u8, line, " \t");

        // skip empty lines
        if (line.len < 1) {
            continue;
        }

        // Labels
        if (std.mem.endsWith(u8, line, ":")) {
            std.debug.print("Lable: {s}\n", .{line[0 .. line.len - 1]});
            try assembler.label(line[0 .. line.len - 1]);
            continue;
        }

        std.debug.print("Line: {s}\n", .{line});

        if (std.mem.startsWith(u8, line, "LDA")) {
            const resolved = try resolveValue(line[4..]);
            assembler.lda(resolved.mode, .{
                .first = resolved.first,
                .second = resolved.second,
            });
        } else if (std.mem.startsWith(u8, line, "STA")) {
            const resolved = try resolveValue(line[4..]);
            assembler.sta(resolved.mode, .{
                .first = resolved.first,
                .second = resolved.second,
            });
        } else if (std.mem.startsWith(u8, line, "LDX")) {
            const resolved = try resolveValue(line[4..]);
            assembler.ldx(resolved.mode, .{
                .first = resolved.first,
                .second = resolved.second,
            });
        } else if (std.mem.startsWith(u8, line, "STX")) {
            const resolved = try resolveValue(line[4..]);
            assembler.stx(resolved.mode, .{
                .first = resolved.first,
                .second = resolved.second,
            });
        } else if (std.mem.startsWith(u8, line, "LDY")) {
            const resolved = try resolveValue(line[4..]);
            assembler.ldy(resolved.mode, .{
                .first = resolved.first,
                .second = resolved.second,
            });
        } else if (std.mem.startsWith(u8, line, "STY")) {
            const resolved = try resolveValue(line[4..]);
            assembler.sty(resolved.mode, .{
                .first = resolved.first,
                .second = resolved.second,
            });
        } else if (std.mem.startsWith(u8, line, "TAX")) {
            assembler.tax();
        } else if (std.mem.startsWith(u8, line, "TXA")) {
            assembler.txa();
        } else if (std.mem.startsWith(u8, line, "TAY")) {
            assembler.tay();
        } else if (std.mem.startsWith(u8, line, "TYA")) {
            assembler.tya();
        } else if (std.mem.startsWith(u8, line, "ADC")) {
            const resolved = try resolveValue(line[4..]);
            assembler.adc(resolved.mode, .{
                .first = resolved.first,
                .second = resolved.second,
            });
        } else if (std.mem.startsWith(u8, line, "SBC")) {
            const resolved = try resolveValue(line[4..]);
            assembler.sbc(resolved.mode, .{
                .first = resolved.first,
                .second = resolved.second,
            });
        } else if (std.mem.startsWith(u8, line, "INC")) {
            const resolved = try resolveValue(line[4..]);
            assembler.inc(resolved.mode, .{
                .first = resolved.first,
                .second = resolved.second,
            });
        } else if (std.mem.startsWith(u8, line, "DEC")) {
            const resolved = try resolveValue(line[4..]);
            assembler.dec(resolved.mode, .{
                .first = resolved.first,
                .second = resolved.second,
            });
        } else if (std.mem.startsWith(u8, line, "INX")) {
            assembler.inx();
        } else if (std.mem.startsWith(u8, line, "DEX")) {
            assembler.dex();
        } else if (std.mem.startsWith(u8, line, "INY")) {
            assembler.iny();
        } else if (std.mem.startsWith(u8, line, "DEY")) {
            assembler.dey();
        } else if (std.mem.startsWith(u8, line, "ASL")) {
            const resolved = try resolveValue(line[4..]);
            assembler.asl(resolved.mode, .{
                .first = resolved.first,
                .second = resolved.second,
            });
        } else if (std.mem.startsWith(u8, line, "LSR")) {
            const resolved = try resolveValue(line[4..]);
            assembler.lsr(resolved.mode, .{
                .first = resolved.first,
                .second = resolved.second,
            });
        } else if (std.mem.startsWith(u8, line, "ROL")) {
            const resolved = try resolveValue(line[4..]);
            assembler.rol(resolved.mode, .{
                .first = resolved.first,
                .second = resolved.second,
            });
        } else if (std.mem.startsWith(u8, line, "ROR")) {
            const resolved = try resolveValue(line[4..]);
            assembler.ror(resolved.mode, .{
                .first = resolved.first,
                .second = resolved.second,
            });
        } else if (std.mem.startsWith(u8, line, "AND")) {
            const resolved = try resolveValue(line[4..]);
            assembler.@"and"(resolved.mode, .{
                .first = resolved.first,
                .second = resolved.second,
            });
        } else if (std.mem.startsWith(u8, line, "ORA")) {
            const resolved = try resolveValue(line[4..]);
            assembler.ora(resolved.mode, .{
                .first = resolved.first,
                .second = resolved.second,
            });
        } else if (std.mem.startsWith(u8, line, "EOR")) {
            const resolved = try resolveValue(line[4..]);
            assembler.eor(resolved.mode, .{
                .first = resolved.first,
                .second = resolved.second,
            });
        } else if (std.mem.startsWith(u8, line, "BIT")) {
            const resolved = try resolveValue(line[4..]);
            assembler.bit(resolved.mode, .{
                .first = resolved.first,
                .second = resolved.second,
            });
        } else if (std.mem.startsWith(u8, line, "CMP")) {
            const resolved = try resolveValue(line[4..]);
            assembler.cmp(resolved.mode, .{
                .first = resolved.first,
                .second = resolved.second,
            });
        } else if (std.mem.startsWith(u8, line, "CPX")) {
            const resolved = try resolveValue(line[4..]);
            assembler.cpx(resolved.mode, .{
                .first = resolved.first,
                .second = resolved.second,
            });
        } else if (std.mem.startsWith(u8, line, "CPY")) {
            const resolved = try resolveValue(line[4..]);
            assembler.cpy(resolved.mode, .{
                .first = resolved.first,
                .second = resolved.second,
            });
        } else if (std.mem.startsWith(u8, line, "BCC")) {
            try assembler.bcc(line[4..]);
        } else if (std.mem.startsWith(u8, line, "BCS")) {
            try assembler.bcs(line[4..]);
        } else if (std.mem.startsWith(u8, line, "BEQ")) {
            try assembler.beq(line[4..]);
        } else if (std.mem.startsWith(u8, line, "BNE")) {
            try assembler.bne(line[4..]);
        } else if (std.mem.startsWith(u8, line, "BPL")) {
            try assembler.bpl(line[4..]);
        } else if (std.mem.startsWith(u8, line, "BMI")) {
            try assembler.bmi(line[4..]);
        } else if (std.mem.startsWith(u8, line, "BVC")) {
            try assembler.bvc(line[4..]);
        } else if (std.mem.startsWith(u8, line, "BVS")) {
            try assembler.bvs(line[4..]);
        } else if (std.mem.startsWith(u8, line, "JMP")) {
            // TODO: allow indirect address mode as well
            try assembler.jmp_label(line[4..]);
        } else if (std.mem.startsWith(u8, line, "JSR")) {
            try assembler.jsr_label(line[4..]);
        } else if (std.mem.startsWith(u8, line, "RTS")) {
            assembler.rts();
        } else if (std.mem.startsWith(u8, line, "BRK")) {
            assembler.brk();
        } else if (std.mem.startsWith(u8, line, "RTI")) {
            assembler.rti();
        } else if (std.mem.startsWith(u8, line, "PHA")) {
            assembler.pha();
        } else if (std.mem.startsWith(u8, line, "PLA")) {
            assembler.pla();
        } else if (std.mem.startsWith(u8, line, "PHP")) {
            assembler.php();
        } else if (std.mem.startsWith(u8, line, "PLP")) {
            assembler.plp();
        } else if (std.mem.startsWith(u8, line, "TXS")) {
            assembler.txs();
        } else if (std.mem.startsWith(u8, line, "TSX")) {
            assembler.tsx();
        } else if (std.mem.startsWith(u8, line, "CLC")) {
            assembler.clc();
        } else if (std.mem.startsWith(u8, line, "SEC")) {
            assembler.sec();
        } else if (std.mem.startsWith(u8, line, "CLI")) {
            assembler.cli();
        } else if (std.mem.startsWith(u8, line, "SEI")) {
            assembler.sei();
        } else if (std.mem.startsWith(u8, line, "CLD")) {
            assembler.cld();
        } else if (std.mem.startsWith(u8, line, "SED")) {
            assembler.sed();
        } else if (std.mem.startsWith(u8, line, "CLV")) {
            assembler.clv();
        } else if (std.mem.startsWith(u8, line, "NOP")) {
            assembler.nop();
        } else {
            std.debug.print("Parser Error: Not an instruction: {s}\n", .{line});
        }
    }
}

const ResolvedValue = struct {
    mode: Instruction.Mode,
    first: u8 = 0x00,
    second: u8 = 0x00,
};

fn resolveValue(text: []const u8) !ResolvedValue {
    // Immediate
    if (text.len > 1 and text[0] == '#') {
        const value = text[1..];
        return .{
            .mode = .immediate,
            .first = try parseU8(value),
        };
    }

    if (text.len > 3 and text[0] == '(') {
        if (text[text.len - 1] == ')' and text[text.len - 2] != 'X') {
            const inner = text[1 .. text.len - 1];
            std.debug.print("Indirect inner: {s}\n", .{inner});
            const val = try parseU16(inner);
            return .{
                .mode = .indirect,
                .first = @truncate(val),
                .second = @truncate(val >> 8),
            };
        } else if (std.mem.endsWith(u8, text, ",X)")) {
            const inner = text[1 .. text.len - 3];
            std.debug.print("Indirect X inner: {s}\n", .{inner});
            return .{
                .mode = .indirect_x,
                .first = try parseU8(inner),
            };
        } else if (std.mem.endsWith(u8, text, "),Y")) {
            const inner = text[1 .. text.len - 3];
            std.debug.print("Indirect Y inner: {s}\n", .{inner});
            return .{
                .mode = .indirect_y,
                .first = try parseU8(inner),
            };
        }
    }

    // indexed
    if (std.mem.endsWith(u8, text, ",X")) {
        const base = std.mem.trimRight(u8, text[0 .. text.len - 2], " \t");
        const val = try parseU16(base);
        if (val <= 0xFF) {
            return .{
                .mode = .zero_page_x,
                .first = @truncate(val),
            };
        } else {
            return .{
                .mode = .absolute_x,
                .first = @truncate(val),
                .second = @truncate(val >> 8),
            };
        }
    } else if (std.mem.endsWith(u8, text, ",Y")) {
        const base = std.mem.trimRight(u8, text[0 .. text.len - 2], " \t");
        const val = try parseU16(base);
        if (val <= 0xFF) {
            return .{
                .mode = .zero_page_y,
                .first = @truncate(val),
            };
        } else {
            return .{
                .mode = .absolute_y,
                .first = @truncate(val),
                .second = @truncate(val >> 8),
            };
        }
    }

    // absolute and zeropage
    const val = try parseU16(text);
    if (val <= 0xFF) {
        return .{
            .mode = .zero_page,
            .first = @truncate(val),
        };
    } else {
        return .{
            .mode = .absolute,
            .first = @truncate(val),
            .second = @truncate(val >> 8),
        };
    }
}

fn parseU8(text: []const u8) !u8 {
    return @as(u8, @intCast(try parseU16(text)));
}

fn parseU16(text: []const u8) !u16 {
    if (text[0] == '$') {
        const hex = text[1..];
        return try std.fmt.parseInt(u16, hex, 16);
    } else {
        return try std.fmt.parseInt(u16, text, 10);
    }
}

fn stripComment(line: []const u8) []const u8 {
    if (std.mem.indexOfScalar(u8, line, ';')) |i| {
        return std.mem.trimRight(u8, line[0..i], " ");
    }
    return std.mem.trimRight(u8, line, " ");
}
