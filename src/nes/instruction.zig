const cpu = @import("cpu.zig");
const Cpu = cpu.Cpu;
const Bus = cpu.ActiveBus;

pub const Instruction = struct {
    name: []const u8 = "xxx",
    instruction: *const fn (*Cpu(Bus)) bool = &xxx,
    addr_mode: *const fn (*Cpu(Bus)) bool = &xxx,
    cycles: u8 = 0,
};

pub const table: [16 * 16]Instruction = blk: {
    var t: [16 * 16]Instruction = undefined;

    for (&t) |*i| {
        i.cycles = 1;
        i.name = "xxx";
        i.addr_mode = &xxx;
        i.instruction = &xxx;
    }

    break :blk t;
};

pub fn xxx(self: *Cpu(Bus)) bool {
    _ = self;
    return false;
}
