const std = @import("std");
const TestBus = @import("testing.zig").TestBus;
const Chip = @import("../mos_technology_6502.zig").Chip;
const Status = @import("../mos_technology_6502.zig").Status;

pub const AddressReturn = struct {
    cycle_request: bool,
    address: u16,
};

pub const micro = struct {
    pub fn readSp(cpu: anytype) u8 {
        return cpu.read(@as(u16, cpu.sp) + 0x0100);
    }
    pub fn writeSp(cpu: anytype, data: u8) void {
        cpu.write(@as(u16, cpu.sp) + 0x0100, data);
    }
    pub fn getSpAbs(cpu: anytype) u16 {
        return @as(u16, cpu.sp) + 0x0100;
    }
    pub fn fetch16(cpu: anytype, address: u16) u16 {
        const lo: u16 = cpu.read(address);
        const hi: u16 = cpu.read(address + 1);
        return (hi << 8) | lo;
    }
};

pub fn implied(_: anytype) AddressReturn {
    return .{
        .cycle_request = false,
        .address = 0x00,
    };
}

pub fn absolute(cpu: anytype) AddressReturn {
    const lo: u16 = cpu.read(cpu.pc);
    cpu.pc += 1;
    const hi: u16 = cpu.read(cpu.pc);
    cpu.pc += 1;
    return .{
        .cycle_request = false,
        .address = (hi << 8) | lo,
    };
}

pub fn indirect(cpu: anytype) AddressReturn {
    const ptr_lo: u16 = cpu.read(cpu.pc);
    cpu.pc += 1;
    const ptr_hi: u16 = cpu.read(cpu.pc);
    cpu.pc += 1;

    const ptr = (ptr_hi << 8) | ptr_lo;

    const lo: u16 = cpu.read(ptr);
    const hi: u16 = if (ptr_lo == 0x00FF) cpu.read(ptr & 0xFF00) else cpu.read(ptr + 1);

    return .{
        .cycle_request = false,
        .address = (hi << 8) | lo,
    };
}

pub fn address_unknown(_: anytype) AddressReturn {
    @panic("unknown address mode!");
}

/// JMP - Jump
/// `PC = Memory`
/// 0x4C - 3 bytes - 3 cycles - absolute
/// 0x6C - 3 bytes - 5 cycles - (indirect)
pub fn jmp(cpu: anytype, ret: AddressReturn) bool {
    cpu.pc = ret.address;
    return false;
}

