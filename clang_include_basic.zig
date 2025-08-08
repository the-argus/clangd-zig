const std = @import("std");

const Context = @import("build.zig").Context;
const sources = @import("clangd_sources.zig");

/// Fills out all the fields in Context.targets that start with clang_*
/// Called from root build.zig
pub fn build(ctx: *Context) void {
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
