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

        // Labels
        if (std.mem.endsWith(u8, line, ":")) {
            std.debug.print("Lable: {s}\n\n", .{line[0 .. line.len - 1]});
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
        } else if (std.mem.startsWith(u8, line, "ADC")) {
            const resolved = try resolveValue(line[4..]);
            assembler.adc(resolved.mode, .{
                .first = resolved.first,
                .second = resolved.second,
            });
        } else if (std.mem.startsWith(u8, line, "INX")) {
            assembler.inx();
        } else if (std.mem.startsWith(u8, line, "DEX")) {
            assembler.dex();
        } else if (std.mem.startsWith(u8, line, "CPX")) {
            const resolved = try resolveValue(line[4..]);
            assembler.cpx(resolved.mode, .{
                .first = resolved.first,
                .second = resolved.second,
            });
        } else if (std.mem.startsWith(u8, line, "BNE")) {
            try assembler.bne(line[4..]);
        } else if (std.mem.startsWith(u8, line, "BRK")) {
            assembler.brk();
        } else {
            std.debug.print("TODO: {s}\n", .{line});
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

    // TODO: indirect

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
