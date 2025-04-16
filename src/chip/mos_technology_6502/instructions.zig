const std = @import("std");
const TestBus = @import("testing.zig").TestBus;
const Chip = @import("../mos_technology_6502.zig").Chip;

pub const AddressReturn = struct {
    cycle_request: bool,
};

// TODO: implement
pub fn implied(_: anytype) AddressReturn {
    return .{
        .cycle_request = false,
    };
}

pub fn address_unknown(_: anytype) AddressReturn {
    return .{
        .cycle_request = false,
    };
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

    // Prepare chip
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

    // Prepare chip
    cpu.status.set(.c, false);

    cpu.clock();

    try std.testing.expectEqual(cpu.status.isSet(.c), true);
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

    // Prepare chip
    cpu.status.set(.d, true);

    cpu.clock();

    try std.testing.expectEqual(cpu.status.isSet(.d), false);
}

pub fn type_unknown(_: anytype, _: AddressReturn) bool {
    return false;
}
