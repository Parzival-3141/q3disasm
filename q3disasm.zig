const std = @import("std");
const log = std.log;

const usage =
    \\Usage: q3disasm [options] <file>
    \\Disassembles a QVM file to stdout.
    \\
    \\Options:
    \\    -map <file>    Path to a .map file containing symbol info. If unspecified it'll try to find one with the same name and directory as the input QVM file.
    \\    -no-syms       Don't print symbol info with disassembly.
    \\    -header        Print the QVM header before disassembly.
    \\    -h|help        Print this help text and exit.
    \\
;

pub fn main() !void {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    var args = try std.process.argsWithAllocator(arena);
    _ = args.skip();

    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    const stdout = bw.writer();
    defer bw.flush() catch |err| std.log.err("unable to flush to stdout: {s}", .{@errorName(err)});

    var qvm_path: ?[]const u8 = null;
    var map_path: ?[]const u8 = null;
    var print_header = false;
    var no_syms = false;
    while (args.next()) |arg| {
        if (arg[0] == '-') {
            if (strEql(arg[1..], "map")) {
                map_path = args.next() orelse return log.err("-map expected a file path", .{});
            } else if (strEql(arg[1..], "no-syms")) {
                no_syms = true;
            } else if (strEql(arg[1..], "header")) {
                print_header = true;
            } else if (strEql(arg[1..], "help") or strEql(arg[1..], "h")) {
                return stdout.print(usage, .{});
            } else {
                log.err("unknown flag {s}", .{arg});
                return stdout.print(usage, .{});
            }
        } else {
            if (qvm_path != null) return log.err("expected only one qvm file", .{});
            qvm_path = arg;
        }
    }

    const qvm = std.fs.cwd().readFileAlloc(
        arena,
        qvm_path orelse return log.err("expected a qvm file path", .{}),
        1024 * 1024,
    ) catch |err| switch (err) {
        error.FileNotFound => return log.err("qvm file not found: {s}", .{qvm_path.?}),
        else => return err,
    };

    const symbols: ?[]Symbol = if (no_syms)
        null
    else if (map_path) |mp|
        parseSymbolMap(arena, mp) catch |err| switch (err) {
            error.FileNotFound => return log.err("map file not found: {s}", .{mp}),
            error.ParseError => return, // the error has already been printed
            else => return err,
        }
    else blk: {
        const without_ext = qvm_path.?[0 .. qvm_path.?.len - std.fs.path.extension(qvm_path.?).len];
        const search_path = try std.mem.concat(arena, u8, &.{ without_ext, ".map" });
        break :blk parseSymbolMap(arena, search_path) catch |err| switch (err) {
            error.FileNotFound => null,
            error.ParseError => return, // the error has already been printed
            else => return err,
        };
    };

    const header: *const VmHeader = @alignCast(@ptrCast(qvm[0..@sizeOf(VmHeader)]));

    if (header.vm_magic != VM_MAGIC or
        header.instruction_count < 0 or
        header.code_offset < 0 or
        header.code_length < 0 or
        header.data_offset < 0 or
        header.data_length < 0 or
        header.lit_length < 0 or
        header.bss_length < 0)
    {
        log.err("invalid QVM header", .{});
        return;
    }

    if (print_header) try stdout.print(
        \\{s} header:
        \\    vm_magic:          0x{X}
        \\    instruction_count: {d}
        \\    code_offset:       0x{X}
        \\    code_length:       {d}
        \\    data_offset:       0x{X}
        \\    data_length:       {d}
        \\    lit_length:        {d}
        \\    bss_length:        {d}
        \\
    , .{
        std.fs.path.basename(qvm_path.?),
        header.vm_magic,
        header.instruction_count,
        header.code_offset,
        header.code_length,
        header.data_offset,
        header.data_length,
        header.lit_length,
        header.bss_length,
    });

    const code_seg = qvm[@intCast(header.code_offset)..][0..@intCast(header.code_length)];

    var ip: u32 = 0; // index into the code segment
    var instruction: u32 = 0; // counts which instruction we're on
    var current_proc: ?*const Symbol = null; // track which procedure we're on (Unused when symbols == null)
    defer std.debug.assert((symbols == null) == (current_proc == null));

    while (ip < code_seg.len) : (instruction += 1) {
        if (symbols) |_symbols| for (_symbols) |*sym| {
            if (sym.segment != .code) break; // map entries are sorted by segment and the code segment is always first.
            if (sym.offset == instruction) {
                current_proc = sym;
                try stdout.print("\n{s}():\n", .{sym.name});
            }
        };

        try stdout.print("{X:0>8}", .{instruction});

        const op: Opcode = @enumFromInt(code_seg[ip]);
        try stdout.print(" {s: >10}", .{@tagName(op)});
        ip += 1;

        const arg_size = op.argumentSize();
        if (arg_size > 0) {
            const arg: i32 = switch (arg_size) {
                1 => code_seg[ip],
                // multi-byte arguments are little endian
                4 => std.mem.littleToNative(i32, std.mem.bytesToValue(i32, code_seg[ip..][0..4])),
                else => unreachable,
            };
            ip += arg_size;
            try stdout.print(" 0x{X: <8}", .{@as(u32, @bitCast(arg))});

            // print extra information about the argument if symbols are available
            if (symbols) |_symbols| switch (op) {
                .CONST => {
                    switch (@as(Opcode, @enumFromInt(code_seg[ip]))) {
                        .CALL => {
                            for (_symbols) |sym| {
                                if (sym.segment == .code and sym.offset == @as(u32, @bitCast(arg))) {
                                    try stdout.print(" ; {s}()", .{sym.name});
                                }
                            }
                        },
                        .LOAD1, .LOAD2, .LOAD4 => {
                            for (_symbols, 0..) |sym, i| {
                                // LIT and BSS symbol offsets are encoded relative to the DATA segment in the instruction stream.
                                // However, the .map file encodes them relative to their respective segments, so we need to apply
                                // offsets before comparing to the LOAD address argument.
                                const seg_offset: u32 = switch (sym.segment) {
                                    .code => continue,
                                    .data => 0,
                                    .lit => @intCast(header.data_length),
                                    .bss => @intCast(header.data_length + header.lit_length),
                                };
                                const sym_offset = sym.offset + seg_offset;

                                const arg_u: u32 = @bitCast(arg);
                                if (sym_offset == arg_u) {
                                    try stdout.print(" ; {s}", .{sym.name});
                                    break;
                                }

                                // check if arg is an offset into the symbol
                                if (sym_offset < arg_u) {
                                    // check the next symbol in the segment.
                                    if (i + 1 < _symbols.len) {
                                        const next = _symbols[i + 1];
                                        if (next.segment != sym.segment) continue;
                                        if (next.offset <= sym.offset) continue; // q3asm.c:HackToSegment() can cause symbol offsets to become non-contiguous
                                        if (arg_u >= next.offset + seg_offset) continue;
                                    } else continue; // if there isn't one we assume arg's not an offset

                                    try stdout.print(" ; {s}+0x{X}", .{ sym.name, arg_u - sym_offset });
                                    break;
                                }
                            }
                        },
                        .JUMP => try printJumpInfoComment(stdout, @bitCast(arg), current_proc.?),
                        else => {},
                    }
                },
                .EQ,
                .NE,
                .LTI,
                .LEI,
                .GTI,
                .GEI,
                .LTU,
                .LEU,
                .GTU,
                .GEU,
                .EQF,
                .NEF,
                .LTF,
                .LEF,
                .GTF,
                .GEF,
                => try printJumpInfoComment(stdout, @bitCast(arg), current_proc.?),
                else => {},
            };
        }

        try stdout.writeByte('\n');
    }
}

