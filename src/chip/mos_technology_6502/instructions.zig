const std = @import("std");
const TestBus = @import("testing.zig").TestBus;
const Chip = @import("../mos_technology_6502.zig").Chip;
const Status = @import("../mos_technology_6502.zig").Status;

pub const AddressReturn = struct {
    cycle_request: bool,
    address: u16,
    accumulator: bool = false,
    relative: u8 = 0x00,
};

pub const micro = struct {
    pub fn readSp(cpu: *Chip) u8 {
        return cpu.read(@as(u16, cpu.sp) + 0x0100);
    }
    pub fn writeSp(cpu: *Chip, data: u8) void {
        cpu.write(@as(u16, cpu.sp) + 0x0100, data);
    }
    pub fn getSpAbs(cpu: *Chip) u16 {
        return @as(u16, cpu.sp) + 0x0100;
    }
    pub fn fetch16(cpu: *Chip, address: u16) u16 {
        const lo: u16 = cpu.read(address);
        const hi: u16 = cpu.read(address +% 1);
        return (hi << 8) | lo;
    }
};

pub fn accumulator(_: *Chip) AddressReturn {
    return .{
        .cycle_request = false,
        .address = 0x00,
        .accumulator = true,
    };
}

pub fn implied(_: *Chip) AddressReturn {
    return .{
        .cycle_request = false,
        .address = 0x00,
    };
}

pub fn immediate(cpu: *Chip) AddressReturn {
    const address = cpu.pc;
    cpu.pc += 1;
    return .{
        .cycle_request = false,
        .address = address,
    };
}

pub fn zeroPage(cpu: *Chip) AddressReturn {
    const address: u16 = cpu.read(cpu.pc);
    cpu.pc += 1;
    return .{
        .cycle_request = false,
        .address = address,
    };
}

pub fn zeroPageX(cpu: *Chip) AddressReturn {
    var address: u8 = cpu.read(cpu.pc);
    address +%= cpu.x;
    cpu.pc += 1;
    return .{
        .cycle_request = false,
        .address = address,
    };
}

pub fn zeroPageY(cpu: *Chip) AddressReturn {
    var address: u8 = cpu.read(cpu.pc);
    address +%= cpu.y;
    cpu.pc += 1;
    return .{
        .cycle_request = false,
        .address = address,
    };
}

pub fn absolute(cpu: *Chip) AddressReturn {
    const lo: u16 = cpu.read(cpu.pc);
    cpu.pc += 1;
    const hi: u16 = cpu.read(cpu.pc);
    cpu.pc += 1;
    return .{
        .cycle_request = false,
        .address = (hi << 8) | lo,
    };
}

pub fn absoluteX(cpu: *Chip) AddressReturn {
    const lo: u16 = cpu.read(cpu.pc);
    cpu.pc += 1;
    const hi: u16 = cpu.read(cpu.pc);
    cpu.pc += 1;

    var address = (hi << 8) | lo;
    address +%= cpu.x;
    const page_boundary_crossed = address >> 8 != hi;
    return .{
        .cycle_request = page_boundary_crossed,
        .address = address,
    };
}

pub fn absoluteY(cpu: *Chip) AddressReturn {
    const lo: u16 = cpu.read(cpu.pc);
    cpu.pc += 1;
    const hi: u16 = cpu.read(cpu.pc);
    cpu.pc += 1;

    var address = (hi << 8) | lo;
    address +%= cpu.y;
    const page_boundary_crossed = address >> 8 != hi;
    return .{
        .cycle_request = page_boundary_crossed,
        .address = address,
    };
}

