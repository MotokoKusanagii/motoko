const std = @import("std");
const Bus = @import("Bus.zig");
const Instruction = @import("Instruction.zig");
const Mode = Instruction.Mode;

const Assembler = @This();

bus: Bus,
ptr: u16,
labels: std.StringHashMap(u16),
allocator: std.mem.Allocator,

pub fn init(bus: Bus, start: u16, allocator: std.mem.Allocator) Assembler {
    return .{
        .bus = bus,
        .ptr = start,
        .labels = std.StringHashMap(u16).init(allocator),
        .allocator = allocator,
    };
}

pub fn deinit(self: *Assembler) void {
    self.labels.deinit();
}

/// Mark the current location of the pointer for branch instructions
/// Note: If the instructions is farther than the i8 limit, then ... uhh
/// it will do nothing for now but please don't do that
/// TODO: With the current system you can only jump back in code
/// please fix
pub fn label(self: *Assembler, name: []const u8) !void {
    std.debug.assert(!self.labels.contains(name));
    try self.labels.put(name, self.ptr);
}

pub const Arg = struct {
    first: u8 = 0x00,
    second: u8 = 0x00,
};

pub fn lda(self: *Assembler, mode: Mode, args: Arg) void {
    switch (mode) {
        .immediate => {
            self.write(0xA9);
            self.write(args.first);
        },
        .zero_page => {
            self.write(0xA5);
            self.write(args.first);
        },
        .zero_page_x => {
            self.write(0xB5);
            self.write(args.first);
        },
        .absolute => {
            self.write(0xAD);
            self.write(args.first);
            self.write(args.second);
        },
        .absolute_x => {
            self.write(0xBD);
            self.write(args.first);
            self.write(args.second);
        },
        .absolute_y => {
            self.write(0xB9);
            self.write(args.first);
            self.write(args.second);
        },
        .indirect_x => {
            self.write(0xA1);
            self.write(args.first);
        },
        .indirect_y => {
            self.write(0xB1);
            self.write(args.first);
        },
        else => {},
    }
}

pub fn sta(self: *Assembler, mode: Mode, args: Arg) void {
    switch (mode) {
        .zero_page => {
            self.write(0x85);
            self.write(args.first);
        },
        .zero_page_x => {
            self.write(0x95);
            self.write(args.first);
        },
        .absolute => {
            self.write(0x8D);
            self.write(args.first);
            self.write(args.second);
        },
        .absolute_x => {
            self.write(0x9D);
            self.write(args.first);
            self.write(args.second);
        },
        .absolute_y => {
            self.write(0x99);
            self.write(args.first);
            self.write(args.second);
        },
        .indirect_x => {
            self.write(0x81);
            self.write(args.first);
        },
        .indirect_y => {
            self.write(0x91);
            self.write(args.first);
        },
        else => {},
    }
}

pub fn ldx(self: *Assembler, mode: Mode, args: Arg) void {
    switch (mode) {
        .immediate => {
            self.write(0xA2);
            self.write(args.first);
        },
        .zero_page => {
            self.write(0xA6);
            self.write(args.first);
        },
        .zero_page_y => {
            self.write(0xB6);
            self.write(args.first);
        },
        .absolute => {
            self.write(0xAE);
            self.write(args.first);
            self.write(args.second);
        },
        .absolute_y => {
            self.write(0xBE);
            self.write(args.first);
            self.write(args.second);
        },
        else => {},
    }
}

pub fn stx(self: *Assembler, mode: Mode, args: Arg) void {
    switch (mode) {
        .zero_page => {
            self.write(0x86);
            self.write(args.first);
        },
        .zero_page_y => {
            self.write(0x96);
            self.write(args.first);
        },
        .absolute => {
            self.write(0x8E);
            self.write(args.first);
            self.write(args.second);
        },
        else => {},
    }
}

