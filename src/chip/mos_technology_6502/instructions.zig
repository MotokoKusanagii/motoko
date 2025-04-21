const std = @import("std");
const TestBus = @import("testing.zig").TestBus;
const Chip = @import("../mos_technology_6502.zig").Chip;
const Status = @import("../mos_technology_6502.zig").Status;

pub const AddressReturn = struct {
    cycle_request: bool,
    address: u16,
    accumulator: bool = false,
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
        const hi: u16 = cpu.read(address +% 1);
        return (hi << 8) | lo;
    }
};

pub fn accumulator(_: anytype) AddressReturn {
    return .{
        .cycle_request = false,
        .address = 0x00,
        .accumulator = true,
    };
}

pub fn implied(_: anytype) AddressReturn {
    return .{
        .cycle_request = false,
        .address = 0x00,
    };
}

pub fn immediate(cpu: anytype) AddressReturn {
    const address = cpu.pc;
    cpu.pc += 1;
    return .{
        .cycle_request = false,
        .address = address,
    };
}

pub fn zeroPage(cpu: anytype) AddressReturn {
    const address: u16 = cpu.read(cpu.pc);
    cpu.pc += 1;
    return .{
        .cycle_request = false,
        .address = address,
    };
}

pub fn zeroPageX(cpu: anytype) AddressReturn {
    var address: u8 = cpu.read(cpu.pc);
    address +%= cpu.x;
    cpu.pc += 1;
    return .{
        .cycle_request = false,
        .address = address,
    };
}

pub fn zeroPageY(cpu: anytype) AddressReturn {
    var address: u8 = cpu.read(cpu.pc);
    address +%= cpu.y;
    cpu.pc += 1;
    return .{
        .cycle_request = false,
        .address = address,
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

pub fn absoluteX(cpu: anytype) AddressReturn {
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

pub fn absoluteY(cpu: anytype) AddressReturn {
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

pub fn indirectX(cpu: anytype) AddressReturn {
    var ptr: u8 = cpu.read(cpu.pc);
    cpu.pc += 1;

    ptr +%= cpu.x;

    const address = micro.fetch16(cpu, ptr);

    return .{
        .cycle_request = false,
        .address = address,
    };
}

pub fn indirectY(cpu: anytype) AddressReturn {
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

pub fn address_unknown(_: anytype) AddressReturn {
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
pub fn lda(cpu: anytype, ret: AddressReturn) bool {
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
pub fn sta(cpu: anytype, ret: AddressReturn) bool {
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
pub fn ldx(cpu: anytype, ret: AddressReturn) bool {
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
pub fn stx(cpu: anytype, ret: AddressReturn) bool {
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
pub fn ldy(cpu: anytype, ret: AddressReturn) bool {
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
pub fn sty(cpu: anytype, ret: AddressReturn) bool {
    cpu.write(ret.address, cpu.y);
    return false;
}

/// TAX - Transfer A to X
/// `X = A`
/// Flags:
///     z = result == 0
///     n = result & 0x80 != 0
/// 0xAA - 1 byte - 2 cycles - implied
pub fn tax(cpu: anytype, _: AddressReturn) bool {
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
pub fn txa(cpu: anytype, _: AddressReturn) bool {
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
pub fn tay(cpu: anytype, _: AddressReturn) bool {
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
pub fn tya(cpu: anytype, _: AddressReturn) bool {
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
pub fn adc(cpu: anytype, ret: AddressReturn) bool {
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
pub fn sbc(cpu: anytype, ret: AddressReturn) bool {
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
pub fn inc(cpu: anytype, ret: AddressReturn) bool {
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
pub fn dec(cpu: anytype, ret: AddressReturn) bool {
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
pub fn inx(cpu: anytype, _: AddressReturn) bool {
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
pub fn dex(cpu: anytype, _: AddressReturn) bool {
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
pub fn iny(cpu: anytype, _: AddressReturn) bool {
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
pub fn dey(cpu: anytype, _: AddressReturn) bool {
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
pub fn asl(cpu: anytype, ret: AddressReturn) bool {
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
pub fn lsr(cpu: anytype, ret: AddressReturn) bool {
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
pub fn rol(cpu: anytype, ret: AddressReturn) bool {
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
pub fn ror(cpu: anytype, ret: AddressReturn) bool {
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

/// JMP - Jump
/// `PC = Memory`
/// 0x4C - 3 bytes - 3 cycles - absolute
/// 0x6C - 3 bytes - 5 cycles - (indirect)
pub fn jmp(cpu: anytype, ret: AddressReturn) bool {
    cpu.pc = ret.address;
    return false;
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

/// BRK - Break (software IRQ)
/// `push PC + 2 to stack`
/// `push NV11DIZC flags to stack`
/// `PC = ($FFFE)`
/// 0x00 - 1 byte - 7 cycles - implied
/// Flags:
///     i = 1
///     b = pushed as 1
pub fn brk(cpu: anytype, _: AddressReturn) bool {
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
pub fn rti(cpu: anytype, _: AddressReturn) bool {
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
pub fn pha(cpu: anytype, _: AddressReturn) bool {
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
pub fn pla(cpu: anytype, _: AddressReturn) bool {
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
pub fn php(cpu: anytype, _: AddressReturn) bool {
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

/// TXS - Transfer X to Stack Pointer
/// `SP = x`
/// 0x9A - 1 byte - 2 cycles - implied
pub fn txs(cpu: anytype, _: AddressReturn) bool {
    cpu.sp = cpu.x;
    return false;
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

/// CLC - Clear Carry
/// `C = 0`
/// 0x18 - 1 byte - 2 cycles - implied
pub fn clc(cpu: anytype, _: AddressReturn) bool {
    cpu.status.set(.c, false);
    return false;
}

/// SEC - Set Carry
/// `C = 1`
/// 0x38 - 1 byte - 2 cycles - implied
pub fn sec(cpu: anytype, _: AddressReturn) bool {
    cpu.status.set(.c, true);
    return false;
}

/// CLI - Clear Interrupt Disable
/// `I = 0`
/// 0x58 - 1 byte - 2 cycles - implied
pub fn cli(cpu: anytype, _: AddressReturn) bool {
    cpu.status.set(.i, false);
    return false;
}

/// SEI - Set interrupt Disable
/// `I = 1`
/// 0x78 - 1 byte - 2 cycles - implied
pub fn sei(cpu: anytype, _: AddressReturn) bool {
    cpu.status.set(.i, true);
    return false;
}

/// CLD - CLear Decimal
/// `D = 0`
/// 0xD8 - 1 byte - 2 cycles - implied
pub fn cld(cpu: anytype, _: AddressReturn) bool {
    cpu.status.set(.d, false);
    return false;
}

/// SED - Set Decimal
/// `D = 1`
/// 0xF8 - 1 byte - 2 cycles - implied
pub fn sed(cpu: anytype, _: AddressReturn) bool {
    cpu.status.set(.d, true);
    return false;
}

/// CLV - Clear Overflow
/// `V = 0`
/// 0xB8 - 1 byte - 2 cycles - implied
pub fn clv(cpu: anytype, _: AddressReturn) bool {
    cpu.status.set(.v, false);
    return false;
}

/// NOP - No Operation
/// 0xEA - 1 byte - 2 cycles - implied
pub fn nop(_: anytype, _: AddressReturn) bool {
    return false;
}

pub fn type_unknown(_: anytype, _: AddressReturn) bool {
    @panic("unknown instruction type!");
}
