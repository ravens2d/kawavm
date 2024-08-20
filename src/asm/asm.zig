const std = @import("std");

const vm = @import("../vm/vm.zig");

const op_map = std.StaticStringMap(vm.Operation).initComptime(.{
    .{ "NOP", vm.Operation.nop },
});

pub fn assemble(allocator: std.mem.Allocator, asm_path: []const u8) !void {
    const asm_file = try std.fs.cwd().openFile(asm_path, .{});
    defer asm_file.close();

    const asm_data = try asm_file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(asm_data);

    const tokens = try tokenize(allocator, asm_data);
    defer tokens.deinit();

    const out_writer = std.io.getStdOut().writer();

    var i: usize = 0;
    var rom_ptr: u16 = 0;
    while (i < tokens.items.len) {
        const token = tokens.items[i];
        if (token[token.len - 1] == ':') {
            // TODO: handle tags here
            std.debug.print("label: {s}\n", .{token});
        } else {
            const op = try strToOp(token);
            try out_writer.writeByte(@intFromEnum(op));
            rom_ptr += 1;
            if (op == vm.Operation.push) {
                i += 1;
                const val_str = tokens.items[i];
                const val = try std.fmt.parseInt(u16, val_str, 10);
                try out_writer.writeInt(u16, val, std.builtin.Endian.little);
                rom_ptr += 2;
            }
        }
        i += 1;
    }
}

pub fn tokenize(allocator: std.mem.Allocator, data: []u8) !std.ArrayList([]u8) {
    var tokens = std.ArrayList([]u8).init(allocator);

    var start: usize = 0;
    var end: usize = 0;
    for (data, 0..) |c, i| {
        if (c == ' ' or c == '\n' or c == '\t') {
            end = i;
            if (end != start) {
                try tokens.append(data[start..end]);
            }
            start = i + 1;
        }
    }

    return tokens;
}

pub fn strToOp(data: []u8) !vm.Operation {
    var buf: [256]u8 = undefined;
    const lower = std.ascii.lowerString(&buf, data);
    return std.meta.stringToEnum(vm.Operation, lower) orelse error.InvlaidOpcode;
}

pub fn strToOpMap(data: []u8) !vm.Operation {
    return op_map.get(data) orelse error.InvalidOpcode;
}