pub fn ldy(self: *Assembler, mode: Mode, args: Arg) void {
    switch (mode) {
        .immediate => {
            self.write(0xA0);
            self.write(args.first);
        },
        .zero_page => {
            self.write(0xA4);
            self.write(args.first);
        },
        .zero_page_x => {
            self.write(0xB4);
            self.write(args.first);
        },
        .absolute => {
            self.write(0xAC);
            self.write(args.first);
            self.write(args.second);
        },
        .absolute_x => {
            self.write(0xBC);
            self.write(args.first);
            self.write(args.second);
        },
        else => {},
    }
}

pub fn sty(self: *Assembler, mode: Mode, args: Arg) void {
    switch (mode) {
        .zero_page => {
            self.write(0x84);
            self.write(args.first);
        },
        .zero_page_x => {
            self.write(0x94);
            self.write(args.first);
        },
        .absolute => {
            self.write(0x8C);
            self.write(args.first);
            self.write(args.second);
        },
        else => {},
    }
}

pub fn tax(self: *Assembler) void {
    self.write(0xAA);
}

pub fn txa(self: *Assembler) void {
    self.write(0x8A);
}

pub fn tay(self: *Assembler) void {
    self.write(0xA8);
}

pub fn tya(self: *Assembler) void {
    self.write(0x98);
}

pub fn adc(self: *Assembler, mode: Mode, args: Arg) void {
    switch (mode) {
        .immediate => {
            self.write(0x69);
            self.write(args.first);
        },
        .zero_page => {
            self.write(0x65);
            self.write(args.first);
        },
        .zero_page_x => {
            self.write(0x75);
            self.write(args.first);
        },
        .absolute => {
            self.write(0x6D);
            self.write(args.first);
            self.write(args.second);
        },
        .absolute_x => {
            self.write(0x7D);
            self.write(args.first);
            self.write(args.second);
        },
        .absolute_y => {
            self.write(0x79);
            self.write(args.first);
            self.write(args.second);
        },
        .indirect_x => {
            self.write(0x61);
            self.write(args.first);
        },
        .indirect_y => {
            self.write(0x71);
            self.write(args.first);
        },
        else => {},
    }
}

pub fn sbc(self: *Assembler, mode: Mode, args: Arg) void {
    switch (mode) {
        .immediate => {
            self.write(0xE9);
            self.write(args.first);
        },
        .zero_page => {
            self.write(0xE5);
            self.write(args.first);
        },
        .zero_page_x => {
            self.write(0xF5);
            self.write(args.first);
        },
        .absolute => {
            self.write(0xED);
            self.write(args.first);
            self.write(args.second);
        },
        .absolute_x => {
            self.write(0xFD);
            self.write(args.first);
            self.write(args.second);
        },
        .absolute_y => {
            self.write(0xF9);
            self.write(args.first);
            self.write(args.second);
        },
        .indirect_x => {
            self.write(0xE1);
            self.write(args.first);
        },
        .indirect_y => {
            self.write(0xF1);
            self.write(args.first);
        },
        else => {},
    }
}

pub fn inc(self: *Assembler, mode: Mode, args: Arg) void {
    switch (mode) {
        .zero_page => {
            self.write(0xE6);
            self.write(args.first);
        },
        .zero_page_x => {
            self.write(0xF6);
            self.write(args.first);
        },
        .absolute => {
            self.write(0xEE);
            self.write(args.first);
            self.write(args.second);
        },
        .absolute_x => {
            self.write(0xFE);
            self.write(args.first);
            self.write(args.second);
        },
        else => {},
    }
}

pub fn dec(self: *Assembler, mode: Mode, args: Arg) void {
    switch (mode) {
        .zero_page => {
            self.write(0xC6);
            self.write(args.first);
        },
        .zero_page_x => {
            self.write(0xD6);
            self.write(args.first);
        },
        .absolute => {
            self.write(0xCE);
            self.write(args.first);
            self.write(args.second);
        },
        .absolute_x => {
            self.write(0xDE);
            self.write(args.first);
            self.write(args.second);
        },
        else => {},
    }
}

pub fn inx(self: *Assembler) void {
    self.write(0xE8);
}

pub fn dex(self: *Assembler) void {
    self.write(0xCA);
}

pub fn iny(self: *Assembler) void {
    self.write(0xC8);
}