const Segment = enum(u8) {
    code = 0,
    /// initialized 32 bit data, will be byte swapped
    data = 1,
    /// strings
    lit = 2,
    /// 0 filled
    bss = 3,
};

const Symbol = struct {
    segment: Segment,
    /// if this symbol belongs to the code segment this is an offset in instructions, not bytes!
    offset: u32,
    name: []const u8,
};

/// Caller owns the returned memory and must free Symbol.name fields as well.
fn parseSymbolMap(allocator: std.mem.Allocator, path: []const u8) ![]Symbol {
    const map = try std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024);
    defer allocator.free(map);

    const num_symbols = std.mem.count(u8, map, "\n"); // @Cleanup: this is very brittle
    const syms = try allocator.alloc(Symbol, num_symbols);

    // @Cleanup
    var cursor: usize = 0;
    var current_sym: usize = 0;
    while (cursor < map.len) {
        syms[current_sym].segment = @enumFromInt(
            std.fmt.parseInt(u8, map[cursor..][0..1], 10) catch |err|
                return parseErr(err, path, cursor),
        );
        cursor += 1;

        while (isWhitespaceNoNewline(map[cursor])) : (cursor += 1) {}
        if (map[cursor] == '\n') return parseErr(error.MissingOffset, path, cursor);

        const offset_end = std.mem.indexOfAnyPos(u8, map, cursor, &std.ascii.whitespace) orelse
            return parseErr(error.InvalidOffset, path, cursor);
        syms[current_sym].offset = std.fmt.parseInt(u32, map[cursor..offset_end], 16) catch |err|
            return parseErr(err, path, cursor);
        cursor = offset_end;

        while (isWhitespaceNoNewline(map[cursor])) : (cursor += 1) {}
        if (map[cursor] == '\n') return parseErr(error.MissingName, path, cursor);

        const newline = std.mem.indexOfScalarPos(u8, map, cursor, '\n') orelse
            return parseErr(error.InvalidName, path, cursor);
        syms[current_sym].name = try allocator.dupe(u8, map[cursor..newline]);

        cursor = newline + 1;
        current_sym += 1;
    }

    return syms;
}

