const std = @import("std");
const Bus = @import("Bus.zig");
const Instruction = @import("Instruction.zig");
const Mode = Instruction.Mode;

const Assembler = @This();

bus: Bus,
ptr: u16,

pub fn init(bus: Bus, start: u16) Assembler {
    return .{
        .bus = bus,
        .ptr = start,
    };
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

fn write(self: *Assembler, value: u8) void {
    self.bus.write(self.ptr, value);
    self.ptr += 1;
}