pub fn dey(self: *Assembler) void {
    self.write(0x88);
}

pub fn asl(self: *Assembler, mode: Mode, args: Arg) void {
    switch (mode) {
        .accumulator => {
            self.write(0x0A);
        },
        .zero_page => {
            self.write(0x06);
            self.write(args.first);
        },
        .zero_page_x => {
            self.write(0x16);
            self.write(args.first);
        },
        .absolute => {
            self.write(0x0E);
            self.write(args.first);
            self.write(args.second);
        },
        .absolute_x => {
            self.write(0x1E);
            self.write(args.first);
            self.write(args.second);
        },
        else => {},
    }
}

pub fn lsr(self: *Assembler, mode: Mode, args: Arg) void {
    switch (mode) {
        .accumulator => {
            self.write(0x4A);
        },
        .zero_page => {
            self.write(0x46);
            self.write(args.first);
        },
        .zero_page_x => {
            self.write(0x56);
            self.write(args.first);
        },
        .absolute => {
            self.write(0x4E);
            self.write(args.first);
            self.write(args.second);
        },
        .absolute_x => {
            self.write(0x5E);
            self.write(args.first);
            self.write(args.second);
        },
        else => {},
    }
}

pub fn rol(self: *Assembler, mode: Mode, args: Arg) void {
    switch (mode) {
        .accumulator => {
            self.write(0x2A);
        },
        .zero_page => {
            self.write(0x26);
            self.write(args.first);
        },
        .zero_page_x => {
            self.write(0x36);
            self.write(args.first);
        },
        .absolute => {
            self.write(0x2E);
            self.write(args.first);
            self.write(args.second);
        },
        .absolute_x => {
            self.write(0x3E);
            self.write(args.first);
            self.write(args.second);
        },
        else => {},
    }
}

pub fn ror(self: *Assembler, mode: Mode, args: Arg) void {
    switch (mode) {
        .accumulator => {
            self.write(0x6A);
        },
        .zero_page => {
            self.write(0x66);
            self.write(args.first);
        },
        .zero_page_x => {
            self.write(0x76);
            self.write(args.first);
        },
        .absolute => {
            self.write(0x6E);
            self.write(args.first);
            self.write(args.second);
        },
        .absolute_x => {
            self.write(0x7E);
            self.write(args.first);
            self.write(args.second);
        },
        else => {},
    }
}

pub fn @"and"(self: *Assembler, mode: Mode, args: Arg) void {
    switch (mode) {
        .immediate => {
            self.write(0x29);
            self.write(args.first);
        },
        .zero_page => {
            self.write(0x25);
            self.write(args.first);
        },
        .zero_page_x => {
            self.write(0x35);
            self.write(args.first);
        },
        .absolute => {
            self.write(0x2D);
            self.write(args.first);
            self.write(args.second);
        },
        .absolute_x => {
            self.write(0x3D);
            self.write(args.first);
            self.write(args.second);
        },
        .absolute_y => {
            self.write(0x39);
            self.write(args.first);
            self.write(args.second);
        },
        .indirect_x => {
            self.write(0x21);
            self.write(args.first);
        },
        .indirect_y => {
            self.write(0x31);
            self.write(args.first);
        },
        else => {},
    }
}

pub fn ora(self: *Assembler, mode: Mode, args: Arg) void {
    switch (mode) {
        .immediate => {
            self.write(0x09);
            self.write(args.first);
        },
        .zero_page => {
            self.write(0x05);
            self.write(args.first);
        },
        .zero_page_x => {
            self.write(0x15);
            self.write(args.first);
        },
        .absolute => {
            self.write(0x0D);
            self.write(args.first);
            self.write(args.second);
        },
        .absolute_x => {
            self.write(0x1D);
            self.write(args.first);
            self.write(args.second);
        },
        .absolute_y => {
            self.write(0x19);
            self.write(args.first);
            self.write(args.second);
        },
        .indirect_x => {
            self.write(0x01);
            self.write(args.first);
        },
        .indirect_y => {
            self.write(0x11);
            self.write(args.first);
        },
        else => {},
    }
}

