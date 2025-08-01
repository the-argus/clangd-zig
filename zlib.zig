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

const headers = &[_][]const u8{
    "zutil.h",
    "zlib.h",
    "zconf.h",
    "trees.h",
    "inftrees.h",
    "inflate.h",
    "inffixed.h",
    "inffast.h",
    "gzguts.h",
    "deflate.h",
    "crc32.h",
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

    for (headers) |header| {
        zlib.installHeader(zlib_dep.path(header), header);
    }

    return zlib;
}