pub fn indirect(cpu: *Chip) AddressReturn {
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

pub fn indirectX(cpu: *Chip) AddressReturn {
    var ptr: u8 = cpu.read(cpu.pc);
    cpu.pc += 1;

    ptr +%= cpu.x;

    const address = micro.fetch16(cpu, ptr);

    return .{
        .cycle_request = false,
        .address = address,
    };
}

pub fn indirectY(cpu: *Chip) AddressReturn {
    const ptr: u8 = cpu.read(cpu.pc);
    cpu.pc += 1;

    const lo: u16 = cpu.read(ptr);
    const hi: u16 = cpu.read(ptr +% 1);
    var address = (hi << 8) | lo;
    address +%= cpu.y;

    const page_boundary_crossed = (address >> 8) != hi;

    return .{
        .cycle_request = page_boundary_crossed,
        .address = address,
    };
}

pub fn relative(cpu: *Chip) AddressReturn {
    var offset = cpu.read(cpu.pc);
    cpu.pc += 1;

    if (offset & 0x80 != 0) {
        offset |= 0x00;
    }

    return .{
        .cycle_request = false,
        .address = 0x00,
        .relative = offset,
    };
}

pub fn address_unknown(_: *Chip) AddressReturn {
    @panic("unknown address mode!");
}

/// LDA - Load A
/// `A = memory`
/// Flags:
///     z = result == 0
///     n = result & 0x80 != 0
/// 0xA9 - 2 bytes - 2 cycles - #immediate
/// 0xA5 - 2 bytes - 3 cycles - zeroPage
/// 0xB5 - 2 bytes - 4 cycles - zeroPage,x
/// 0xAD - 3 bytes - 4 cycles - absolute
/// 0xBD - 3 bytes - 4 cycles* - absolute,x
/// 0xB9 - 3 bytes - 4 cycles* - absolute,y
/// 0xA1 - 2 bytes - 6 cycles - (indirect,x)
/// 0xB1 - 2 bytes - 5 cycles* - (indirect),y
pub fn lda(cpu: *Chip, ret: AddressReturn) bool {
    cpu.a = cpu.read(ret.address);
    cpu.status.set(.z, cpu.a == 0x00);
    cpu.status.set(.n, cpu.a & 0x80 != 0);
    return ret.cycle_request;
}

/// STA - Store A
/// `memory = A`
/// 0x85 - 2 bytes - 3 cycles - zeroPage
/// 0x95 - 2 bytes - 4 cycles - zeroPage,x
/// 0x8D - 3 bytes - 4 cycles - absolute
/// 0x9D - 3 bytes - 5 cycles - absolute,x
/// 0x99 - 3 bytes - 5 cycles - absolute,y
/// 0x81 - 2 bytes - 6 cycles - (indirect,x)
/// 0x91 - 2 bytes - 6 cycles - (indirect),y
pub fn sta(cpu: *Chip, ret: AddressReturn) bool {
    cpu.write(ret.address, cpu.a);
    return false;
}

/// LDX - Load X
/// `X = memory`
/// Flags:
///     z = result == 0
///     n = result & 0x80 != 0
/// 0xA2 - 2 bytes - 2 cycles - #immediate
/// 0xA6 - 2 bytes - 3 cycles - zeroPage
/// 0xB6 - 2 bytes - 4 cycles - zeroPage,y
/// 0xAE - 3 bytes - 4 cycles - absolute
/// 0xBE - 3 bytes - 4 cycles* - absolute,y
pub fn ldx(cpu: *Chip, ret: AddressReturn) bool {
    cpu.x = cpu.read(ret.address);
    cpu.status.set(.z, cpu.x == 0x00);
    cpu.status.set(.n, cpu.x & 0x80 != 0);
    return ret.cycle_request;
}

/// STX - Store X
/// `memory = X`
/// 0x86 - 2 bytes - 3 cycles - zeroPage
/// 0x96 - 2 bytes - 4 cycles - zeroPage,y
/// 0x8E - 3 bytes - 4 cycles - absolute
pub fn stx(cpu: *Chip, ret: AddressReturn) bool {
    cpu.write(ret.address, cpu.x);
    return false;
}

/// LDY - Load Y
/// `Y = memory`
/// Flags:
///     z = result == 0
///     n = result & 0x80 != 0
/// 0xA0 - 2 bytes - 2 cycles - #immediate
/// 0xA4 - 2 bytes - 3 cycles - zeroPage
/// 0xB4 - 2 bytes - 4 cycles - zeroPage,x
/// 0xAC - 3 bytes - 4 cycles - absolute
/// 0xBC - 3 bytes - 4 cycles - absolute,x
pub fn ldy(cpu: *Chip, ret: AddressReturn) bool {
    cpu.y = cpu.read(ret.address);
    cpu.status.set(.z, cpu.x == 0x00);
    cpu.status.set(.n, cpu.x & 0x80 != 0);
    return ret.cycle_request;
}

/// STY - Store Y
/// `memory = Y`
/// 0x84 - 2 bytes - 3 cycles - zeroPage
/// 0x94 - 2 bytes - 4 cycles - zeroPage,x
/// 0x8C - 3 bytes - 4 cycles - absolute
pub fn sty(cpu: *Chip, ret: AddressReturn) bool {
    cpu.write(ret.address, cpu.y);
    return false;
}

/// TAX - Transfer A to X
/// `X = A`
/// Flags:
///     z = result == 0
///     n = result & 0x80 != 0
/// 0xAA - 1 byte - 2 cycles - implied
pub fn tax(cpu: *Chip, _: AddressReturn) bool {
    cpu.x = cpu.a;
    cpu.status.set(.z, cpu.x == 0x00);
    cpu.status.set(.n, cpu.x & 0x80 != 0);
    return false;
}

/// TXA - Transfer X to A
/// `A = X`
/// Flags:
///     z = result == 0
///     n = result & 0x80 != 0
/// 0x8A - 1 byte - 2 cycles - implied
pub fn txa(cpu: *Chip, _: AddressReturn) bool {
    cpu.a = cpu.x;
    cpu.status.set(.z, cpu.a == 0x00);
    cpu.status.set(.n, cpu.a & 0x80 != 0);
    return false;
}

/// TAY - Transfer A to Y
/// `Y = A`
/// Flags:
///     z = result == 0
///     n = result & 0x80 != 0
/// 0xA8 - 1 byte - 2 cycles - implied
pub fn tay(cpu: *Chip, _: AddressReturn) bool {
    cpu.y = cpu.a;
    cpu.status.set(.z, cpu.y == 0x00);
    cpu.status.set(.n, cpu.y & 0x80 != 0);
    return false;
}

/// TYA - Transfer Y to A
/// `A = Y`
/// Flags:
///     z = result == 0
///     n = result & 0x80 != 0
/// 0x98 - 1 byte - 2 cycles - implied
pub fn tya(cpu: *Chip, _: AddressReturn) bool {
    cpu.a = cpu.y;
    cpu.status.set(.z, cpu.a == 0x00);
    cpu.status.set(.n, cpu.a & 0x80 != 0);
    return false;
}

/// ADC - Add with Carry
/// `A = A + memory + C`
/// Flags:
///     c = result > 0xFF
///     z = result == 0
///     v = (result ^ A) & (result ^ memory) & 0x80
///     n = result 0x80 != 0
/// 0x69 - 2 bytes - 2 cycles - #immediate
/// 0x65 - 2 bytes - 3 cycles - zeroPage
/// 0x75 - 2 bytes - 4 cycles - zeroPage,x
/// 0x6D - 3 bytes - 4 cycles - absolute
/// 0x7D - 3 bytes - 4 cycles* - absolute,x
/// 0x79 - 3 bytes - 4 cycles* - absolute,y
/// 0x61 - 2 bytes - 6 cycles - (indirect,x)
/// 0x71 - 2 bytes - 5 cycles* - (indirect),y
pub fn adc(cpu: *Chip, ret: AddressReturn) bool {
    const m: u16 = cpu.read(ret.address);
    const c: u16 = @intFromBool(cpu.status.isSet(.c));
    const a: u16 = cpu.a;

    const r: u16 = a + m + c;
    cpu.status.set(.c, r > 0xFF);
    cpu.status.set(.z, r & 0x00FF == 0x00);
    cpu.status.set(.v, ~(a ^ m) & (a ^ r) & 0x80 != 0);
    cpu.status.set(.n, r & 0x80 != 0);

    cpu.a = @truncate(r);

    return ret.cycle_request;
}

/// SBC - Subtract with Carry
/// `A = A - memory - ~C`, or `A = A + ~memory + C`
/// Flags:
///     c = ~(result < 0x00)
///     z = result == 0
///     v = (result ^ A) & (result ^ ~memory) & 0x80 != 0
///     n = result 0x80 != 0
/// 0xE9 - 2 bytes - 2 cycles - #immediate
/// 0xE5 - 2 bytes - 3 cycles - zeroPage
/// 0xF5 - 2 bytes - 4 cycles - zeroPage,x
/// 0xED - 3 bytes - 4 cycles - absolute
/// 0xFD - 3 bytes - 4 cycles* - absolute,x
/// 0xF9 - 3 bytes - 4 cycles* - absolute,y
/// 0xE1 - 2 bytes - 6 cycles - (indirect,x)
/// 0xF1 - 2 bytes - 5 cycles* - (indirect),y
pub fn sbc(cpu: *Chip, ret: AddressReturn) bool {
    const m: u16 = cpu.read(ret.address);
    const c: u16 = @intFromBool(cpu.status.isSet(.c));
    const a: u16 = cpu.a;

    const r: u16 = a + (~m & 0x00FF) + c;
    cpu.status.set(.c, r & 0xFF00 != 0);
    cpu.status.set(.z, r & 0x00FF == 0x00);
    cpu.status.set(.v, (r ^ a) & (r ^ ~m) & 0x80 != 0);
    cpu.status.set(.n, r & 0x80 != 0);

    cpu.a = @truncate(r);

    return ret.cycle_request;
}

/// INC - Increment Memory
/// `memory = memory + 1`
/// Flags:
///     z = result == 0
///     n = result 0x80 != 0
/// 0xE6 - 2 bytes - 5 cycles - zeroPage
/// 0xF6 - 2 bytes - 6 cycles - zeroPage,x
/// 0xEE - 3 bytes - 6 cycles - absolute
/// 0xFE - 3 bytes - 7 cycles - absolute,x
pub fn inc(cpu: *Chip, ret: AddressReturn) bool {
    const memory = cpu.read(ret.address);
    const result = memory +% 1;
    cpu.write(ret.address, result);
    cpu.status.set(.z, result == 0x00);
    cpu.status.set(.n, result & 0x80 != 0);
    return false;
}

/// DEC - Decrement Memory
/// `memory = memory - 1`
/// Flags:
///     z = result == 0
///     n = result 0x80 != 0
/// 0xC6 - 2 bytes - 5 cycles - zeroPage
/// 0xD6 - 2 bytes - 6 cycles - zeroPage,x
/// 0xCE - 3 bytes - 6 cycles - absolute
/// 0xDE - 3 bytes - 7 cycles - absolute,x
pub fn dec(cpu: *Chip, ret: AddressReturn) bool {
    const memory = cpu.read(ret.address);
    const result = memory -% 1;
    cpu.write(ret.address, result);
    cpu.status.set(.z, result == 0x00);
    cpu.status.set(.n, result & 0x80 != 0);
    return false;
}

/// INX - Increment X
/// Flags:
///     z = result == 0
///     n = result 0x80 != 0
/// 0xE8 - 1 byte - 2 cycles - implied
pub fn inx(cpu: *Chip, _: AddressReturn) bool {
    cpu.x +%= 1;
    cpu.status.set(.z, cpu.x == 0x00);
    cpu.status.set(.n, cpu.x & 0x80 != 0);
    return false;
}

/// DEX - Decrement X
/// Flags:
///     z = result == 0
///     n = result 0x80 != 0
/// 0xCA - 1 byte - 2 cycles - implied
pub fn dex(cpu: *Chip, _: AddressReturn) bool {
    cpu.x -%= 1;
    cpu.status.set(.z, cpu.x == 0x00);
    cpu.status.set(.n, cpu.x & 0x80 != 0);
    return false;
}

/// INY - Increment Y
/// Flags:
///     z = result == 0
///     n = result 0x80 != 0
/// 0xC8 - 1 byte - 2 cycles - implied
pub fn iny(cpu: *Chip, _: AddressReturn) bool {
    cpu.y +%= 1;
    cpu.status.set(.z, cpu.y == 0x00);
    cpu.status.set(.n, cpu.y & 0x80 != 0);
    return false;
}

/// DEY - Decrement Y
/// Flags:
///     z = result == 0
///     n = result 0x80 != 0
/// 0x88 - 1 byte - 2 cycles - implied
pub fn dey(cpu: *Chip, _: AddressReturn) bool {
    cpu.y -%= 1;
    cpu.status.set(.z, cpu.y == 0x00);
    cpu.status.set(.n, cpu.y & 0x80 != 0);
    return false;
}

/// ASL - Arithmetic Shift Left
/// `value = value << 1` or `C <- [76543210] <- 0`
/// Flags:
///     c = old bit 7
///     z = result == 0
///     n = result 0x80 != 0
/// 0x0A - 1 byte - 2 cycles - accumulator
/// 0x06 - 2 bytes - 5 cycles - zeroPage
/// 0x16 - 2 bytes - 6 cycles - zeroPage,x
/// 0x0E - 3 bytes - 6 cycles - absolute
/// 0x1E - 3 bytes - 7 cycles - absolute,x
pub fn asl(cpu: *Chip, ret: AddressReturn) bool {
    if (ret.accumulator) {
        const value: u16 = cpu.a;
        const result = value << 1;
        cpu.status.set(.c, result & 0xFF00 > 0);
        cpu.status.set(.z, result & 0x00FF == 0);
        cpu.status.set(.n, result & 0x80 != 0);
        cpu.a = @truncate(result);
    } else {
        const value: u16 = cpu.read(ret.address);
        const result = value << 1;
        cpu.status.set(.c, result & 0xFF00 != 0);
        cpu.status.set(.z, result & 0x00FF == 0);
        cpu.status.set(.n, result & 0x80 != 0);
        cpu.write(ret.address, @truncate(result));
    }
    return false;
}

/// LSR - Logical Shift Right
/// `value = value >> 1` or `0 -> [76543210] -> C`
/// Flags:
///     c = value bit 0
///     z = result == 0
///     n = result 0x80 != 0
/// 0x4A - 1 byte - 2 cycles - accumulator
/// 0X46 - 2 bytes - 5 cycles - zeroPage
/// 0x56 - 2 bytes - 6 cycles - zeroPage,x
/// 0x4E - 3 bytes - 6 cycles - absolute
/// 0x5E - 3 bytes - 7 cycles - absolute,x
pub fn lsr(cpu: *Chip, ret: AddressReturn) bool {
    if (ret.accumulator) {
        const value: u16 = cpu.a;
        const result = value >> 1;
        cpu.status.set(.c, value & 0x0001 != 0);
        cpu.status.set(.z, result & 0x00FF == 0);
        cpu.status.set(.n, result & 0x80 != 0);
        cpu.a = @truncate(result);
    } else {
        const value: u16 = cpu.read(ret.address);
        const result = value >> 1;
        cpu.status.set(.c, value & 0x0001 != 0);
        cpu.status.set(.z, result & 0x00FF == 0);
        cpu.status.set(.n, result & 0x80 != 0);
        cpu.write(ret.address, @truncate(result));
    }
    return false;
}

/// ROL - Rotate Left
/// `value = value << 1 through C` or `C <- [76543210] <- C`
/// Flags:
///     c = value bit 7
///     z = result == 0
///     n = result 0x80 != 0
/// 0x2A - 1 byte - 2 cycles - accumulator
/// 0x26 - 2 bytes - 5 cycles - zeroPage
/// 0x36 - 2 bytes - 6 cycles - zeroPage,x
/// 0x2E - 3 bytes - 6 cycles - absolute
/// 0x3E - 3 bytes - 7 cycles - absolute,x
pub fn rol(cpu: *Chip, ret: AddressReturn) bool {
    if (ret.accumulator) {
        const c: u16 = @intFromBool(cpu.status.isSet(.c));
        const value: u16 = cpu.a;
        const result = value << 1 | c;
        cpu.status.set(.c, result & 0xFF00 > 0);
        cpu.status.set(.z, result & 0x00FF == 0);
        cpu.status.set(.n, result & 0x80 != 0);
        cpu.a = @truncate(result);
    } else {
        const c: u16 = @intFromBool(cpu.status.isSet(.c));
        const value: u16 = cpu.read(ret.address);
        const result = value << 1 | c;
        cpu.status.set(.c, result & 0xFF00 > 0);
        cpu.status.set(.z, result & 0x00FF == 0);
        cpu.status.set(.n, result & 0x80 != 0);
        cpu.write(ret.address, @truncate(result));
    }
    return false;
}

/// ROR - Rotate Right
/// `value = value >> 1 through C` or `C -> [76543210] -> C`
/// Flags:
///     c = value bit 0
///     z = result == 0
///     n = result 0x80 != 0
/// 0x6A - 1 byte - 2 cycles - accumulator
/// 0x66 - 2 bytes - 5 cycles - zeroPage
/// 0x76 - 2 bytes - 6 cycles - zeroPage,x
/// 0x6E - 3 bytes - 6 cycles - absolute
/// 0x7E - 3 bytes - 7 cycles - absolute,x
pub fn ror(cpu: *Chip, ret: AddressReturn) bool {
    if (ret.accumulator) {
        const c: u16 = @intFromBool(cpu.status.isSet(.c));
        const value: u16 = cpu.a;
        const result = (c << 7) | (value >> 1);
        cpu.status.set(.c, value & 0x0001 != 0);
        cpu.status.set(.z, result & 0x00FF == 0);
        cpu.status.set(.n, result & 0x80 != 0);
        cpu.a = @truncate(result);
    } else {
        const c: u16 = @intFromBool(cpu.status.isSet(.c));
        const value: u16 = cpu.read(ret.address);
        const result = (c << 7) | (value >> 1);
        cpu.status.set(.c, value & 0x0001 != 0);
        cpu.status.set(.z, result & 0x00FF == 0);
        cpu.status.set(.n, result & 0x80 != 0);
        cpu.write(ret.address, @truncate(result));
    }
    return false;
}

/// AND - Bitwise AND
/// `A = A & memory`
/// Flags:
///     z = result == 0
///     n = result 0x80 != 0
/// 0x29 - 2 bytes - 2 cycles - #immediate
/// 0x25 - 2 bytes - 3 cycles - zeroPage
/// 0x35 - 2 bytes - 4 cycles - zeroPage,x
/// 0x2D - 3 bytes - 4 cycles - absolute
/// 0x3D - 3 bytes - 4 cycles* - absolute,x
/// 0x39 - 3 bytes - 4 cycles* - absolute,y
/// 0x21 - 2 bytes - 6 cycles - (indirect,x)
/// 0x31 - 2 bytes - 5 cycles* - (indirect),y
pub fn @"and"(cpu: *Chip, ret: AddressReturn) bool {
    const value = cpu.read(ret.address);
    cpu.a = cpu.a & value;
    cpu.status.set(.z, cpu.a == 0);
    cpu.status.set(.n, cpu.a & 0x80 != 0);
    return ret.cycle_request;
}

/// ORA - Bitwise OR
/// `A = a | memory`
/// Flags:
///     z = result == 0
///     n = result 0x80 != 0
/// 0x09 - 2 bytes - 2 cycles - #immediate
/// 0x05 - 2 bytes - 3 cycles - zeroPage
/// 0x15 - 2 bytes - 4 cycles - zeroPage,x
/// 0x0D - 3 bytes - 4 cycles - absolute
/// 0x1D - 3 bytes - 4 cycles* - absolute,x
/// 0x19 - 3 bytes - 4 cycles* - absolute,y
/// 0x01 - 2 bytes - 6 cycles - (indirect,x)
/// 0x11 - 2 bytes - 5 cycles* - (indirect),y
pub fn ora(cpu: *Chip, ret: AddressReturn) bool {
    const value = cpu.read(ret.address);
    cpu.a = cpu.a | value;
    cpu.status.set(.z, cpu.a == 0);
    cpu.status.set(.n, cpu.a & 0x80 != 0);
    return ret.cycle_request;
}

/// EOR - Bitwise Exclusive OR
/// `A = A ^ memory`
/// Flags:
///     z = result == 0
///     n = result 0x80 != 0
/// 0x49 - 2 bytes - 2 cycles - #immediate
/// 0x45 - 2 bytes - 3 cycles - zeroPage
/// 0x55 - 2 bytes - 4 cycles - zeroPage,x
/// 0x4D - 3 bytes - 4 cycles - absolute
/// 0x5D - 3 bytes - 4 cycles* - absolute,x
/// 0x59 - 3 bytes - 4 cycles* - absolute,y
/// 0x41 - 2 bytes - 6 cycles - (indirect,x)
/// 0x51 - 2 bytes - 5 cycles* - (indirect),y
pub fn eor(cpu: *Chip, ret: AddressReturn) bool {
    const value = cpu.read(ret.address);
    cpu.a = cpu.a ^ value;
    cpu.status.set(.z, cpu.a == 0);
    cpu.status.set(.n, cpu.a & 0x80 != 0);
    return ret.cycle_request;
}

/// BIT - BIT Test
/// `A & memory`
/// Flags:
///     z = result == 0
///     v = memory bit 6
///     n = memory bit 7
/// 0x24 - 2 bytes - 3 cycles - zeroPage
/// 0x2C - 3 bytes - 4 cycles - absolute
pub fn bit(cpu: *Chip, ret: AddressReturn) bool {
    const value = cpu.read(ret.address);
    const result = cpu.a & value;
    cpu.status.set(.z, result == 0);
    cpu.status.set(.v, value & 0x40 != 0);
    cpu.status.set(.n, value & 0x80 != 0);
    return false;
}

/// CMP - Compare A
/// `A - memory`
/// Flags:
///     c = A >= memory
///     z = A == memory
///     n = result & 0x80 != 0
/// 0xC9 - 2 bytes - 2 cycles - #immediate
/// 0xC5 - 2 bytes - 3 cycles - zeroPage
/// 0xD5 - 2 bytes - 4 cycles - zeroPage,x
/// 0xCD - 3 bytes - 4 cycles - absolute
/// 0xDD - 3 bytes - 4 cycles* - absolute,x
/// 0xD9 - 3 bytes - 4 cycles* - absolute,y
/// 0xC1 - 2 bytes - 6 cycles - (indirect,x)
/// 0xD1 - 2 bytes - 5 cycles* - (indirect),y
pub fn cmp(cpu: *Chip, ret: AddressReturn) bool {
    const value = cpu.read(ret.address);
    const result = cpu.a -% value;
    cpu.status.set(.c, cpu.a >= value);
    cpu.status.set(.z, cpu.a == value);
    cpu.status.set(.n, result & 0x80 != 0);
    return ret.cycle_request;
}

/// CPX - Compare X
/// `X - memory`
/// Flags:
///     c = X >= memory
///     z = X == memory
///     n = result & 0x80 != 0
/// 0xE0 - 2 bytes - 2 cycles - #immediate
/// 0xE4 - 2 bytes - 3 cycles - zeroPage
/// 0xEC - 3 bytes - 4 cycles - absolute
pub fn cpx(cpu: *Chip, ret: AddressReturn) bool {
    const value = cpu.read(ret.address);
    const result = cpu.x -% value;
    cpu.status.set(.c, cpu.x >= value);
    cpu.status.set(.z, cpu.x == value);
    cpu.status.set(.n, result & 0x80 != 0);
    return ret.cycle_request;
}

/// CPY - Compare Y
/// `Y - memory`
/// Flags:
///     c = Y >= memory
///     z = Y == memory
///     n = result & 0x80 != 0
/// 0xC0 - 2 bytes - 2 cycles - #immediate
/// 0xC4 - 2 bytes - 3 cycles - zeroPage
/// 0xCC - 3 bytes - 4 cycles - absolute
pub fn cpy(cpu: *Chip, ret: AddressReturn) bool {
    const value = cpu.read(ret.address);
    const result = cpu.y -% value;
    cpu.status.set(.c, cpu.y >= value);
    cpu.status.set(.z, cpu.y == value);
    cpu.status.set(.n, result & 0x80 != 0);
    return ret.cycle_request;
}

/// BCC - Branch if Carry Clear
/// `PC = PC + 2 + memory (signed)`
/// 0x90 - 2 bytes - 2 cycles (3 if branch taken, 4 if page crossed) - relative
pub fn bcc(cpu: *Chip, ret: AddressReturn) bool {
    if (!cpu.status.isSet(.c)) {
        cpu.cycles_left += 1;
        const new_pc: u16 = cpu.pc + ret.relative;

        if ((new_pc & 0xFF00) != (cpu.pc & 0xFF00)) {
            cpu.cycles_left += 1;
        }

        cpu.pc = new_pc;
    }

    return false;
}

/// BCS - Branch if Carry Set
/// `PC = PC + 2 + memory (signed)`
/// 0xB0 - 2 bytes - 2 cycles (3 if branch taken, 4 if page crossed) - relative
pub fn bcs(cpu: *Chip, ret: AddressReturn) bool {
    if (cpu.status.isSet(.c)) {
        cpu.cycles_left += 1;
        const new_pc: u16 = cpu.pc + ret.relative;

        if ((new_pc & 0xFF00) != (cpu.pc & 0xFF00)) {
            cpu.cycles_left += 1;
        }

        cpu.pc = new_pc;
    }

    return false;
}

/// BEQ - Branch if Equal
/// `PC = PC + 2 + memory (signed)`
/// 0xF0 - 2 bytes - 2 cycles (3 if branch taken, 4 if page crossed) - relative
pub fn beq(cpu: *Chip, ret: AddressReturn) bool {
    if (cpu.status.isSet(.z)) {
        cpu.cycles_left += 1;
        const new_pc: u16 = cpu.pc + ret.relative;

        if ((new_pc & 0xFF00) != (cpu.pc & 0xFF00)) {
            cpu.cycles_left += 1;
        }

        cpu.pc = new_pc;
    }

    return false;
}

/// BNE - Branch if Not Equal
/// `PC = PC + 2 + memory (signed)`
/// 0xD0 - 2 bytes - 2 cycles (3 if branch taken, 4 if page crossed) - relative
pub fn bne(cpu: *Chip, ret: AddressReturn) bool {
    if (!cpu.status.isSet(.z)) {
        cpu.cycles_left += 1;
        const new_pc: u16 = cpu.pc + ret.relative;

        if ((new_pc & 0xFF00) != (cpu.pc & 0xFF00)) {
            cpu.cycles_left += 1;
        }

        cpu.pc = new_pc;
    }

    return false;
}

/// BPL - Branch if Plus
/// `PC = PC + 2 + memory (signed)`
/// 0x10 - 2 bytes - 2 cycles (3 if branch taken, 4 if page crossed) - relative
pub fn bpl(cpu: *Chip, ret: AddressReturn) bool {
    if (!cpu.status.isSet(.n)) {
        cpu.cycles_left += 1;
        const new_pc: u16 = cpu.pc + ret.relative;

        if ((new_pc & 0xFF00) != (cpu.pc & 0xFF00)) {
            cpu.cycles_left += 1;
        }

        cpu.pc = new_pc;
    }

    return false;
}

/// BMI - Branch if Minus
/// `PC = PC + 2 + memory (signed)`
/// 0x30 - 2 bytes - 2 cycles (3 if branch taken, 4 if page crossed) - relative
pub fn bmi(cpu: *Chip, ret: AddressReturn) bool {
    if (cpu.status.isSet(.n)) {
        cpu.cycles_left += 1;
        const new_pc: u16 = cpu.pc + ret.relative;

        if ((new_pc & 0xFF00) != (cpu.pc & 0xFF00)) {
            cpu.cycles_left += 1;
        }

        cpu.pc = new_pc;
    }

    return false;
}

/// BVC - Branch if Overflow CLear
/// `PC = PC + 2 + memory (signed)`
/// 0x50 - 2 bytes - 2 cycles (3 if branch taken, 4 if page crossed) - relative
pub fn bvc(cpu: *Chip, ret: AddressReturn) bool {
    if (!cpu.status.isSet(.v)) {
        cpu.cycles_left += 1;
        const new_pc: u16 = cpu.pc + ret.relative;

        if ((new_pc & 0xFF00) != (cpu.pc & 0xFF00)) {
            cpu.cycles_left += 1;
        }

        cpu.pc = new_pc;
    }

    return false;
}

/// JMP - Jump
/// `PC = Memory`
/// 0x4C - 3 bytes - 3 cycles - absolute
/// 0x6C - 3 bytes - 5 cycles - (indirect)
pub fn jmp(cpu: *Chip, ret: AddressReturn) bool {
    cpu.pc = ret.address;
    return false;
}

/// JSR - Jump to Subroutine
/// `push PC + 2 to stack`
/// `PC = memory`
/// 0x20 - 3 bytes - 6 cycles - absolute
pub fn jsr(cpu: *Chip, ret: AddressReturn) bool {
    cpu.pc -= 1;

    micro.writeSp(cpu, @truncate(cpu.pc >> 8));
    cpu.sp -%= 1;
    micro.writeSp(cpu, @truncate(cpu.pc));
    cpu.sp -%= 1;

    cpu.pc = ret.address;
    return false;
}

/// RTS - Return from Subroutine
/// `pull PC from stack`
/// `PC = PC + 1`
/// 0x60 - 1 byte - 6 cycles - implied
pub fn rts(cpu: *Chip, _: AddressReturn) bool {
    cpu.sp +%= 1;
    const lo: u16 = micro.readSp(cpu);
    cpu.sp +%= 1;
    const hi: u16 = micro.readSp(cpu);
    cpu.pc = (hi << 8) | lo;

    cpu.pc += 1;
    return false;
}

/// BRK - Break (software IRQ)
/// `push PC + 2 to stack`
/// `push NV11DIZC flags to stack`
/// `PC = ($FFFE)`
/// 0x00 - 1 byte - 7 cycles - implied
/// Flags:
///     i = 1
///     b = pushed as 1
pub fn brk(cpu: *Chip, _: AddressReturn) bool {
    cpu.pc += 1;

    cpu.status.set(.i, true);
    micro.writeSp(cpu, @truncate(cpu.pc >> 8));
    cpu.sp -= 1;
    micro.writeSp(cpu, @truncate(cpu.pc));
    cpu.sp -= 1;

    cpu.status.set(.b, true);
    micro.writeSp(cpu, cpu.status.data);
    cpu.sp -= 1;
    cpu.status.set(.b, false);

    const lo: u16 = cpu.read(0xFFFE);
    const hi: u16 = cpu.read(0xFFFF);
    cpu.pc = (hi << 8) | lo;

    return false;
}

/// RTI - Return from interrupt
/// `pull NVxxDIZC flags from stack`
/// `pull PC from stack`
/// 0x40 - 1 byte - 6 cycles - implied
/// Flags:
///     c = result & 0x01
///     z = result & 0x02
///     i = result & 0x04
///     d = result & 0x08
///     v = result & 0x40
///     n = result & 0x80
pub fn rti(cpu: *Chip, _: AddressReturn) bool {
    cpu.sp += 1;
    cpu.status.data = micro.readSp(cpu);
    cpu.status.set(.b, false);
    cpu.status.set(.u, false);

    cpu.sp += 1;
    const lo: u16 = micro.readSp(cpu);
    cpu.sp += 1;
    const hi: u16 = micro.readSp(cpu);

    cpu.pc = (hi << 8) | lo;
    return false;
}

/// PHA - Push A
/// `($0100 + SP) = A`
/// `SP = SP - 1`
/// 0x48 - 1 byte - 3 cycles - implied
pub fn pha(cpu: *Chip, _: AddressReturn) bool {
    micro.writeSp(cpu, cpu.a);
    cpu.sp -%= 1;
    return false;
}

/// PLA - Pull A
/// `SP = SP + 1`
/// `A = ($0100 + SP)`
/// Flags:
///     z = result == 0
///     n = result & 0x80 != 0
/// 0x68 - 1 byte - 4 cycles - implied
pub fn pla(cpu: *Chip, _: AddressReturn) bool {
    cpu.sp +%= 1;
    cpu.a = micro.readSp(cpu);
    cpu.status.set(.z, cpu.a == 0);
    cpu.status.set(.n, cpu.a & 0x80 != 0);
    return false;
}

/// PHP - Push Processor Status
/// `($0100 + SP) = NV11DIZC`
/// `SP = SP - 1`
/// 0x08 - 1 byte - 3 cycles - implied
pub fn php(cpu: *Chip, _: AddressReturn) bool {
    var local: Status = cpu.status;
    local.set(.b, true);
    local.set(.u, true);
    micro.writeSp(cpu, local.data);
    cpu.sp -%= 1;
    return false;
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
pub fn plp(cpu: *Chip, _: AddressReturn) bool {
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

/// TXS - Transfer X to Stack Pointer
/// `SP = x`
/// 0x9A - 1 byte - 2 cycles - implied
pub fn txs(cpu: *Chip, _: AddressReturn) bool {
    cpu.sp = cpu.x;
    return false;
}

/// TSX - Transfer Stack Pointer to X
/// `X = SP`
/// Flags:
///     z = result == 0
///     n = result & 0x80 != 0
/// 0xBA - 1 byte - 2 cycles - implied
pub fn tsx(cpu: *Chip, _: AddressReturn) bool {
    cpu.x = cpu.sp;
    cpu.status.set(.z, cpu.x == 0);
    cpu.status.set(.n, cpu.x & 0x80 != 0);
    return false;
}

/// CLC - Clear Carry
/// `C = 0`
/// 0x18 - 1 byte - 2 cycles - implied
pub fn clc(cpu: *Chip, _: AddressReturn) bool {
    cpu.status.set(.c, false);
    return false;
}

/// SEC - Set Carry
/// `C = 1`
/// 0x38 - 1 byte - 2 cycles - implied
pub fn sec(cpu: *Chip, _: AddressReturn) bool {
    cpu.status.set(.c, true);
    return false;
}

/// CLI - Clear Interrupt Disable
/// `I = 0`
/// 0x58 - 1 byte - 2 cycles - implied
pub fn cli(cpu: *Chip, _: AddressReturn) bool {
    cpu.status.set(.i, false);
    return false;
}

/// SEI - Set interrupt Disable
/// `I = 1`
/// 0x78 - 1 byte - 2 cycles - implied
pub fn sei(cpu: *Chip, _: AddressReturn) bool {
    cpu.status.set(.i, true);
    return false;
}

/// CLD - CLear Decimal
/// `D = 0`
/// 0xD8 - 1 byte - 2 cycles - implied
pub fn cld(cpu: *Chip, _: AddressReturn) bool {
    cpu.status.set(.d, false);
    return false;
}

/// SED - Set Decimal
/// `D = 1`
/// 0xF8 - 1 byte - 2 cycles - implied
pub fn sed(cpu: *Chip, _: AddressReturn) bool {
    cpu.status.set(.d, true);
    return false;
}

/// CLV - Clear Overflow
/// `V = 0`
/// 0xB8 - 1 byte - 2 cycles - implied
pub fn clv(cpu: *Chip, _: AddressReturn) bool {
    cpu.status.set(.v, false);
    return false;
}

/// NOP - No Operation
/// 0xEA - 1 byte - 2 cycles - implied
pub fn nop(_: *Chip, _: AddressReturn) bool {
    return false;
}

pub fn type_unknown(_: *Chip, _: AddressReturn) bool {
    @panic("unknown instruction type!");
}