test "jmp absolute" {
    // JMP $5025
    var bus = TestBus.setup(&.{ 0x4C, 0x25, 0x50 });
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    cpu.clock();

    try std.testing.expectEqual(0x5025, cpu.pc);
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

/// JSR - Jump to Subroutine
/// `push PC + 2 to stack`
/// `PC = memory`
/// 0x20 - 3 bytes - 6 cycles - absolute
pub fn jsr(cpu: anytype, ret: AddressReturn) bool {
    cpu.pc -= 1;

    micro.writeSp(cpu, @truncate(cpu.pc >> 8));
    cpu.sp -%= 1;
    micro.writeSp(cpu, @truncate(cpu.pc));
    cpu.sp -%= 1;

    cpu.pc = ret.address;
    return false;
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

/// RTS - Return from Subroutine
/// `pull PC from stack`
/// `PC = PC + 1`
/// 0x60 - 1 byte - 6 cycles - implied
pub fn rts(cpu: anytype, _: AddressReturn) bool {
    cpu.sp +%= 1;
    const lo: u16 = micro.readSp(cpu);
    cpu.sp +%= 1;
    const hi: u16 = micro.readSp(cpu);
    cpu.pc = (hi << 8) | lo;

    cpu.pc += 1;
    return false;
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

/// PHA - Push A
/// `($0100 + SP) = A`
/// `SP = SP - 1`
/// 0x48 - 1 byte - 3 cycles - implied
pub fn pha(cpu: anytype, _: AddressReturn) bool {
    micro.writeSp(cpu, cpu.a);
    cpu.sp -%= 1;
    return false;
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

/// PLA - Pull A
/// `SP = SP + 1`
/// `A = ($0100 + SP)`
/// Flags:
///     z = result == 0
///     n = result & 0x80 != 0
/// 0x68 - 1 byte - 4 cycles - implied
pub fn pla(cpu: anytype, _: AddressReturn) bool {
    cpu.sp +%= 1;
    cpu.a = micro.readSp(cpu);
    cpu.status.set(.z, cpu.a == 0);
    cpu.status.set(.n, cpu.a & 0x80 != 0);
    return false;
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

/// PHP - Push Processor Status
/// `($0100 + SP) = NV11DIZC`
/// `SP = SP - 1`
/// 0x08 - 1 byte - 3 cycles - implied
pub fn php(cpu: anytype, _: AddressReturn) bool {
    var local: Status = cpu.status;
    local.set(.b, true);
    local.set(.u, true);
    micro.writeSp(cpu, local.data);
    cpu.sp -%= 1;
    return false;
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

/// PLP - Pull Processor Status
/// `SP = SP + 1`
/// `NVxxDIZC = ($0100 + SP)`
/// Flags:
///     c = result & 0x01 != 0
///     z = result & 0x02 != 0
///     i = result & 0x04 != 0
///     d = result & 0x08 != 0
///     v = result & 0x40 != 0
///     n = result & 0x80 != 0
/// 0x28 - 1 byte - 4 cycles - implied
pub fn plp(cpu: anytype, _: AddressReturn) bool {
    cpu.sp +%= 1;
    const result = micro.readSp(cpu);
    cpu.status.set(.c, result & 0x01 != 0);
    cpu.status.set(.z, result & 0x02 != 0);
    cpu.status.set(.i, result & 0x04 != 0);
    cpu.status.set(.d, result & 0x08 != 0);
    cpu.status.set(.v, result & 0x40 != 0);
    cpu.status.set(.n, result & 0x80 != 0);
    return false;
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

/// TXS - Transfer X to Stack Pointer
/// `SP = x`
/// 0x9A - 1 byte - 2 cycles - implied
pub fn txs(cpu: anytype, _: AddressReturn) bool {
    cpu.sp = cpu.x;
    return false;
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

/// TSX - Transfer Stack Pointer to X
/// `X = SP`
/// Flags:
///     z = result == 0
///     n = result & 0x80 != 0
/// 0xBA - 1 byte - 2 cycles - implied
pub fn tsx(cpu: anytype, _: AddressReturn) bool {
    cpu.x = cpu.sp;
    cpu.status.set(.z, cpu.x == 0);
    cpu.status.set(.n, cpu.x & 0x80 != 0);
    return false;
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

/// CLC - Clear Carry
/// `C = 0`
/// 0x18 - 1 byte - 2 cycles - implied
pub fn clc(cpu: anytype, _: AddressReturn) bool {
    cpu.status.set(.c, false);
    return false;
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

/// SEC - Set Carry
/// `C = 1`
/// 0x38 - 1 byte - 2 cycles - implied
pub fn sec(cpu: anytype, _: AddressReturn) bool {
    cpu.status.set(.c, true);
    return false;
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

/// CLI - Clear Interrupt Disable
/// `I = 0`
/// 0x58 - 1 byte - 2 cycles - implied
pub fn cli(cpu: anytype, _: AddressReturn) bool {
    cpu.status.set(.i, false);
    return false;
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

/// SEI - Set interrupt Disable
/// `I = 1`
/// 0x78 - 1 byte - 2 cycles - implied
pub fn sei(cpu: anytype, _: AddressReturn) bool {
    cpu.status.set(.i, true);
    return false;
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

/// CLD - CLear Decimal
/// `D = 0`
/// 0xD8 - 1 byte - 2 cycles - implied
pub fn cld(cpu: anytype, _: AddressReturn) bool {
    cpu.status.set(.d, false);
    return false;
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

/// SED - Set Decimal
/// `D = 1`
/// 0xF8 - 1 byte - 2 cycles - implied
pub fn sed(cpu: anytype, _: AddressReturn) bool {
    cpu.status.set(.d, true);
    return false;
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

/// CLV - Clear Overflow
/// `V = 0`
/// 0xB8 - 1 byte - 2 cycles - implied
pub fn clv(cpu: anytype, _: AddressReturn) bool {
    cpu.status.set(.v, false);
    return false;
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

/// NOP - No Operation
/// 0xEA - 1 byte - 2 cycles - implied
pub fn nop(_: anytype, _: AddressReturn) bool {
    return false;
}

test "nop implied" {
    var bus = TestBus.setup(&.{0xEA});
    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    cpu.clock();
}

pub fn type_unknown(_: anytype, _: AddressReturn) bool {
    @panic("unknown instruction type!");
}
