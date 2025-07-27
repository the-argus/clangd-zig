const std = @import("std");
const zlib_builder = @import("zlib.zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    // const optimize = b.standardOptimizeOption(.{});

    const clangd_malloc_trim = b.option(
        bool,
        "clangd_malloc_trim",
        "Call malloc_trim(3) periodically in clangd. (default: true)",
    ) orelse true;
    const clangd_tidy_checks = b.option(
        bool,
        "clangd_tidy_checks",
        "Link all clang-tidy checks into clangd. (default: true)",
    ) orelse true;
    const clangd_decision_forest = b.option(
        bool,
        "clangd_decision_forest",
        "Enable decision forest model for ranking code completion items. (default: true)",
    ) orelse true;
    const clangd_enable_remote = b.option(
        bool,
        "clangd_enable_remote",
        "Use gRPC library to enable remote index support for clangd. (default: false)",
    ) orelse false;
    const enable_grpc_reflection = b.option(
        bool,
        "enable_grpc_reflection",
        "Link to gRPC Reflection library. (default: off) (currently unsupported)",
    ) orelse false;
    if (enable_grpc_reflection) {
        @panic("Linking to gRPC is not currently supported by clangd-zig.");
    }

    const clangd_build_xpc_default = target.result.tag == .macos;

    const clangd_build_xpc = b.option(
        bool,
        "clangd_build_xpc",
        "Use gRPC library to enable remote index support for clangd. (default: false, unless on macos darwin)",
    ) orelse clangd_build_xpc_default;

    // no FORCE_ON option needed here as we build zlib ourselves
    const llvm_enable_zlib = b.option(
        bool,
        "llvm_enable_zlib",
        "Use zlib for compression/decompression. (default: true)",
    ) orelse true;

    const zlib: ?*std.Build.Step.Compile = null;
    if (llvm_enable_zlib) {
        const zlib_dep = b.lazyDependency("zlib", .{}).?;
        zlib = zlib_builder.build(zlib_dep);
    }

    const llvm_project = b.dependency("llvm_project", .{});
    const clang_tools_extra_path = llvm_project.path("clang-tools-extra");

    const clangd_lib = b.addLibrary(.{
        .name = "clangd",
        .linkage = .static,
    });
    clangd_lib.linkLibCpp();
    clangd_lib.addIncludePath(clang_tools_extra_path.path("include-cleaner/include"));
    // TODO: configure and install clang-tidy headers, add the build dir as include path

    const clangd_subdir = clang_tools_extra_path.path("clangd");

    clangd_lib.addConfigHeader(b.addConfigHeader(
        .{ .style = .cmake{clangd_subdir.path(b, "Features.inc.in")} },
        .{
            .CLANGD_BUILD_XPC = clangd_build_xpc,
            .CLANGD_ENABLE_REMOTE = clangd_enable_remote,
            .ENABLE_GRPC_REFLECTION = enable_grpc_reflection,
            .CLANGD_MALLOC_TRIM = clangd_malloc_trim,
            .CLANGD_TIDY_CHECKS = clangd_tidy_checks,
            .CLANGD_DECISION_FOREST = clangd_decision_forest,
        },
    ));

    clangd_lib.addCSourceFiles(.{
        .root = clangd_subdir,
        .files = @import("clangd_sources.zig").cpp_files,
        .flags = &.{},
        .language = .cpp,
    });

    // libs to build and link
    // clangAST
    // clangASTMatchers
    // clangBasic
    // clangDependencyScanning
    // clangDriver
    // clangFormat
    // clangFrontend
    // clangIndex
    // clangLex
    // clangSema
    // clangSerialization
    // clangTooling
    // clangToolingCore
    // clangToolingInclusions
    // clangToolingInclusionsStdlib
    // clangToolingSyntax
    //
    // ${LLVM_PTHREAD_LIB}
    // clangIncludeCleaner
    // clangTidy
    // clangTidyUtils
    // clangdSupport

    // TODO: link ALL_CLANG_TIDY_CHECKS libraries if (clangd_tidy_checks)

    b.installArtifact(clangd_lib); // TODO: generate executable
}
