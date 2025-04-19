const std = @import("std");
const testing = std.testing;
const Chip = @import("../mos_technology_6502.zig").Chip;
const micro = @import("instructions.zig").micro;

pub const TestBus = struct {
    data: [64 * 1024]u8,

    pub fn read(self: TestBus, addr: u16) u8 {
        return self.data[addr];
    }
    pub fn write(self: *TestBus, addr: u16, value: u8) void {
        self.data[addr] = value;
    }

    pub fn setup(instruction: []const u8) TestBus {
        var bus = TestBus{
            .data = undefined,
        };
        @memset(&bus.data, 0xAA);

        // Set pc 0xF000
        bus.data[0xFFFC] = 0x00;
        bus.data[0xFFFD] = 0xF0;

        for (instruction, 0..) |data, index| {
            bus.data[0xF000 + index] = data;
        }

        return bus;
    }
};

test "lda #immediate" {
    // LDA #$42
    var bus = TestBus.setup(&.{ 0xA9, 0x42 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    cpu.clock();

    try std.testing.expectEqual(0x42, cpu.a);
}

test "lda zeroPage" {
    // LDA $A4
    var bus = TestBus.setup(&.{ 0xA5, 0xA4 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    bus.data[0x00A4] = 0xFA;

    cpu.clock();

    try std.testing.expectEqual(0xFA, cpu.a);
}

test "lda zeroPage,x (wrap)" {
    // LDA $F0,x
    var bus = TestBus.setup(&.{ 0xB5, 0xF0 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    bus.data[0x0012] = 0x10;
    cpu.x = 0x22;

    cpu.clock();

    try std.testing.expectEqual(0x10, cpu.a);
}

test "lda absolute" {
    // LDA $4264
    var bus = TestBus.setup(&.{ 0xAD, 0x64, 0x42 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    bus.data[0x4264] = 0xBC;

    cpu.clock();

    try std.testing.expectEqual(0xBC, cpu.a);
    try std.testing.expectEqual(3, cpu.cycles_left);
}

test "lda absolute,x" {
    // LDA $55F0,x
    var bus = TestBus.setup(&.{ 0xBD, 0xF0, 0x55 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.x = 0x20;
    bus.data[0x5610] = 0xAB;

    cpu.clock();

    try std.testing.expectEqual(0xAB, cpu.a);
    try std.testing.expectEqual(4, cpu.cycles_left);
}

test "lda absolute,y" {
    // LDA $55F0,y
    var bus = TestBus.setup(&.{ 0xB9, 0xF0, 0x55 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.y = 0x20;
    bus.data[0x5610] = 0xAB;

    cpu.clock();

    try std.testing.expectEqual(0xAB, cpu.a);
    try std.testing.expectEqual(4, cpu.cycles_left);
}

test "lda (indirect,x)" {
    // LDA ($F0,x)
    var bus = TestBus.setup(&.{ 0xA1, 0xF0 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.x = 0x25;
    bus.data[0x0015] = 0xAB;
    bus.data[0x0016] = 0x25;
    bus.data[0x25AB] = 0xCD;

    cpu.clock();

    try std.testing.expectEqual(0xCD, cpu.a);
}

test "lda (indirect),y" {
    // LDA ($55),y
    var bus = TestBus.setup(&.{ 0xB1, 0x55 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.y = 0x25;
    bus.data[0x0055] = 0xF0;
    bus.data[0x0056] = 0x50;
    bus.data[0x5115] = 0xCD;

    cpu.clock();

    try std.testing.expectEqual(0xCD, cpu.a);
    try std.testing.expectEqual(5, cpu.cycles_left);
}

test "lda flag z" {
    // LDA $4264
    var bus = TestBus.setup(&.{ 0xAD, 0x64, 0x42 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    bus.data[0x4264] = 0x00;

    cpu.clock();

    try std.testing.expectEqual(0x00, cpu.a);
    try std.testing.expect(cpu.status.isSet(.z));
}

test "lda flag n" {
    // LDA $4264
    var bus = TestBus.setup(&.{ 0xAD, 0x64, 0x42 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    bus.data[0x4264] = 0x81;

    cpu.clock();

    try std.testing.expectEqual(0x81, cpu.a);
    try std.testing.expect(cpu.status.isSet(.n));
}

test "sta zeroPage" {
    // STA $A4
    var bus = TestBus.setup(&.{ 0x85, 0xA4 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.a = 0xFA;

    cpu.clock();

    try std.testing.expectEqual(0xFA, bus.data[0x00A4]);
}

test "sta zeroPage,x (wrap)" {
    // STA $F0,x
    var bus = TestBus.setup(&.{ 0x95, 0xF0 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.x = 0x22;
    cpu.a = 0x10;

    cpu.clock();

    try std.testing.expectEqual(0x10, bus.data[0x0012]);
}

test "sta absolute" {
    // STA $4264
    var bus = TestBus.setup(&.{ 0x8D, 0x64, 0x42 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.a = 0xBC;

    cpu.clock();

    try std.testing.expectEqual(0xBC, bus.data[0x4264]);
}

test "sta absolute,x" {
    // STA $55F0,x
    var bus = TestBus.setup(&.{ 0x9D, 0xF0, 0x55 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.x = 0x20;
    cpu.a = 0xAB;

    cpu.clock();

    try std.testing.expectEqual(0xAB, bus.data[0x5610]);
    try std.testing.expectEqual(4, cpu.cycles_left);
}

test "sta absolute,y" {
    // STA $55F0,y
    var bus = TestBus.setup(&.{ 0x99, 0xF0, 0x55 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.y = 0x20;
    cpu.a = 0xAB;

    cpu.clock();

    try std.testing.expectEqual(0xAB, bus.data[0x5610]);
    try std.testing.expectEqual(4, cpu.cycles_left);
}

test "sta (indirect,x)" {
    // STA ($F0,x)
    var bus = TestBus.setup(&.{ 0x81, 0xF0 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.x = 0x25;
    bus.data[0x0015] = 0xAB;
    bus.data[0x0016] = 0x25;
    cpu.a = 0xCD;

    cpu.clock();

    try std.testing.expectEqual(0xCD, bus.data[0x25AB]);
}

test "sta (indirect),y" {
    // STA ($55),y
    var bus = TestBus.setup(&.{ 0x91, 0x55 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.y = 0x25;
    bus.data[0x0055] = 0xF0;
    bus.data[0x0056] = 0x50;
    cpu.a = 0xCD;

    cpu.clock();

    try std.testing.expectEqual(0xCD, bus.data[0x5115]);
    try std.testing.expectEqual(5, cpu.cycles_left);
}

test "ldx #immediate" {
    // LDX #$42
    var bus = TestBus.setup(&.{ 0xA2, 0x42 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    cpu.clock();

    try std.testing.expectEqual(0x42, cpu.x);
}

test "ldx zeroPage" {
    // LDX $A4
    var bus = TestBus.setup(&.{ 0xA6, 0xA4 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    bus.data[0x00A4] = 0xFA;

    cpu.clock();

    try std.testing.expectEqual(0xFA, cpu.x);
}

test "ldx zeroPage,y (wrap)" {
    // LDX $F0,y
    var bus = TestBus.setup(&.{ 0xB6, 0xF0 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    bus.data[0x0012] = 0x10;
    cpu.y = 0x22;

    cpu.clock();

    try std.testing.expectEqual(0x10, cpu.x);
}

test "ldx absolute" {
    // LDX $4264
    var bus = TestBus.setup(&.{ 0xAE, 0x64, 0x42 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    bus.data[0x4264] = 0xBC;

    cpu.clock();

    try std.testing.expectEqual(0xBC, cpu.x);
}

test "ldx absolute,y" {
    // LDX $55F0,y
    var bus = TestBus.setup(&.{ 0xBE, 0xF0, 0x55 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.y = 0x20;
    bus.data[0x5610] = 0xAB;

    cpu.clock();

    try std.testing.expectEqual(0xAB, cpu.x);
    try std.testing.expectEqual(4, cpu.cycles_left);
}

test "ldx flag z" {
    // LDX $4264
    var bus = TestBus.setup(&.{ 0xAE, 0x64, 0x42 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    bus.data[0x4264] = 0x00;

    cpu.clock();

    try std.testing.expectEqual(0x00, cpu.x);
    try std.testing.expect(cpu.status.isSet(.z));
}

test "ldx flag n" {
    // LDA $4264
    var bus = TestBus.setup(&.{ 0xAE, 0x64, 0x42 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    bus.data[0x4264] = 0x81;

    cpu.clock();

    try std.testing.expectEqual(0x81, cpu.x);
    try std.testing.expect(cpu.status.isSet(.n));
}

test "stx zeroPage" {
    // STX $A4
    var bus = TestBus.setup(&.{ 0x86, 0xA4 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.x = 0xFA;

    cpu.clock();

    try std.testing.expectEqual(0xFA, bus.data[0x00A4]);
}

test "stx zeroPage,y (wrap)" {
    // STX $F0,y
    var bus = TestBus.setup(&.{ 0x96, 0xF0 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.y = 0x22;
    cpu.x = 0x10;

    cpu.clock();

    try std.testing.expectEqual(0x10, bus.data[0x0012]);
}

test "stx absolute" {
    // STX $4264
    var bus = TestBus.setup(&.{ 0x8E, 0x64, 0x42 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.x = 0xBC;

    cpu.clock();

    try std.testing.expectEqual(0xBC, bus.data[0x4264]);
}

test "ldy #immediate" {
    // LDY #$42
    var bus = TestBus.setup(&.{ 0xA0, 0x42 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    cpu.clock();

    try std.testing.expectEqual(0x42, cpu.y);
}

test "ldy zeroPage" {
    // LDY $A4
    var bus = TestBus.setup(&.{ 0xA4, 0xA4 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    bus.data[0x00A4] = 0xFA;

    cpu.clock();

    try std.testing.expectEqual(0xFA, cpu.y);
}

test "ldy zeroPage,x (wrap)" {
    // LDY $F0,x
    var bus = TestBus.setup(&.{ 0xB4, 0xF0 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    bus.data[0x0012] = 0x10;
    cpu.x = 0x22;

    cpu.clock();

    try std.testing.expectEqual(0x10, cpu.y);
}

test "ldy absolute" {
    // LDY $4264
    var bus = TestBus.setup(&.{ 0xAC, 0x64, 0x42 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    bus.data[0x4264] = 0xBC;

    cpu.clock();

    try std.testing.expectEqual(0xBC, cpu.y);
}

test "ldy absolute,x" {
    // LDY $55F0,x
    var bus = TestBus.setup(&.{ 0xBC, 0xF0, 0x55 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.x = 0x20;
    bus.data[0x5610] = 0xAB;

    cpu.clock();

    try std.testing.expectEqual(0xAB, cpu.y);
    try std.testing.expectEqual(4, cpu.cycles_left);
}

test "jmp absolute" {
    // JMP $5025
    var bus = TestBus.setup(&.{ 0x4C, 0x25, 0x50 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    cpu.clock();

    try std.testing.expectEqual(0x5025, cpu.pc);
}

test "sty zeroPage" {
    // STY $A4
    var bus = TestBus.setup(&.{ 0x84, 0xA4 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.y = 0xFA;

    cpu.clock();

    try std.testing.expectEqual(0xFA, bus.data[0x00A4]);
}

test "sty zeroPage,x (wrap)" {
    // STY $F0,y
    var bus = TestBus.setup(&.{ 0x94, 0xF0 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.x = 0x22;
    cpu.y = 0x10;

    cpu.clock();

    try std.testing.expectEqual(0x10, bus.data[0x0012]);
}

test "sty absolute" {
    // STY $4264
    var bus = TestBus.setup(&.{ 0x8C, 0x64, 0x42 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.y = 0xBC;

    cpu.clock();

    try std.testing.expectEqual(0xBC, bus.data[0x4264]);
}

test "tax implied" {
    var bus = TestBus.setup(&.{0xAA});
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.a = 0xFA;

    cpu.clock();

    try std.testing.expectEqual(0xFA, cpu.x);
}

test "txa implied" {
    var bus = TestBus.setup(&.{0x8A});
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.x = 0xFA;

    cpu.clock();

    try std.testing.expectEqual(0xFA, cpu.a);
}

test "tay implied" {
    var bus = TestBus.setup(&.{0xA8});
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.a = 0xFA;

    cpu.clock();

    try std.testing.expectEqual(0xFA, cpu.y);
}

test "tya implied" {
    var bus = TestBus.setup(&.{0x98});
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.y = 0xFA;

    cpu.clock();

    try std.testing.expectEqual(0xFA, cpu.a);
}

test "adc #immediate" {
    // ADC #$50
    var bus = TestBus.setup(&.{ 0x69, 0x50 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.a = 0x50;

    cpu.clock();

    try testing.expectEqual(0xA0, cpu.a);
    try testing.expect(!cpu.status.isSet(.c));
    try testing.expect(cpu.status.isSet(.v));
    try testing.expect(cpu.status.isSet(.n));
}

test "adc zeroPage" {
    // ADC $50
    var bus = TestBus.setup(&.{ 0x65, 0x50 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    bus.data[0x0050] = 0x90;
    cpu.a = 0x90;

    cpu.clock();

    try testing.expectEqual(0x20, cpu.a);
    try testing.expect(cpu.status.isSet(.c));
    try testing.expect(cpu.status.isSet(.v));
    try testing.expect(!cpu.status.isSet(.n));
}

test "adc zeroPage,x" {
    // ADC $50,x
    var bus = TestBus.setup(&.{ 0x75, 0x50 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    bus.data[0x0055] = 0x00;
    cpu.a = 0xFF;
    cpu.x = 0x05;
    cpu.status.set(.c, true);

    cpu.clock();

    try testing.expectEqual(0x00, cpu.a);
    try testing.expect(cpu.status.isSet(.c));
    try testing.expect(!cpu.status.isSet(.v));
    try testing.expect(!cpu.status.isSet(.n));
}

test "adc absolute" {
    // ADC $5030
    var bus = TestBus.setup(&.{ 0x6D, 0x30, 0x50 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    bus.data[0x5030] = 0x01;
    cpu.a = 0x7F;

    cpu.clock();

    try testing.expectEqual(0x80, cpu.a);
    try testing.expect(!cpu.status.isSet(.c));
    try testing.expect(cpu.status.isSet(.v));
    try testing.expect(cpu.status.isSet(.n));
}

test "adc absolute,x" {
    // ADC $50E0,x
    var bus = TestBus.setup(&.{ 0x7D, 0xE0, 0x50 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    bus.data[0x5100] = 0x01;
    cpu.a = 0x7F;
    cpu.x = 0x20;

    cpu.clock();

    try testing.expectEqual(0x80, cpu.a);
    try testing.expect(!cpu.status.isSet(.c));
    try testing.expect(cpu.status.isSet(.v));
    try testing.expect(cpu.status.isSet(.n));
    try testing.expectEqual(4, cpu.cycles_left);
}

test "adc absolute,y" {
    // ADC $5030,x
    var bus = TestBus.setup(&.{ 0x79, 0x30, 0x50 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    bus.data[0x5040] = 0x01;
    cpu.a = 0x7F;
    cpu.y = 0x10;

    cpu.clock();

    try testing.expectEqual(0x80, cpu.a);
    try testing.expect(!cpu.status.isSet(.c));
    try testing.expect(cpu.status.isSet(.v));
    try testing.expect(cpu.status.isSet(.n));
    try testing.expectEqual(3, cpu.cycles_left);
}

test "adc (indirect,x)" {
    // ADC ($50,x)
    var bus = TestBus.setup(&.{ 0x61, 0x50 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    bus.data[0x0060] = 0x50;
    bus.data[0x0061] = 0x70; // 0x7050
    bus.data[0x7050] = 0xFF;
    cpu.x = 0x10;
    cpu.a = 0x80;

    cpu.clock();

    try testing.expectEqual(0x7F, cpu.a);
    try testing.expect(cpu.status.isSet(.c));
    try testing.expect(!cpu.status.isSet(.z));
    try testing.expect(cpu.status.isSet(.v));
}

test "adc (indirect),y" {
    // ADC ($50,x)
    var bus = TestBus.setup(&.{ 0x71, 0x50 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    bus.data[0x0050] = 0x50;
    bus.data[0x0051] = 0x70; // 0x7050
    bus.data[0x7060] = 0x00;
    cpu.y = 0x10;
    cpu.a = 0x00;

    cpu.clock();

    try testing.expectEqual(0x00, cpu.a);
    try testing.expect(!cpu.status.isSet(.c));
    try testing.expect(cpu.status.isSet(.z));
    try testing.expect(!cpu.status.isSet(.v));
    try testing.expectEqual(4, cpu.cycles_left);
}

test "jmp (indirect)" {
    // JMP ($ABBA)
    var bus = TestBus.setup(&.{ 0x6C, 0xBA, 0xAB });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    bus.data[0xABBA] = 0x34;
    bus.data[0xABBB] = 0x12;

    cpu.clock();

    try std.testing.expectEqual(0x1234, cpu.pc);
}

test "jsr absolute" {
    // JSR $2548
    var bus = TestBus.setup(&.{ 0x20, 0x48, 0x25 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    cpu.sp = 0x50;

    cpu.clock();

    try std.testing.expectEqual(0x2548, cpu.pc);
    try std.testing.expectEqual(0x02, bus.data[micro.getSpAbs(cpu) + 1]);
    try std.testing.expectEqual(0xF0, bus.data[micro.getSpAbs(cpu) + 2]);
}

test "rts implied" {
    var bus = TestBus.setup(&.{0x60});
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    cpu.sp = 0x50;
    // 0x45BA
    bus.data[micro.getSpAbs(cpu) + 1] = 0xBA;
    bus.data[micro.getSpAbs(cpu) + 2] = 0x45;

    cpu.clock();

    try std.testing.expectEqual(0x45BB, cpu.pc);
}

test "brk implied" {
    var bus = TestBus.setup(&.{0x00});
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    // 0xCCBB
    bus.data[0xFFFE] = 0xBB;
    bus.data[0xFFFF] = 0xCC;

    cpu.sp = 0x10;
    cpu.status.set(.n, true);
    cpu.status.set(.v, true);

    cpu.clock();

    try std.testing.expectEqual(0xCCBB, cpu.pc);
    try std.testing.expectEqual(0xD4, bus.data[micro.getSpAbs(cpu) + 1]);
    try std.testing.expectEqual(0x02, bus.data[micro.getSpAbs(cpu) + 2]);
    try std.testing.expectEqual(0xF0, bus.data[micro.getSpAbs(cpu) + 3]);
    try std.testing.expectEqual(0xCCBB, cpu.pc);
}

test "rti implied" {
    var bus = TestBus.setup(&.{0x40});
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.sp = 0x10;
    bus.data[micro.getSpAbs(cpu) + 1] = 0xD4; // Stack 0b11010100
    bus.data[micro.getSpAbs(cpu) + 2] = 0xBB;
    bus.data[micro.getSpAbs(cpu) + 3] = 0xCC; // 0xCCBB

    cpu.clock();

    try std.testing.expectEqual(0b11000100, cpu.status.data);
    try std.testing.expectEqual(0xCCBB, cpu.pc);
}

test "pha implied" {
    var bus = TestBus.setup(&.{0x48});
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.sp = 0xAB;
    cpu.a = 0xFA;

    cpu.clock();

    try std.testing.expectEqual(0xFA, bus.data[micro.getSpAbs(cpu) + 1]);
}

test "pla implied" {
    var bus = TestBus.setup(&.{0x68});
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.sp = 0x58;
    bus.data[0x59 + 0x0100] = 0xAA;

    cpu.clock();

    try std.testing.expectEqual(0xAA, cpu.a);
}

test "pla flag z" {
    var bus = TestBus.setup(&.{0x68});
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.sp = 0xA1;
    bus.data[0xA2 + 0x0100] = 0x00;

    cpu.clock();

    try std.testing.expect(cpu.status.isSet(.z));
}

test "pla flag n" {
    var bus = TestBus.setup(&.{0x68});
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.sp = 0x82;
    bus.data[0x83 + 0x0100] = 0xAA;

    cpu.clock();

    try std.testing.expect(cpu.status.isSet(.n));
}

test "php implied" {
    var bus = TestBus.setup(&.{0x08});
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.sp = 0x14;
    cpu.status.data = 0b11001101;

    cpu.clock();

    try std.testing.expectEqual(0b11111101, bus.data[micro.getSpAbs(cpu) + 1]);
}

test "plp implied" {
    var bus = TestBus.setup(&.{0x28});
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.sp = 0x24;
    bus.data[0x25 + 0x0100] = 0b11111111;
    cpu.status.set(.b, false);
    cpu.status.set(.u, false);

    cpu.clock();

    try std.testing.expect(cpu.status.isSet(.c));
    try std.testing.expect(cpu.status.isSet(.z));
    try std.testing.expect(cpu.status.isSet(.i));
    try std.testing.expect(cpu.status.isSet(.d));
    try std.testing.expect(cpu.status.isSet(.v));
    try std.testing.expect(cpu.status.isSet(.n));

    try std.testing.expect(!cpu.status.isSet(.b));
    try std.testing.expect(!cpu.status.isSet(.u));
}

test "txs implied" {
    var bus = TestBus.setup(&.{0x9A});
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.x = 0xBB;

    cpu.clock();

    try std.testing.expectEqual(cpu.sp, 0xBB);
}

test "tsx implied" {
    var bus = TestBus.setup(&.{0xBA});
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.sp = 0xAA;

    cpu.clock();

    try std.testing.expectEqual(cpu.x, 0xAA);
}

test "tsx flag z" {
    var bus = TestBus.setup(&.{0xBA});
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.sp = 0x00;

    cpu.clock();

    try std.testing.expect(cpu.status.isSet(.z));
}

test "tsx flag n" {
    var bus = TestBus.setup(&.{0xBA});
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.sp = 0b10010100;

    cpu.clock();

    try std.testing.expect(cpu.status.isSet(.n));
}

test "clc implied" {
    var bus = TestBus.setup(&.{0x18});
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.status.set(.c, true);

    cpu.clock();

    try std.testing.expectEqual(cpu.status.isSet(.c), false);
}

test "sec implied" {
    var bus = TestBus.setup(&.{0x38});
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.status.set(.c, false);

    cpu.clock();

    try std.testing.expectEqual(cpu.status.isSet(.c), true);
}

test "cli implied" {
    var bus = TestBus.setup(&.{0x58});
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.status.set(.i, true);

    cpu.clock();

    try std.testing.expectEqual(cpu.status.isSet(.i), false);
}

test "sei implied" {
    var bus = TestBus.setup(&.{0x78});
    var cpu = Chip(TestBus).init(&bus);

    cpu.powerOn();

    // Prepare data
    cpu.status.set(.i, false);

    cpu.clock();

    try std.testing.expectEqual(cpu.status.isSet(.i), true);
}

test "cld implied" {
    var bus = TestBus.setup(&.{0xD8});
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.status.set(.d, true);

    cpu.clock();

    try std.testing.expectEqual(cpu.status.isSet(.d), false);
}

test "sed implied" {
    var bus = TestBus.setup(&.{0xF8});
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.status.set(.d, false);

    cpu.clock();

    try std.testing.expectEqual(true, cpu.status.isSet(.d));
}

test "clv implied" {
    var bus = TestBus.setup(&.{0xB8});
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.status.set(.v, true);

    cpu.clock();

    try std.testing.expectEqual(false, cpu.status.isSet(.v));
}

test "nop implied" {
    var bus = TestBus.setup(&.{0xEA});
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    cpu.clock();
}
