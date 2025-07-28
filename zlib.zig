const std = @import("std");

const srcs = &[_][]const u8{
    "adler32.c",
    "compress.c",
    "crc32.c",
    "deflate.c",
    "gzclose.c",
    "gzlib.c",
    "gzread.c",
    "gzwrite.c",
    "inflate.c",
    "infback.c",
    "inftrees.c",
    "inffast.c",
    "trees.c",
    "uncompr.c",
    "zutil.c",
};

const flags = &.{
    "-std=c89",
};

pub fn build(zlib_dep: *std.Build.Dependency, module: *std.Build.Module) *std.Build.Step.Compile {
    const zlib = zlib_dep.builder.addLibrary(.{
        .name = "z",
        .linkage = .static,
        .root_module = module,
    });

    zlib.linkLibC();
    zlib.addIncludePath(zlib_dep.path("."));

    for (srcs) |src| {
        zlib.addCSourceFile(.{
            .file = zlib_dep.path(src),
            .flags = flags,
            .language = .c,
        });
    }

    return zlib;
}
