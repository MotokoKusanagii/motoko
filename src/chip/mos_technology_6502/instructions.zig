const std = @import("std");
const TestBus = @import("testing.zig").TestBus;
const Chip = @import("../mos_technology_6502.zig").Chip;

pub const AddressReturn = struct {
    cycle_request: bool,
};

pub const micro = struct {
    pub fn readSp(cpu: anytype) u8 {
        return cpu.read(@as(u16, cpu.sp) + 0x0100);
    }
};

pub fn implied(_: anytype) AddressReturn {
    return .{
        .cycle_request = false,
    };
}

pub fn address_unknown(_: anytype) AddressReturn {
    @panic("unknown address mode!");
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
    var bus = TestBus{
        .data = undefined,
    };
    @memset(&bus.data, 0);

    // Prepare instruction
    bus.data[0xFFFC] = 0x28;

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
    var bus = TestBus{
        .data = undefined,
    };
    @memset(&bus.data, 0);

    // Prepare instruction
    bus.data[0xFFFC] = 0x9A;

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
    var bus = TestBus{
        .data = undefined,
    };
    @memset(&bus.data, 0);

    // Prepare instruction
    bus.data[0xFFFC] = 0xBA;

    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.sp = 0xAA;

    cpu.clock();

    try std.testing.expectEqual(cpu.x, 0xAA);
}

test "tsx flag z" {
    var bus = TestBus{
        .data = undefined,
    };
    @memset(&bus.data, 0);

    // Prepare instruction
    bus.data[0xFFFC] = 0xBA;

    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.sp = 0x00;

    cpu.clock();

    try std.testing.expect(cpu.status.isSet(.z));
}

test "tsx flag n" {
    var bus = TestBus{
        .data = undefined,
    };
    @memset(&bus.data, 0);

    // Prepare instruction
    bus.data[0xFFFC] = 0xBA;

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
    var bus = TestBus{
        .data = undefined,
    };
    @memset(&bus.data, 0);

    // Prepare instruction
    bus.data[0xFFFC] = 0x18;

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
    var bus = TestBus{
        .data = undefined,
    };
    @memset(&bus.data, 0);

    // Prepare instruction
    bus.data[0xFFFC] = 0x38;

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
    var bus = TestBus{
        .data = undefined,
    };
    @memset(&bus.data, 0);

    // Prepare instruction
    bus.data[0xFFFC] = 0x58;

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
    var bus = TestBus{
        .data = undefined,
    };
    @memset(&bus.data, 0);

    // Prepare instruction
    bus.data[0xFFFC] = 0x78;

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
    var bus = TestBus{
        .data = undefined,
    };
    @memset(&bus.data, 0);

    // Prepare instruction
    bus.data[0xFFFC] = 0xD8;

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
    var bus = TestBus{
        .data = undefined,
    };
    @memset(&bus.data, 0);

    // Prepare instruction
    bus.data[0xFFFC] = 0xF8;

    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.status.set(.d, false);

    cpu.clock();

    try std.testing.expectEqual(cpu.status.isSet(.d), true);
}

/// CLV - Clear Overflow
/// `V = 0`
/// 0xB8 - 1 byte - 2 cycles - implied
pub fn clv(cpu: anytype, _: AddressReturn) bool {
    cpu.status.set(.v, false);
    return false;
}

test "clv implied" {
    var bus = TestBus{
        .data = undefined,
    };
    @memset(&bus.data, 0);

    // Prepare instruction
    bus.data[0xFFFC] = 0xB8;

    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    // Prepare data
    cpu.status.set(.v, true);

    cpu.clock();

    try std.testing.expectEqual(cpu.status.isSet(.d), false);
}

/// NOP - No Operation
/// 0xEA - 1 byte - 2 cycles - implied
pub fn nop(_: anytype, _: AddressReturn) bool {
    return false;
}

test "nop implied" {
    var bus = TestBus{
        .data = undefined,
    };
    @memset(&bus.data, 0);

    // Prepare instruction
    bus.data[0xFFFC] = 0xEA;

    var cpu = Chip(TestBus).init(&bus);
    cpu.powerOn();

    cpu.clock();
}

pub fn type_unknown(_: anytype, _: AddressReturn) bool {
    @panic("unknown instruction type!");
}