fn isWhitespaceNoNewline(c: u8) bool {
    if (c == '\n') return false;
    return std.ascii.isWhitespace(c);
}

fn parseErr(err: anyerror, path: []const u8, offset: usize) (error{ParseError} || std.fs.Dir.RealPathError) {
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const abs_path = try std.fs.cwd().realpath(path, &buf);
    log.err("{s} at {s}:{d}", .{ @errorName(err), abs_path, offset });
    return error.ParseError;
}

fn strEql(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

const VM_MAGIC = 0x12721444;
const VmHeader = extern struct {
    vm_magic: i32,

    instruction_count: i32,

    code_offset: i32,
    code_length: i32,

    data_offset: i32,
    data_length: i32,
    /// ( data_length - lit_length ) should be byteswapped on load
    lit_length: i32,
    /// zero filled memory appended to datalength
    bss_length: i32,
};

const Opcode = enum(u8) {
    UNDEF,

    IGNORE,

    BREAK,

    ENTER,
    LEAVE,
    CALL,
    PUSH,
    POP,

    /// Followed by an i32 constant
    CONST,
    /// Followed by an i32 offset from the stack register
    LOCAL,

    JUMP,

    //-------------------

    EQ,
    NE,

    LTI,
    LEI,
    GTI,
    GEI,

    LTU,
    LEU,
    GTU,
    GEU,

    EQF,
    NEF,

    LTF,
    LEF,
    GTF,
    GEF,

    //-------------------

    LOAD1,
    LOAD2,
    LOAD4,
    STORE1,
    STORE2,
    /// *(stack[top-1]) = stack[top]
    STORE4,
    ARG,

    BLOCK_COPY,

    //-------------------

    SEX8,
    SEX16,

    NEGI,
    ADD,
    SUB,
    DIVI,
    DIVU,
    MODI,
    MODU,
    MULI,
    MULU,

    BAND,
    BOR,
    BXOR,
    BCOM,

    LSH,
    RSHI,
    RSHU,

    NEGF,
    ADDF,
    SUBF,
    DIVF,
    MULF,

    CVIF,
    CVFI,

    /// Returns the size of the opcode's argument in bytes.
    /// Returns 0 if the opcode has no argument.
    /// Multi-byte arguments are encoded as little endian.
    fn argumentSize(op: Opcode) u8 {
        return switch (op) {
            .ENTER,
            .CONST,
            .LOCAL,
            .LEAVE,

            .EQ,
            .NE,
            .LTI,
            .LEI,
            .GTI,
            .GEI,
            .LTU,
            .LEU,
            .GTU,
            .GEU,
            .EQF,
            .NEF,
            .LTF,
            .LEF,
            .GTF,
            .GEF,

            .BLOCK_COPY,
            => 4,

            .ARG => 1,
            else => 0,
        };
    }
};

fn printJumpInfoComment(writer: anytype, jmp_target_instr: u32, procedure: *const Symbol) !void {
    // based off instruction count, not byte offset!
    const proc_rel_jmp_offset = jmp_target_instr - procedure.offset;
    try writer.print(" ; {s}()+0x{X} ({X:0>8})", .{ procedure.name, proc_rel_jmp_offset, jmp_target_instr });
}
