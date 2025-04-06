const Cpu = @import("nes/cpu.zig").Cpu;
pub const Nes = struct {
    cpu: Cpu = .init,

    pub fn powerOn(self: *Nes) void {
        self.cpu.powerOn();
    }
};
