const std = @import("std");
const testing = std.testing;
const Chip = @import("../mos_technology_6502.zig").Chip;
const Bus = @import("Bus.zig");
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
        var b = TestBus{
            .data = undefined,
        };
        @memset(&b.data, 0xEA);

        // Set pc 0xF000
        b.data[0xFFFC] = 0x00;
        b.data[0xFFFD] = 0xF0;

        for (instruction, 0..) |data, index| {
            b.data[0xF000 + index] = data;
        }

        return b;
    }

    fn readVTable(ptr: *anyopaque, addr: u16) u8 {
        const self: *TestBus = @ptrCast(@alignCast(ptr));
        return self.read(addr);
    }

    fn writeVTable(ptr: *anyopaque, addr: u16, value: u8) void {
        const self: *TestBus = @ptrCast(@alignCast(ptr));
        self.write(addr, value);
    }

    pub fn bus(self: *TestBus) Bus {
        return .{
            .ptr = self,
            .vtable = &.{
                .read = readVTable,
                .write = writeVTable,
            },
        };
    }
};

test "lda #immediate" {
    // LDA #$42
    var bus = TestBus.setup(&.{ 0xA9, 0x42 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.clock();

    try std.testing.expectEqual(0x42, cpu.a);
}

test "lda zeroPage" {
    // LDA $A4
    var bus = TestBus.setup(&.{ 0xA5, 0xA4 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    // Prepare data
    bus.data[0x00A4] = 0xFA;

    cpu.clock();

    try std.testing.expectEqual(0xFA, cpu.a);
}

test "lda zeroPage,x (wrap)" {
    // LDA $F0,x
    var bus = TestBus.setup(&.{ 0xB5, 0xF0 });
    var cpu = Chip.init(bus.bus());
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
    var cpu = Chip.init(bus.bus());
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
    var cpu = Chip.init(bus.bus());
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
    var cpu = Chip.init(bus.bus());
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
    var cpu = Chip.init(bus.bus());
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
    var cpu = Chip.init(bus.bus());
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
    var cpu = Chip.init(bus.bus());
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
    var cpu = Chip.init(bus.bus());
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
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    // Prepare data
    cpu.a = 0xFA;

    cpu.clock();

    try std.testing.expectEqual(0xFA, bus.data[0x00A4]);
}

test "sta zeroPage,x (wrap)" {
    // STA $F0,x
    var bus = TestBus.setup(&.{ 0x95, 0xF0 });
    var cpu = Chip.init(bus.bus());
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
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    // Prepare data
    cpu.a = 0xBC;

    cpu.clock();

    try std.testing.expectEqual(0xBC, bus.data[0x4264]);
}

test "sta absolute,x" {
    // STA $55F0,x
    var bus = TestBus.setup(&.{ 0x9D, 0xF0, 0x55 });
    var cpu = Chip.init(bus.bus());
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
    var cpu = Chip.init(bus.bus());
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
    var cpu = Chip.init(bus.bus());
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
    var cpu = Chip.init(bus.bus());
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
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.clock();

    try std.testing.expectEqual(0x42, cpu.x);
}

test "ldx zeroPage" {
    // LDX $A4
    var bus = TestBus.setup(&.{ 0xA6, 0xA4 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    // Prepare data
    bus.data[0x00A4] = 0xFA;

    cpu.clock();

    try std.testing.expectEqual(0xFA, cpu.x);
}

test "ldx zeroPage,y (wrap)" {
    // LDX $F0,y
    var bus = TestBus.setup(&.{ 0xB6, 0xF0 });
    var cpu = Chip.init(bus.bus());
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
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    // Prepare data
    bus.data[0x4264] = 0xBC;

    cpu.clock();

    try std.testing.expectEqual(0xBC, cpu.x);
}

test "ldx absolute,y" {
    // LDX $55F0,y
    var bus = TestBus.setup(&.{ 0xBE, 0xF0, 0x55 });
    var cpu = Chip.init(bus.bus());
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
    var cpu = Chip.init(bus.bus());
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
    var cpu = Chip.init(bus.bus());
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
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    // Prepare data
    cpu.x = 0xFA;

    cpu.clock();

    try std.testing.expectEqual(0xFA, bus.data[0x00A4]);
}

test "stx zeroPage,y (wrap)" {
    // STX $F0,y
    var bus = TestBus.setup(&.{ 0x96, 0xF0 });
    var cpu = Chip.init(bus.bus());
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
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    // Prepare data
    cpu.x = 0xBC;

    cpu.clock();

    try std.testing.expectEqual(0xBC, bus.data[0x4264]);
}

test "ldy #immediate" {
    // LDY #$42
    var bus = TestBus.setup(&.{ 0xA0, 0x42 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.clock();

    try std.testing.expectEqual(0x42, cpu.y);
}

test "ldy zeroPage" {
    // LDY $A4
    var bus = TestBus.setup(&.{ 0xA4, 0xA4 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    // Prepare data
    bus.data[0x00A4] = 0xFA;

    cpu.clock();

    try std.testing.expectEqual(0xFA, cpu.y);
}

test "ldy zeroPage,x (wrap)" {
    // LDY $F0,x
    var bus = TestBus.setup(&.{ 0xB4, 0xF0 });
    var cpu = Chip.init(bus.bus());
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
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    // Prepare data
    bus.data[0x4264] = 0xBC;

    cpu.clock();

    try std.testing.expectEqual(0xBC, cpu.y);
}

test "ldy absolute,x" {
    // LDY $55F0,x
    var bus = TestBus.setup(&.{ 0xBC, 0xF0, 0x55 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    // Prepare data
    cpu.x = 0x20;
    bus.data[0x5610] = 0xAB;

    cpu.clock();

    try std.testing.expectEqual(0xAB, cpu.y);
    try std.testing.expectEqual(4, cpu.cycles_left);
}

test "sty zeroPage" {
    // STY $A4
    var bus = TestBus.setup(&.{ 0x84, 0xA4 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    // Prepare data
    cpu.y = 0xFA;

    cpu.clock();

    try std.testing.expectEqual(0xFA, bus.data[0x00A4]);
}

test "sty zeroPage,x (wrap)" {
    // STY $F0,y
    var bus = TestBus.setup(&.{ 0x94, 0xF0 });
    var cpu = Chip.init(bus.bus());
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
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    // Prepare data
    cpu.y = 0xBC;

    cpu.clock();

    try std.testing.expectEqual(0xBC, bus.data[0x4264]);
}

test "tax implied" {
    var bus = TestBus.setup(&.{0xAA});
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    // Prepare data
    cpu.a = 0xFA;

    cpu.clock();

    try std.testing.expectEqual(0xFA, cpu.x);
}

test "txa implied" {
    var bus = TestBus.setup(&.{0x8A});
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    // Prepare data
    cpu.x = 0xFA;

    cpu.clock();

    try std.testing.expectEqual(0xFA, cpu.a);
}

test "tay implied" {
    var bus = TestBus.setup(&.{0xA8});
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    // Prepare data
    cpu.a = 0xFA;

    cpu.clock();

    try std.testing.expectEqual(0xFA, cpu.y);
}

test "tya implied" {
    var bus = TestBus.setup(&.{0x98});
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    // Prepare data
    cpu.y = 0xFA;

    cpu.clock();

    try std.testing.expectEqual(0xFA, cpu.a);
}

test "adc #immediate" {
    // ADC #$50
    var bus = TestBus.setup(&.{ 0x69, 0x50 });
    var cpu = Chip.init(bus.bus());
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
    var cpu = Chip.init(bus.bus());
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
    var cpu = Chip.init(bus.bus());
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
    var cpu = Chip.init(bus.bus());
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
    var cpu = Chip.init(bus.bus());
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
    var cpu = Chip.init(bus.bus());
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
    var cpu = Chip.init(bus.bus());
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
    var cpu = Chip.init(bus.bus());
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

test "sbc #immediate" {
    // SBC #$10
    var bus = TestBus.setup(&.{ 0xE9, 0x10 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.a = 0x20;
    cpu.status.set(.c, true);

    cpu.clock();

    try testing.expectEqual(0x10, cpu.a);
    try testing.expect(cpu.status.isSet(.c));
    try testing.expect(!cpu.status.isSet(.z));
    try testing.expect(!cpu.status.isSet(.v));
    try testing.expect(!cpu.status.isSet(.n));
}

test "sbc zeroPage" {
    // SBC $50
    var bus = TestBus.setup(&.{ 0xE5, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    bus.data[0x0050] = 0x20;
    cpu.a = 0x20;
    cpu.status.set(.c, true);

    cpu.clock();

    try testing.expectEqual(0x00, cpu.a);
    try testing.expect(cpu.status.isSet(.c));
    try testing.expect(cpu.status.isSet(.z));
    try testing.expect(!cpu.status.isSet(.v));
    try testing.expect(!cpu.status.isSet(.n));
}

test "sbc zeroPage,x" {
    // SBC $50,x
    var bus = TestBus.setup(&.{ 0xF5, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    bus.data[0x0055] = 0x01;
    cpu.a = 0x00;
    cpu.x = 0x05;
    cpu.status.set(.c, false); // simulate borrow (subtract 1 more)

    cpu.clock();

    try testing.expectEqual(0xFE, cpu.a);
    try testing.expect(!cpu.status.isSet(.c));
    try testing.expect(!cpu.status.isSet(.z));
    try testing.expect(!cpu.status.isSet(.v));
    try testing.expect(cpu.status.isSet(.n));
}

test "sbc absolute" {
    // SBC $5030
    var bus = TestBus.setup(&.{ 0xED, 0x30, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    bus.data[0x5030] = 0x80;
    cpu.a = 0x7F;
    cpu.status.set(.c, true);

    cpu.clock();

    try testing.expectEqual(0xFF, cpu.a);
    try testing.expect(!cpu.status.isSet(.c));
    try testing.expect(!cpu.status.isSet(.z));
    try testing.expect(cpu.status.isSet(.v));
    try testing.expect(cpu.status.isSet(.n));
}

test "sbc absolute,x" {
    // SBC $50E0,x
    var bus = TestBus.setup(&.{ 0xFD, 0xE0, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    bus.data[0x5100] = 0x01;
    cpu.a = 0x01;
    cpu.x = 0x20;
    cpu.status.set(.c, true);

    cpu.clock();

    try testing.expectEqual(0x00, cpu.a);
    try testing.expect(cpu.status.isSet(.z));
    try testing.expect(cpu.status.isSet(.c));
    try testing.expect(!cpu.status.isSet(.v));
    try testing.expect(!cpu.status.isSet(.n));
}

test "sbc absolute,y" {
    // SBC $5030,y
    var bus = TestBus.setup(&.{ 0xF9, 0x30, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    bus.data[0x5040] = 0x01;
    cpu.a = 0x01;
    cpu.y = 0x10;
    cpu.status.set(.c, true);

    cpu.clock();

    try testing.expectEqual(0x00, cpu.a);
    try testing.expect(cpu.status.isSet(.z));
    try testing.expect(cpu.status.isSet(.c));
    try testing.expect(!cpu.status.isSet(.n));
}

test "sbc (indirect,x)" {
    // SBC ($50,x)
    var bus = TestBus.setup(&.{ 0xE1, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    bus.data[0x0060] = 0x50;
    bus.data[0x0061] = 0x70; // 0x7050
    bus.data[0x7050] = 0x01;
    cpu.x = 0x10;
    cpu.a = 0x01;
    cpu.status.set(.c, true);

    cpu.clock();

    try testing.expectEqual(0x00, cpu.a);
    try testing.expect(cpu.status.isSet(.z));
    try testing.expect(cpu.status.isSet(.c));
    try testing.expect(!cpu.status.isSet(.v));
    try testing.expect(!cpu.status.isSet(.n));
}

test "sbc (indirect),y" {
    // SBC ($50),y
    var bus = TestBus.setup(&.{ 0xF1, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    bus.data[0x0050] = 0x50;
    bus.data[0x0051] = 0x70; // 0x7050
    bus.data[0x7060] = 0x01;
    cpu.y = 0x10;
    cpu.a = 0x01;
    cpu.status.set(.c, true);

    cpu.clock();

    try testing.expectEqual(0x00, cpu.a);
    try testing.expect(cpu.status.isSet(.z));
    try testing.expect(cpu.status.isSet(.c));
    try testing.expect(!cpu.status.isSet(.v));
    try testing.expect(!cpu.status.isSet(.n));
}

test "inc zeroPage" {
    // INC $50
    var bus = TestBus.setup(&.{ 0xE6, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    // Prepare memory
    bus.data[0x0050] = 0x01;

    cpu.clock();

    try testing.expectEqual(@as(u8, 0x02), bus.data[0x0050]);
    try testing.expect(!cpu.status.isSet(.z));
    try testing.expect(!cpu.status.isSet(.n));
}

test "inc zeroPage,x" {
    // INC $50,X
    var bus = TestBus.setup(&.{ 0xF6, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.x = 0x05;
    bus.data[0x0055] = 0xFF;

    cpu.clock();

    try testing.expectEqual(@as(u8, 0x00), bus.data[0x0055]);
    try testing.expect(cpu.status.isSet(.z));
    try testing.expect(!cpu.status.isSet(.n));
}

test "inc absolute" {
    // INC $5030
    var bus = TestBus.setup(&.{ 0xEE, 0x30, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    bus.data[0x5030] = 0x7F;

    cpu.clock();

    try testing.expectEqual(@as(u8, 0x80), bus.data[0x5030]);
    try testing.expect(!cpu.status.isSet(.z));
    try testing.expect(cpu.status.isSet(.n));
}

test "inc absolute,x" {
    // INC $50E0,X
    var bus = TestBus.setup(&.{ 0xFE, 0xE0, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.x = 0x10;
    bus.data[0x50F0] = 0xFF;

    cpu.clock();

    try testing.expectEqual(@as(u8, 0x00), bus.data[0x50F0]);
    try testing.expect(cpu.status.isSet(.z));
    try testing.expect(!cpu.status.isSet(.n));
}

test "dec zeroPage" {
    // DEC $50
    var bus = TestBus.setup(&.{ 0xC6, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    bus.data[0x0050] = 0x02;

    cpu.clock();

    try testing.expectEqual(@as(u8, 0x01), bus.data[0x0050]);
    try testing.expect(!cpu.status.isSet(.z));
    try testing.expect(!cpu.status.isSet(.n));
}

test "dec zeroPage,x" {
    // DEC $50,X
    var bus = TestBus.setup(&.{ 0xD6, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.x = 0x05;
    bus.data[0x0055] = 0x01;

    cpu.clock();

    try testing.expectEqual(@as(u8, 0x00), bus.data[0x0055]);
    try testing.expect(cpu.status.isSet(.z));
    try testing.expect(!cpu.status.isSet(.n));
}

test "dec absolute" {
    // DEC $5030
    var bus = TestBus.setup(&.{ 0xCE, 0x30, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    bus.data[0x5030] = 0x80;

    cpu.clock();

    try testing.expectEqual(@as(u8, 0x7F), bus.data[0x5030]);
    try testing.expect(!cpu.status.isSet(.z));
    try testing.expect(!cpu.status.isSet(.n));
}

test "dec absolute,x" {
    // DEC $50E0,X
    var bus = TestBus.setup(&.{ 0xDE, 0xE0, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.x = 0x10;
    bus.data[0x50F0] = 0x00;

    cpu.clock();

    try testing.expectEqual(@as(u8, 0xFF), bus.data[0x50F0]);
    try testing.expect(!cpu.status.isSet(.z));
    try testing.expect(cpu.status.isSet(.n));
}

test "inx implied" {
    var bus = TestBus.setup(&.{0xE8});
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.x = 0xFF;
    cpu.clock(); // wrap to 0

    try std.testing.expectEqual(@as(u8, 0x00), cpu.x);
    try std.testing.expect(cpu.status.isSet(.z));
    try std.testing.expect(!cpu.status.isSet(.n));
}

test "dex implied" {
    var bus = TestBus.setup(&.{0xCA});
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.x = 0x01;
    cpu.clock(); // → 0x00

    try std.testing.expectEqual(@as(u8, 0x00), cpu.x);
    try std.testing.expect(cpu.status.isSet(.z));
    try std.testing.expect(!cpu.status.isSet(.n));
}

test "iny implied" {
    var bus = TestBus.setup(&.{0xC8});
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.y = 0xFF;
    cpu.clock(); // → 0x00

    try std.testing.expectEqual(@as(u8, 0x00), cpu.y);
    try std.testing.expect(cpu.status.isSet(.z));
    try std.testing.expect(!cpu.status.isSet(.n));
}

test "dey implied" {
    var bus = TestBus.setup(&.{0x88});
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.y = 0x01;
    cpu.clock(); // → 0x00

    try std.testing.expectEqual(@as(u8, 0x00), cpu.y);
    try std.testing.expect(cpu.status.isSet(.z));
    try std.testing.expect(!cpu.status.isSet(.n));
}

test "asl accumulator" {
    var bus = TestBus.setup(&.{0x0A});
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.a = 0b1010_0001; // 0xA1

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0x42), cpu.a); // 0xA1 << 1 = 0x142 → 0x42
    try std.testing.expect(cpu.status.isSet(.c)); // bit 7 was 1
    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(!cpu.status.isSet(.n));
}

test "asl zeroPage" {
    var bus = TestBus.setup(&.{ 0x06, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    bus.data[0x0050] = 0x40;

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0x80), bus.data[0x0050]);
    try std.testing.expect(!cpu.status.isSet(.c));
    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(cpu.status.isSet(.n));
}

test "asl zeroPage,x" {
    var bus = TestBus.setup(&.{ 0x16, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.x = 0x05;
    bus.data[0x0055] = 0x80;

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0x00), bus.data[0x0055]);
    try std.testing.expect(cpu.status.isSet(.c));
    try std.testing.expect(cpu.status.isSet(.z));
    try std.testing.expect(!cpu.status.isSet(.n));
}

test "asl absolute" {
    var bus = TestBus.setup(&.{ 0x0E, 0x30, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    bus.data[0x5030] = 0xFF;

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0xFE), bus.data[0x5030]);
    try std.testing.expect(cpu.status.isSet(.c)); // bit 7 was set
    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(cpu.status.isSet(.n));
}

test "asl absolute,x" {
    var bus = TestBus.setup(&.{ 0x1E, 0xE0, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.x = 0x10;
    bus.data[0x50F0] = 0x01;

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0x02), bus.data[0x50F0]);
    try std.testing.expect(!cpu.status.isSet(.c));
    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(!cpu.status.isSet(.n));
}

test "lsr accumulator" {
    var bus = TestBus.setup(&.{0x4A});
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.a = 0b0000_0011; // bit 0 is 1 → C set, result is 0x01

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0x01), cpu.a);
    try std.testing.expect(cpu.status.isSet(.c)); // bit 0 was 1
    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(!cpu.status.isSet(.n));
}

test "lsr zeroPage" {
    var bus = TestBus.setup(&.{ 0x46, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    bus.data[0x0050] = 0b0000_0001;

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0x00), bus.data[0x0050]);
    try std.testing.expect(cpu.status.isSet(.c)); // bit 0 was 1
    try std.testing.expect(cpu.status.isSet(.z));
    try std.testing.expect(!cpu.status.isSet(.n));
}

test "lsr zeroPage,x" {
    var bus = TestBus.setup(&.{ 0x56, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.x = 0x05;
    bus.data[0x0055] = 0b1000_0000;

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0x40), bus.data[0x0055]);
    try std.testing.expect(!cpu.status.isSet(.c)); // bit 0 was 0
    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(!cpu.status.isSet(.n));
}

test "lsr absolute" {
    var bus = TestBus.setup(&.{ 0x4E, 0x30, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    bus.data[0x5030] = 0x01;

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0x00), bus.data[0x5030]);
    try std.testing.expect(cpu.status.isSet(.c)); // bit 0 was 1
    try std.testing.expect(cpu.status.isSet(.z));
    try std.testing.expect(!cpu.status.isSet(.n));
}

test "lsr absolute,x" {
    var bus = TestBus.setup(&.{ 0x5E, 0xE0, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.x = 0x10;
    bus.data[0x50F0] = 0xFF;

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0x7F), bus.data[0x50F0]);
    try std.testing.expect(cpu.status.isSet(.c)); // bit 0 was 1
    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(!cpu.status.isSet(.n)); // result is 0x7F
}

test "rol accumulator" {
    var bus = TestBus.setup(&.{0x2A});
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.a = 0b0100_0001; // bit 7 = 0, carry in = 1 → expect: 0b1000_0011
    cpu.status.set(.c, true);

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0b1000_0011), cpu.a);
    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(cpu.status.isSet(.n));
    try std.testing.expect(!cpu.status.isSet(.c)); // bit 7 was 0
}

test "rol zeroPage" {
    var bus = TestBus.setup(&.{ 0x26, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    bus.data[0x0050] = 0b1000_0000;
    cpu.status.set(.c, false); // carry in = 0

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0x00), bus.data[0x0050]); // shifted out 1, in 0
    try std.testing.expect(cpu.status.isSet(.z));
    try std.testing.expect(!cpu.status.isSet(.n));
    try std.testing.expect(cpu.status.isSet(.c)); // bit 7 was 1
}

test "rol zeroPage,x" {
    var bus = TestBus.setup(&.{ 0x36, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.x = 0x05;
    bus.data[0x0055] = 0b0000_0000;
    cpu.status.set(.c, true); // carry in = 1

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0b0000_0001), bus.data[0x0055]);
    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(!cpu.status.isSet(.n));
    try std.testing.expect(!cpu.status.isSet(.c));
}

test "rol absolute" {
    var bus = TestBus.setup(&.{ 0x2E, 0x30, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    bus.data[0x5030] = 0b1111_1111;
    cpu.status.set(.c, false);

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0b1111_1110), bus.data[0x5030]);
    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(cpu.status.isSet(.n));
    try std.testing.expect(cpu.status.isSet(.c));
}

test "rol absolute,x" {
    var bus = TestBus.setup(&.{ 0x3E, 0xE0, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.x = 0x10;
    bus.data[0x50F0] = 0b0100_0000;
    cpu.status.set(.c, true);

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0b1000_0001), bus.data[0x50F0]);
    try std.testing.expect(cpu.status.isSet(.n));
    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(!cpu.status.isSet(.c)); // bit 7 was 0
}

test "ror accumulator" {
    var bus = TestBus.setup(&.{0x6A});
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.a = 0b0000_0011;
    cpu.status.set(.c, true); // carry in becomes bit 7

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0b1000_0001), cpu.a);
    try std.testing.expect(cpu.status.isSet(.c)); // bit 0 was 1
    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(cpu.status.isSet(.n));
}

test "ror zeroPage" {
    var bus = TestBus.setup(&.{ 0x66, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    bus.data[0x0050] = 0b0000_0001;
    cpu.status.set(.c, false); // bit 7 = 0 after rotate

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0b0000_0000), bus.data[0x0050]);
    try std.testing.expect(cpu.status.isSet(.c)); // bit 0 was 1
    try std.testing.expect(cpu.status.isSet(.z));
    try std.testing.expect(!cpu.status.isSet(.n));
}

test "ror zeroPage,x" {
    var bus = TestBus.setup(&.{ 0x76, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.x = 0x05;
    bus.data[0x0055] = 0b1111_1110;
    cpu.status.set(.c, true);

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0b1111_1111), bus.data[0x0055]);
    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(cpu.status.isSet(.n));
    try std.testing.expect(!cpu.status.isSet(.c)); // bit 0 was 0
}

test "ror absolute" {
    var bus = TestBus.setup(&.{ 0x6E, 0x30, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    bus.data[0x5030] = 0b0000_0001;
    cpu.status.set(.c, true); // C becomes bit 7

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0b1000_0000), bus.data[0x5030]);
    try std.testing.expect(cpu.status.isSet(.c)); // bit 0 was 1
    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(cpu.status.isSet(.n));
}

test "ror absolute,x" {
    var bus = TestBus.setup(&.{ 0x7E, 0xE0, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.x = 0x10;
    bus.data[0x50F0] = 0b0000_0000;
    cpu.status.set(.c, true);

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0b1000_0000), bus.data[0x50F0]);
    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(cpu.status.isSet(.n));
    try std.testing.expect(!cpu.status.isSet(.c)); // bit 0 was 0
}

test "and #immediate" {
    var bus = TestBus.setup(&.{ 0x29, 0x0F });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.a = 0x3C;

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0x0C), cpu.a);
    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(!cpu.status.isSet(.n));
}

test "and zeroPage" {
    var bus = TestBus.setup(&.{ 0x25, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.a = 0xF0;
    bus.data[0x0050] = 0x0F;

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0x00), cpu.a);
    try std.testing.expect(cpu.status.isSet(.z));
    try std.testing.expect(!cpu.status.isSet(.n));
}

test "and zeroPage,x" {
    var bus = TestBus.setup(&.{ 0x35, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.x = 0x05;
    cpu.a = 0b1100_1100;
    bus.data[0x0055] = 0b1000_1000;

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0b1000_1000), cpu.a);
    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(cpu.status.isSet(.n));
}

test "and absolute" {
    var bus = TestBus.setup(&.{ 0x2D, 0x30, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.a = 0xAA;
    bus.data[0x5030] = 0xF0;

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0xA0), cpu.a);
    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(cpu.status.isSet(.n));
}

test "and absolute,x" {
    var bus = TestBus.setup(&.{ 0x3D, 0xE0, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.x = 0x10;
    cpu.a = 0x0F;
    bus.data[0x50F0] = 0xF0;

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0x00), cpu.a);
    try std.testing.expect(cpu.status.isSet(.z));
    try std.testing.expect(!cpu.status.isSet(.n));
}

test "and absolute,y" {
    var bus = TestBus.setup(&.{ 0x39, 0x30, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.y = 0x10;
    cpu.a = 0xF0;
    bus.data[0x5040] = 0x80;

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0x80), cpu.a);
    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(cpu.status.isSet(.n));
}

test "and (indirect,x)" {
    var bus = TestBus.setup(&.{ 0x21, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.x = 0x10;
    cpu.a = 0xF0;

    bus.data[0x0060] = 0x00;
    bus.data[0x0061] = 0x70;
    bus.data[0x7000] = 0x0F;

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0x00), cpu.a);
    try std.testing.expect(cpu.status.isSet(.z));
    try std.testing.expect(!cpu.status.isSet(.n));
}

test "and (indirect),y" {
    var bus = TestBus.setup(&.{ 0x31, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.y = 0x10;
    cpu.a = 0xF0;

    bus.data[0x0050] = 0x00;
    bus.data[0x0051] = 0x70;
    bus.data[0x7010] = 0x0F;

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0x00), cpu.a);
    try std.testing.expect(cpu.status.isSet(.z));
    try std.testing.expect(!cpu.status.isSet(.n));
}

test "ora #immediate" {
    var bus = TestBus.setup(&.{ 0x09, 0x0F });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.a = 0xF0;

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0xFF), cpu.a);
    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(cpu.status.isSet(.n));
}

test "ora zeroPage" {
    var bus = TestBus.setup(&.{ 0x05, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.a = 0x00;
    bus.data[0x0050] = 0x00;

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0x00), cpu.a);
    try std.testing.expect(cpu.status.isSet(.z));
    try std.testing.expect(!cpu.status.isSet(.n));
}

test "ora zeroPage,x" {
    var bus = TestBus.setup(&.{ 0x15, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.x = 0x05;
    cpu.a = 0x01;
    bus.data[0x0055] = 0x02;

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0x03), cpu.a);
    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(!cpu.status.isSet(.n));
}

test "ora absolute" {
    var bus = TestBus.setup(&.{ 0x0D, 0x30, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.a = 0x00;
    bus.data[0x5030] = 0x80;

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0x80), cpu.a);
    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(cpu.status.isSet(.n));
}

test "ora absolute,x" {
    var bus = TestBus.setup(&.{ 0x1D, 0xE0, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.x = 0x10;
    cpu.a = 0x80;
    bus.data[0x50F0] = 0x01;

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0x81), cpu.a);
    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(cpu.status.isSet(.n));
}

test "ora absolute,y" {
    var bus = TestBus.setup(&.{ 0x19, 0x30, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.y = 0x10;
    cpu.a = 0x01;
    bus.data[0x5040] = 0x02;

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0x03), cpu.a);
    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(!cpu.status.isSet(.n));
}

test "ora (indirect,x)" {
    var bus = TestBus.setup(&.{ 0x01, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.x = 0x10;
    cpu.a = 0x0F;

    bus.data[0x0060] = 0x00;
    bus.data[0x0061] = 0x70;
    bus.data[0x7000] = 0xF0;

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0xFF), cpu.a);
    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(cpu.status.isSet(.n));
}

test "ora (indirect),y" {
    var bus = TestBus.setup(&.{ 0x11, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.y = 0x10;
    cpu.a = 0x00;

    bus.data[0x0050] = 0x00;
    bus.data[0x0051] = 0x70;
    bus.data[0x7010] = 0x01;

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0x01), cpu.a);
    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(!cpu.status.isSet(.n));
}

test "eor #immediate" {
    var bus = TestBus.setup(&.{ 0x49, 0x0F });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.a = 0xF0;

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0xFF), cpu.a);
    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(cpu.status.isSet(.n));
}

test "eor zeroPage" {
    var bus = TestBus.setup(&.{ 0x45, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.a = 0xAA;
    bus.data[0x0050] = 0xAA;

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0x00), cpu.a);
    try std.testing.expect(cpu.status.isSet(.z));
    try std.testing.expect(!cpu.status.isSet(.n));
}

test "eor zeroPage,x" {
    var bus = TestBus.setup(&.{ 0x55, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.x = 0x05;
    cpu.a = 0b10101010;
    bus.data[0x0055] = 0b01010101;

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0b11111111), cpu.a);
    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(cpu.status.isSet(.n));
}

test "eor absolute" {
    var bus = TestBus.setup(&.{ 0x4D, 0x30, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.a = 0x0F;
    bus.data[0x5030] = 0xF0;

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0xFF), cpu.a);
    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(cpu.status.isSet(.n));
}

test "eor absolute,x" {
    var bus = TestBus.setup(&.{ 0x5D, 0xE0, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.x = 0x10;
    cpu.a = 0xFF;
    bus.data[0x50F0] = 0xFF;

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0x00), cpu.a);
    try std.testing.expect(cpu.status.isSet(.z));
    try std.testing.expect(!cpu.status.isSet(.n));
}

test "eor absolute,y" {
    var bus = TestBus.setup(&.{ 0x59, 0x30, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.y = 0x10;
    cpu.a = 0xAA;
    bus.data[0x5040] = 0xFF;

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0x55), cpu.a);
    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(!cpu.status.isSet(.n));
}

test "eor (indirect,x)" {
    var bus = TestBus.setup(&.{ 0x41, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.x = 0x10;
    cpu.a = 0x0F;

    bus.data[0x0060] = 0x00;
    bus.data[0x0061] = 0x70;
    bus.data[0x7000] = 0xF0;

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0xFF), cpu.a);
    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(cpu.status.isSet(.n));
}

test "eor (indirect),y" {
    var bus = TestBus.setup(&.{ 0x51, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.y = 0x10;
    cpu.a = 0xF0;

    bus.data[0x0050] = 0x00;
    bus.data[0x0051] = 0x70;
    bus.data[0x7010] = 0x0F;

    cpu.clock();

    try std.testing.expectEqual(@as(u8, 0xFF), cpu.a);
    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(cpu.status.isSet(.n));
}

test "bit zeroPage" {
    var bus = TestBus.setup(&.{ 0x24, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.a = 0b0000_1111;
    bus.data[0x0050] = 0b1100_0000; // bits 7 and 6 set

    cpu.clock();

    try std.testing.expect(cpu.status.isSet(.z)); // A & M = 0x0F & 0xC0 = 0x00 → Z set
    try std.testing.expect(cpu.status.isSet(.n)); // memory bit 7 set
    try std.testing.expect(cpu.status.isSet(.v)); // memory bit 6 set
}

test "bit absolute" {
    var bus = TestBus.setup(&.{ 0x2C, 0x30, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.a = 0b1111_0000;
    bus.data[0x5030] = 0b0100_0000; // bit 6 set, bit 7 clear

    cpu.clock();

    try std.testing.expect(!cpu.status.isSet(.z)); // A & M = 0xF0 & 0x40 = 0x40 ≠ 0
    try std.testing.expect(!cpu.status.isSet(.n)); // bit 7 clear
    try std.testing.expect(cpu.status.isSet(.v)); // bit 6 set
}

test "bit zeroPage with non-zero result" {
    var bus = TestBus.setup(&.{ 0x24, 0x10 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.a = 0b0000_0101;
    bus.data[0x0010] = 0b0000_0101;

    cpu.clock();

    try std.testing.expectEqual(cpu.a & bus.data[0x0010], 0x05);
    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(!cpu.status.isSet(.v));
    try std.testing.expect(!cpu.status.isSet(.n));
}

test "cmp #immediate" {
    var bus = TestBus.setup(&.{ 0xC9, 0x0F });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.a = 0x0F;

    cpu.clock();

    try std.testing.expect(cpu.status.isSet(.z)); // A == M
    try std.testing.expect(cpu.status.isSet(.c)); // A >= M
    try std.testing.expect(!cpu.status.isSet(.n));
}

test "cmp zeroPage" {
    var bus = TestBus.setup(&.{ 0xC5, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.a = 0x10;
    bus.data[0x0050] = 0x20;

    cpu.clock();

    try std.testing.expect(!cpu.status.isSet(.c)); // A < M
    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(cpu.status.isSet(.n)); // Result is negative
}

test "cmp zeroPage,x" {
    var bus = TestBus.setup(&.{ 0xD5, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.x = 0x05;
    cpu.a = 0x30;
    bus.data[0x0055] = 0x20;

    cpu.clock();

    try std.testing.expect(cpu.status.isSet(.c)); // A > M
    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(!cpu.status.isSet(.n));
}

test "cmp absolute" {
    var bus = TestBus.setup(&.{ 0xCD, 0x30, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.a = 0x20;
    bus.data[0x5030] = 0x20;

    cpu.clock();

    try std.testing.expect(cpu.status.isSet(.z));
    try std.testing.expect(cpu.status.isSet(.c));
    try std.testing.expect(!cpu.status.isSet(.n));
}

test "cmp absolute,x" {
    var bus = TestBus.setup(&.{ 0xDD, 0xE0, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.x = 0x10;
    cpu.a = 0x01;
    bus.data[0x50F0] = 0x02;

    cpu.clock();

    try std.testing.expect(!cpu.status.isSet(.c));
    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(cpu.status.isSet(.n));
}

test "cmp absolute,y" {
    var bus = TestBus.setup(&.{ 0xD9, 0x30, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.y = 0x10;
    cpu.a = 0x03;
    bus.data[0x5040] = 0x01;

    cpu.clock();

    try std.testing.expect(cpu.status.isSet(.c));
    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(!cpu.status.isSet(.n));
}

test "cmp (indirect,x)" {
    var bus = TestBus.setup(&.{ 0xC1, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.x = 0x10;
    cpu.a = 0x01;

    bus.data[0x0060] = 0x00;
    bus.data[0x0061] = 0x70;
    bus.data[0x7000] = 0x01;

    cpu.clock();

    try std.testing.expect(cpu.status.isSet(.z));
    try std.testing.expect(cpu.status.isSet(.c));
    try std.testing.expect(!cpu.status.isSet(.n));
}

test "cmp (indirect),y" {
    var bus = TestBus.setup(&.{ 0xD1, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.y = 0x10;
    cpu.a = 0xFF;

    bus.data[0x0050] = 0x00;
    bus.data[0x0051] = 0x70;
    bus.data[0x7010] = 0x01;

    cpu.clock();

    try std.testing.expect(cpu.status.isSet(.c));
    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(cpu.status.isSet(.n));
}

test "cpx #immediate" {
    var bus = TestBus.setup(&.{ 0xE0, 0x20 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.x = 0x20;

    cpu.clock();

    try std.testing.expect(cpu.status.isSet(.z)); // X == memory
    try std.testing.expect(cpu.status.isSet(.c)); // X >= memory
    try std.testing.expect(!cpu.status.isSet(.n));
}

test "cpx zeroPage" {
    var bus = TestBus.setup(&.{ 0xE4, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.x = 0x10;
    bus.data[0x0050] = 0x20;

    cpu.clock();

    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(!cpu.status.isSet(.c)); // X < memory
    try std.testing.expect(cpu.status.isSet(.n)); // result is negative
}

test "cpx absolute" {
    var bus = TestBus.setup(&.{ 0xEC, 0x30, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.x = 0x80;
    bus.data[0x5030] = 0x01;

    cpu.clock();

    try std.testing.expect(cpu.status.isSet(.c)); // X > memory
    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(!cpu.status.isSet(.n)); // result = 0x7F, bit 7 not set
}

test "cpy #immediate" {
    var bus = TestBus.setup(&.{ 0xC0, 0x10 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.y = 0x10;

    cpu.clock();

    try std.testing.expect(cpu.status.isSet(.z)); // Y == memory
    try std.testing.expect(cpu.status.isSet(.c)); // Y >= memory
    try std.testing.expect(!cpu.status.isSet(.n));
}

test "cpy zeroPage" {
    var bus = TestBus.setup(&.{ 0xC4, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.y = 0x00;
    bus.data[0x0050] = 0x80;

    cpu.clock();

    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(!cpu.status.isSet(.c)); // Y < memory
    try std.testing.expect(cpu.status.isSet(.n)); // result = 0x80 → bit 7 set
}

test "cpy absolute" {
    var bus = TestBus.setup(&.{ 0xCC, 0x30, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.y = 0xFF;
    bus.data[0x5030] = 0x01;

    cpu.clock();

    try std.testing.expect(!cpu.status.isSet(.z));
    try std.testing.expect(cpu.status.isSet(.c)); // Y > memory
    try std.testing.expect(cpu.status.isSet(.n)); // 0xFF - 0x01 = 0xFE → N set
}

test "bcc not taken" {
    var bus = TestBus.setup(&.{ 0x90, 0x10 }); // BCC + $10
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.status.set(.c, true); // carry is set → branch not taken

    cpu.clock();

    try std.testing.expectEqual(@as(u16, 0xF002), cpu.pc); // skips the branch
    try std.testing.expectEqual(@as(u8, 1), cpu.cycles_left); // 2 cycles used
}

test "bcc taken" {
    var bus = TestBus.setup(&.{ 0x90, 0x10 }); // BCC + $10
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.status.set(.c, false); // carry is not set → branch taken

    cpu.clock();

    try std.testing.expectEqual(@as(u16, 0xF012), cpu.pc);
    try std.testing.expectEqual(@as(u8, 2), cpu.cycles_left);
}

test "bcc taken (crossed page)" {
    var bus = TestBus.setup(&.{ 0x90, 0xFF }); // BCC + $10
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.status.set(.c, false); // carry is not set → branch taken

    cpu.clock();

    try std.testing.expectEqual(@as(u16, 0xF101), cpu.pc);
    try std.testing.expectEqual(@as(u8, 3), cpu.cycles_left);
}

test "bcs not taken" {
    var bus = TestBus.setup(&.{ 0xB0, 0x10 }); // BCC + $10
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.status.set(.c, false);

    cpu.clock();

    try std.testing.expectEqual(@as(u16, 0xF002), cpu.pc); // skips the branch
    try std.testing.expectEqual(@as(u8, 1), cpu.cycles_left); // 2 cycles used
}

test "bcs taken" {
    var bus = TestBus.setup(&.{ 0xB0, 0x10 }); // BCC + $10
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.status.set(.c, true);

    cpu.clock();

    try std.testing.expectEqual(@as(u16, 0xF012), cpu.pc);
    try std.testing.expectEqual(@as(u8, 2), cpu.cycles_left);
}

test "bcs taken (crossed page)" {
    var bus = TestBus.setup(&.{ 0xB0, 0xFF }); // BCC + $10
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.status.set(.c, true);

    cpu.clock();

    try std.testing.expectEqual(@as(u16, 0xF101), cpu.pc);
    try std.testing.expectEqual(@as(u8, 3), cpu.cycles_left);
}

test "jmp absolute" {
    // JMP $5025
    var bus = TestBus.setup(&.{ 0x4C, 0x25, 0x50 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.clock();

    try std.testing.expectEqual(0x5025, cpu.pc);
}

test "jmp (indirect)" {
    // JMP ($ABBA)
    var bus = TestBus.setup(&.{ 0x6C, 0xBA, 0xAB });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    bus.data[0xABBA] = 0x34;
    bus.data[0xABBB] = 0x12;

    cpu.clock();

    try std.testing.expectEqual(0x1234, cpu.pc);
}

test "jsr absolute" {
    // JSR $2548
    var bus = TestBus.setup(&.{ 0x20, 0x48, 0x25 });
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.sp = 0x50;

    cpu.clock();

    try std.testing.expectEqual(0x2548, cpu.pc);
    try std.testing.expectEqual(0x02, bus.data[micro.getSpAbs(&cpu) + 1]);
    try std.testing.expectEqual(0xF0, bus.data[micro.getSpAbs(&cpu) + 2]);
}

test "rts implied" {
    var bus = TestBus.setup(&.{0x60});
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.sp = 0x50;
    // 0x45BA
    bus.data[micro.getSpAbs(&cpu) + 1] = 0xBA;
    bus.data[micro.getSpAbs(&cpu) + 2] = 0x45;

    cpu.clock();

    try std.testing.expectEqual(0x45BB, cpu.pc);
}

test "brk implied" {
    var bus = TestBus.setup(&.{0x00});
    var cpu = Chip.init(bus.bus());
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
    try std.testing.expectEqual(0xD4, bus.data[micro.getSpAbs(&cpu) + 1]);
    try std.testing.expectEqual(0x02, bus.data[micro.getSpAbs(&cpu) + 2]);
    try std.testing.expectEqual(0xF0, bus.data[micro.getSpAbs(&cpu) + 3]);
    try std.testing.expectEqual(0xCCBB, cpu.pc);
}

test "rti implied" {
    var bus = TestBus.setup(&.{0x40});
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    // Prepare data
    cpu.sp = 0x10;
    bus.data[micro.getSpAbs(&cpu) + 1] = 0xD4; // Stack 0b11010100
    bus.data[micro.getSpAbs(&cpu) + 2] = 0xBB;
    bus.data[micro.getSpAbs(&cpu) + 3] = 0xCC; // 0xCCBB

    cpu.clock();

    try std.testing.expectEqual(0b11000100, cpu.status.data);
    try std.testing.expectEqual(0xCCBB, cpu.pc);
}

test "pha implied" {
    var bus = TestBus.setup(&.{0x48});
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    // Prepare data
    cpu.sp = 0xAB;
    cpu.a = 0xFA;

    cpu.clock();

    try std.testing.expectEqual(0xFA, bus.data[micro.getSpAbs(&cpu) + 1]);
}

test "pla implied" {
    var bus = TestBus.setup(&.{0x68});
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    // Prepare data
    cpu.sp = 0x58;
    bus.data[0x59 + 0x0100] = 0xAA;

    cpu.clock();

    try std.testing.expectEqual(0xAA, cpu.a);
}

test "pla flag z" {
    var bus = TestBus.setup(&.{0x68});
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    // Prepare data
    cpu.sp = 0xA1;
    bus.data[0xA2 + 0x0100] = 0x00;

    cpu.clock();

    try std.testing.expect(cpu.status.isSet(.z));
}

test "pla flag n" {
    var bus = TestBus.setup(&.{0x68});
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    // Prepare data
    cpu.sp = 0x82;
    bus.data[0x83 + 0x0100] = 0xAA;

    cpu.clock();

    try std.testing.expect(cpu.status.isSet(.n));
}

test "php implied" {
    var bus = TestBus.setup(&.{0x08});
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    // Prepare data
    cpu.sp = 0x14;
    cpu.status.data = 0b11001101;

    cpu.clock();

    try std.testing.expectEqual(0b11111101, bus.data[micro.getSpAbs(&cpu) + 1]);
}

test "plp implied" {
    var bus = TestBus.setup(&.{0x28});
    var cpu = Chip.init(bus.bus());
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
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    // Prepare data
    cpu.x = 0xBB;

    cpu.clock();

    try std.testing.expectEqual(cpu.sp, 0xBB);
}

test "tsx implied" {
    var bus = TestBus.setup(&.{0xBA});
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    // Prepare data
    cpu.sp = 0xAA;

    cpu.clock();

    try std.testing.expectEqual(cpu.x, 0xAA);
}

test "tsx flag z" {
    var bus = TestBus.setup(&.{0xBA});
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    // Prepare data
    cpu.sp = 0x00;

    cpu.clock();

    try std.testing.expect(cpu.status.isSet(.z));
}

test "tsx flag n" {
    var bus = TestBus.setup(&.{0xBA});
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    // Prepare data
    cpu.sp = 0b10010100;

    cpu.clock();

    try std.testing.expect(cpu.status.isSet(.n));
}

test "clc implied" {
    var bus = TestBus.setup(&.{0x18});
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    // Prepare data
    cpu.status.set(.c, true);

    cpu.clock();

    try std.testing.expectEqual(cpu.status.isSet(.c), false);
}

test "sec implied" {
    var bus = TestBus.setup(&.{0x38});
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    // Prepare data
    cpu.status.set(.c, false);

    cpu.clock();

    try std.testing.expectEqual(cpu.status.isSet(.c), true);
}

test "cli implied" {
    var bus = TestBus.setup(&.{0x58});
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    // Prepare data
    cpu.status.set(.i, true);

    cpu.clock();

    try std.testing.expectEqual(cpu.status.isSet(.i), false);
}

test "sei implied" {
    var bus = TestBus.setup(&.{0x78});
    var cpu = Chip.init(bus.bus());

    cpu.powerOn();

    // Prepare data
    cpu.status.set(.i, false);

    cpu.clock();

    try std.testing.expectEqual(cpu.status.isSet(.i), true);
}

test "cld implied" {
    var bus = TestBus.setup(&.{0xD8});
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    // Prepare data
    cpu.status.set(.d, true);

    cpu.clock();

    try std.testing.expectEqual(cpu.status.isSet(.d), false);
}

test "sed implied" {
    var bus = TestBus.setup(&.{0xF8});
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    // Prepare data
    cpu.status.set(.d, false);

    cpu.clock();

    try std.testing.expectEqual(true, cpu.status.isSet(.d));
}

test "clv implied" {
    var bus = TestBus.setup(&.{0xB8});
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    // Prepare data
    cpu.status.set(.v, true);

    cpu.clock();

    try std.testing.expectEqual(false, cpu.status.isSet(.v));
}

test "nop implied" {
    var bus = TestBus.setup(&.{0xEA});
    var cpu = Chip.init(bus.bus());
    cpu.powerOn();

    cpu.clock();
}
