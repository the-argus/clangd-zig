// replacement for llvm-project/clang/utils/bundle_resources.py

// original python code:
// # Usage: bundle-resources.py foo.inc a.js path/b.css ...
// # Produces foo.inc containing:
// #   const char a_js[] = "...";
// #   const char b_css[] = "...";
// import os
// import sys

// outfile = sys.argv[1]
// infiles = sys.argv[2:]

// with open(outfile, "w") as out:
//     for filename in infiles:
//         varname = os.path.basename(filename).replace(".", "_")
//         out.write("const char " + varname + "[] = \n")
//         # MSVC limits each chunk of string to 2k, so split by lines.
//         # The overall limit is 64k, which ought to be enough for anyone.
//         for line in open(filename).read().split("\n"):
//             out.write('  R"x(' + line + ')x" "\\n"\n')
//         out.write("  ;\n")

const std = @import("std");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.smp_allocator);
    var inner_arena = std.heap.ArenaAllocator.init(std.heap.smp_allocator);
    defer inner_arena.deinit();
    defer arena.deinit();
    const alloc = arena.allocator();
    const inner_allocator = inner_arena.allocator();

    var args = try std.process.argsWithAllocator(alloc);
    defer args.deinit();
    var arglist = std.ArrayList([]const u8).init(alloc);
    defer arglist.deinit();
    while (args.next()) |arg| try arglist.append(arg);

    if (arglist.items.len < 3) {
        std.log.err("expected at least three arguments: executable output_file [input_files... ]", .{});
        return;
    }

    const outfile = arglist.items[1];
    const infiles = arglist.items[2..];

    const cwd = std.fs.cwd();
    const out = try cwd.createFile(outfile, .{});
    defer out.close();
    const out_writer = out.writer();
    for (infiles) |filename| {
        defer _ = inner_arena.reset(.retain_capacity);
        const varname = try std.mem.replaceOwned(u8, inner_allocator, std.fs.path.basename(filename), ".", "_");
        try std.fmt.format(out_writer, "const char {s} [] = \n", .{varname});
        const file = try cwd.openFile(filename, .{});
        defer file.close();

        while (true) {
            const line = file.reader().readUntilDelimiterAlloc(inner_allocator, '\n', 100000) catch break;
            try std.fmt.format(out_writer, "  R\"x({s})x\" \"\\n\"\n", .{line});
        }
        try std.fmt.format(out_writer, "  ;\n", .{});
    }
}
