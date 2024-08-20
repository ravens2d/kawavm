const std = @import("std");

const vm = @import("./vm/vm.zig");
const asmlib = @import("./asm/asm.zig");

pub fn main() !void {
    if (std.os.argv.len < 3) {
        std.debug.print("Usage: run [.rom] or build [.asm]\n", .{});
        return;
    }
    const mode: []const u8 = std.mem.span(std.os.argv[1]);
    const file_path: []const u8 = std.mem.span(std.os.argv[2]);

    if (std.mem.eql(u8, mode, "build")) {
        try asmlib.assemble(std.heap.page_allocator, file_path);
    } else if (std.mem.eql(u8, mode, "run")) {
        try run_vm(file_path);
    } else {
        std.debug.print("Usage: run [.rom] or build [.asm]\n", .{});
        return;
    }
}

pub fn run_vm(rom_path: []const u8) !void {
    var state = try vm.VMState.init(rom_path);

    var can_step = true;
    while (can_step) {
        can_step = try state.step();
    }
}
