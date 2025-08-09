const std = @import("std");

const Build = @import("build.zig");
const Context = Build.Context;
const sources = @import("clangd_sources.zig");

/// Fills out all the fields in Context.targets that start with clang_*
/// Called from root build.zig
pub fn build(ctx: *Context) void {
    ctx.targets.clang_basic_version_config_header = ctx.b.addConfigHeader(
        ctx.paths.clang.include.clang.basic.clang_basic_version_config_header.makeOptions(),
        .{
            .CLANG_VERSION = Build.version_string,
            .CLANG_VERSION_MAJOR = @as(i64, Build.version.major),
            .CLANG_VERSION_MINOR = @as(i64, Build.version.minor),
            .CLANG_VERSION_PATCHLEVEL = @as(i64, Build.version.patch),
            // from clang/CMakeLists.txt
            .MAX_CLANG_ABI_COMPAT_VERSION = @as(i64, Build.version.major),
        },
    );

    ctx.targets.clang_host_component_support_lib = ctx.addClangLibrary(.{
        .name = "clangSupport",
        .root_module = ctx.makeHostModule(),
    });
    ctx.targets.clang_host_component_support_lib.?.addCSourceFiles(.{
        .root = ctx.paths.clang.lib.support.path,
        .files = sources.clang_support_lib_cpp_files,
        .flags = ctx.dupeGlobalFlags(),
        .language = .cpp,
    });
    // clang support also has llvm support and tablegen lib
    ctx.targets.clang_host_component_support_lib.?.linkLibrary(ctx.targets.llvm_host_component_tablegen_lib.?);

    ctx.targets.clang_host_component_tblgen_exe = ctx.addClangExecutable(.{
        .name = "clang-tblgen",
        .root_module = ctx.makeHostModule(),
    });
    ctx.targets.clang_host_component_tblgen_exe.?.addCSourceFiles(.{
        .files = sources.clang_tablegen_cpp_files,
        .root = ctx.paths.clang.utils.tablegen.path,
        .flags = ctx.dupeGlobalFlags(),
        .language = .cpp,
    });
    ctx.targets.clang_host_component_tblgen_exe.?.linkLibrary(ctx.targets.clang_host_component_support_lib.?);

    const writefile_step = ctx.b.addWriteFiles();

    // generate all the needed .inc files and copy them into the subdir
    for (ctx.clang_tablegen_files) |desc| {
        ctx.addTablegenOutputFileToWriteFileStep(writefile_step, ctx.targets.clang_host_component_tblgen_exe.?, desc);
    }
    ctx.targets.clang_tablegenerated_incs = writefile_step.getDirectory();
}
