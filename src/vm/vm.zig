const std = @import("std");

pub const Operation = enum(u8) {
    nop,
    brk,
    push,
    pop,
    dup,
    swap,
    add,
    mult,
    sub,
    div,
    jump,
    jumpz,
    load,
    store,
    _, // for catching invalid opcodes later in a switch
};

pub const VMState = struct {
    rom: []u8 = undefined,
    ram: [65536]u8 = undefined,
    stack: [1024]u8 = undefined,

    pc: u16 = 0,
    stack_ptr: u16 = 0,

    rom_buffer: [16384]u8 = undefined,

    pub fn init(rom_path: []const u8) !VMState {
        var state = VMState{};

        const rom_file = try std.fs.cwd().openFile(rom_path, .{});
        defer rom_file.close();

        const rom_size = try rom_file.readAll(&state.rom_buffer);
        state.rom = state.rom_buffer[0..rom_size];

        return state;
    }

    pub fn step(self: *VMState) !bool {
        const op = try self.fetchRomByte(self.pc);
        self.pc += 1;

        switch (@as(Operation, @enumFromInt(op))) {
            Operation.nop => {},
            Operation.brk => {
                return false;
            },
            Operation.push => {
                const val = try self.fetchRomWord(self.pc);
                try self.pushStackWord(val);
                self.pc += 2;
            },
            Operation.pop => {
                const val = try self.popStackWord();
                std.debug.print("POP: {d}\n", .{val});
            },
            Operation.dup => {
                const val = try self.popStackWord();
                try self.pushStackWord(val);
                try self.pushStackWord(val);
            },
            Operation.swap => {
                const val_a = try self.popStackWord();
                const val_b = try self.popStackWord();
                try self.pushStackWord(val_a);
                try self.pushStackWord(val_b);
            },
            Operation.add => {
                const val_a = try self.popStackWord();
                const val_b = try self.popStackWord();
                try self.pushStackWord(@addWithOverflow(val_a, val_b)[0]);
            },
            Operation.mult => {
                const val_a = try self.popStackWord();
                const val_b = try self.popStackWord();
                try self.pushStackWord(@mulWithOverflow(val_a, val_b)[0]);
            },
            Operation.sub => {
                const val_a = try self.popStackWord();
                const val_b = try self.popStackWord();
                try self.pushStackWord(@subWithOverflow(val_a, val_b)[0]);
            },
            Operation.div => {
                const val_a = try self.popStackWord();
                const val_b = try self.popStackWord();
                try self.pushStackWord(val_a / val_b);
            },
            Operation.jump => {
                const loc = try self.popStackWord();
                self.pc = loc;
            },
            Operation.jumpz => {
                const test_val = try self.popStackWord();
                const loc = try self.popStackWord();
                if (test_val == 0) {
                    self.pc = loc;
                }
            },
            Operation.load => {
                const loc = try self.popStackWord();
                const val = try self.loadWord(loc);
                try self.pushStackWord(val);
            },
            Operation.store => {
                const val = try self.popStackWord();
                const loc = try self.popStackWord();
                try self.storeWord(loc, val);
            },
            else => {
                return error.InvalidOpcode;
            },
        }

        std.debug.print("{s}\t->\t", .{@tagName(@as(Operation, @enumFromInt(op)))});
        self.inspect();
        return true;
    }

    pub fn inspect(self: *VMState) void {
        std.debug.print("PC: {X:0>4} | SP: {X:0>4} | Stack: ", .{ self.pc, self.stack_ptr });
        for (self.stack[0..self.stack_ptr]) |b| {
            std.debug.print("{X:0>2} ", .{b});
        }
        std.debug.print("\n", .{});
    }

    fn fetchRomByte(self: *VMState, address: u16) !u8 {
        if (address >= self.rom.len) {
            return error.InvalidROMAccess;
        }
        return self.rom[address];
    }

    fn fetchRomWord(self: *VMState, address: u16) !u16 {
        const lower = try fetchRomByte(self, address);
        const upper = try fetchRomByte(self, address + 1);
        return @as(u16, @intCast(lower)) | (@as(u16, @intCast(upper)) << 8);
    }

    fn pushStackWord(self: *VMState, value: u16) !void {
        if (self.stack_ptr + 2 >= self.stack.len) {
            return error.StackOverflow;
        }
        self.stack[self.stack_ptr] = @truncate(value);
        self.stack[self.stack_ptr + 1] = @truncate(value >> 8);
        self.stack_ptr += 2;
    }

    fn popStackWord(self: *VMState) !u16 {
        if (self.stack_ptr < 2) {
            return error.StackUnderflow;
        }
        const lower = self.stack[self.stack_ptr - 2];
        const upper = self.stack[self.stack_ptr - 1];
        self.stack_ptr -= 2;
        return @as(u16, @intCast(lower)) | (@as(u16, @intCast(upper)) << 8);
    }

    fn storeWord(self: *VMState, address: u16, value: u16) !void {
        if (address + 1 >= self.ram.len) {
            return error.InvalidMemoryAccess;
        }
        self.ram[address] = @truncate(value);
        self.ram[address + 1] = @truncate(value >> 8);
    }

    fn loadWord(self: *VMState, address: u16) !u16 {
        if (address >= self.ram.len) {
            return error.InvalidMemoryAccess;
        }
        const lower = self.ram[address];
        const upper = self.ram[address + 1];
        return @as(u16, @intCast(lower)) | (@as(u16, @intCast(upper)) << 8);
    }
};