pub fn eor(self: *Assembler, mode: Mode, args: Arg) void {
    switch (mode) {
        .immediate => {
            self.write(0x49);
            self.write(args.first);
        },
        .zero_page => {
            self.write(0x45);
            self.write(args.first);
        },
        .zero_page_x => {
            self.write(0x55);
            self.write(args.first);
        },
        .absolute => {
            self.write(0x4D);
            self.write(args.first);
            self.write(args.second);
        },
        .absolute_x => {
            self.write(0x5D);
            self.write(args.first);
            self.write(args.second);
        },
        .absolute_y => {
            self.write(0x59);
            self.write(args.first);
            self.write(args.second);
        },
        .indirect_x => {
            self.write(0x41);
            self.write(args.first);
        },
        .indirect_y => {
            self.write(0x51);
            self.write(args.first);
        },
        else => {},
    }
}

pub fn bit(self: *Assembler, mode: Mode, args: Arg) void {
    switch (mode) {
        .zero_page => {
            self.write(0x24);
            self.write(args.first);
        },
        .absolute => {
            self.write(0x2C);
            self.write(args.first);
            self.write(args.second);
        },
        else => {},
    }
}

pub fn cmp(self: *Assembler, mode: Mode, args: Arg) void {
    switch (mode) {
        .immediate => {
            self.write(0xC9);
            self.write(args.first);
        },
        .zero_page => {
            self.write(0xC5);
            self.write(args.first);
        },
        .zero_page_x => {
            self.write(0xD5);
            self.write(args.first);
        },
        .absolute => {
            self.write(0xCD);
            self.write(args.first);
            self.write(args.second);
        },
        .absolute_x => {
            self.write(0xDD);
            self.write(args.first);
            self.write(args.second);
        },
        .absolute_y => {
            self.write(0xD9);
            self.write(args.first);
            self.write(args.second);
        },
        .indirect_x => {
            self.write(0xC1);
            self.write(args.first);
        },
        .indirect_y => {
            self.write(0xD1);
            self.write(args.first);
        },
        else => {},
    }
}

pub fn cpx(self: *Assembler, mode: Mode, args: Arg) void {
    switch (mode) {
        .immediate => {
            self.write(0xE0);
            self.write(args.first);
        },
        .zero_page => {
            self.write(0xE4);
            self.write(args.first);
        },
        .absolute => {
            self.write(0xEC);
            self.write(args.first);
            self.write(args.second);
        },
        else => {},
    }
}

pub fn cpy(self: *Assembler, mode: Mode, args: Arg) void {
    switch (mode) {
        .immediate => {
            self.write(0xC0);
            self.write(args.first);
        },
        .zero_page => {
            self.write(0xC4);
            self.write(args.first);
        },
        .absolute => {
            self.write(0xCC);
            self.write(args.first);
            self.write(args.second);
        },
        else => {},
    }
}

pub fn beq(self: *Assembler, name: []const u8) void {
    const target = self.labels.get(name) orelse {
        @panic("label not found");
    };

    self.write(0xF0);
    self.write(self.calc_offset(target));
}

pub fn bne(self: *Assembler, name: []const u8) void {
    const target = self.labels.get(name) orelse {
        @panic("label not found");
    };

    self.write(0xD0);
    self.write(self.calc_offset(target));
}

pub fn jmp_label(self: *Assembler, name: []const u8) void {
    const target = self.labels.get(name) orelse {
        @panic("label not found");
    };

    self.write(0x4C);
    self.write(@truncate(target));
    self.write(@truncate(target >> 8));
}

fn calc_offset(self: Assembler, target: u16) u8 {
    var offset: u16 = 0x00;
    if (self.ptr > target) {
        offset = (self.ptr) - target;
        offset = ~offset;
    } else {
        offset = target - (self.ptr);
    }

    std.debug.print("offset: {X}\n", .{offset});
    return @truncate(offset);
}

fn write(self: *Assembler, value: u8) void {
    self.bus.write(self.ptr, value);
    self.ptr += 1;
}
