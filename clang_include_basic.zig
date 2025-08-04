const std = @import("std");

const Context = @import("build.zig").Context;
const ClangTablegenTarget = @import("build.zig").ClangTablegenTarget;
const ClangTablegenDescription = @import("build.zig").ClangTablegenDescription;
const sources = @import("clangd_sources.zig");

pub const TableGenOptions = struct {
    source_file: std.Build.LazyPath,
    output_filename: []const u8,
    args: []const []const u8 = &.{},
    // these directories will have -I prefixing them and then be passed as args
    include_dir_args: []const std.Build.LazyPath = &.{},
};

pub fn clangTablegen(
    ctx: *Context,
    options: TableGenOptions,
) std.Build.LazyPath {
    const tblgen_invocation = ctx.b.addRunArtifact(ctx.targets.llvm_tblgen_exe.?);
    tblgen_invocation.addFileArg(options.source_file);
    tblgen_invocation.addArg("-o");
    const generated_file = tblgen_invocation.addOutputFileArg(options.output_filename);
    tblgen_invocation.addArgs(options.args);
    for (options.include_dir_args) |include_dir| {
        tblgen_invocation.addPrefixedDirectoryArg("-I", include_dir);
    }
    return generated_file;
}

pub fn clangBasicAddInc(ctx: *Context, wfs: *std.Build.Step.WriteFile, desc: ClangTablegenDescription) void {
    for (desc.targets) |target| {
        const regular_keyword_attr_info_result_file = clangTablegen(ctx, .{
            .output_filename = target.output_basename,
            .args = target.flags,
            .include_dir_args = &.{ ctx.paths.clang.include.path, ctx.paths.clang.include.clang.basic.path },
            .source_file = desc.td_file,
        });
        ctx.targets.clang_tablegenerated_incs = wfs.getDirectory();
        _ = wfs.addCopyFile(
            regular_keyword_attr_info_result_file,
            "clang/Basic",
        );
    }
}

pub fn build(ctx: *Context) void {
    ctx.targets.llvm_host_component_tablegen_lib = ctx.b.addLibrary(.{
        .name = "tblgen",
        .root_module = ctx.makeHostModule(),
    });
    ctx.targets.llvm_host_component_tablegen_lib.?.addCSourceFiles(.{
        .root = ctx.paths.llvm.lib.tablegen.path,
        .files = sources.tablegen_lib_cpp_files,
        .flags = &.{},
        .language = .cpp,
    });
    ctx.targets.llvm_host_component_tablegen_lib.?.linkLibCpp();
    ctx.targets.llvm_host_component_tablegen_lib.?.addIncludePath(ctx.paths.llvm.lib.tablegen.path);
    ctx.targets.llvm_host_component_tablegen_lib.?.addIncludePath(ctx.paths.llvm.include.path);
    ctx.targets.llvm_host_component_tablegen_lib.?.addConfigHeader(ctx.targets.llvm_public_config_header.?);
    ctx.targets.llvm_host_component_tablegen_lib.?.addConfigHeader(ctx.targets.llvm_private_config_header.?);
    ctx.targets.llvm_host_component_tablegen_lib.?.addConfigHeader(ctx.targets.llvm_abi_breaking_config_header.?);
    ctx.targets.llvm_host_component_tablegen_lib.?.linkLibrary(ctx.targets.llvm_host_component_support_lib.?);

    // create tablegen executable artifact so fn clangTablegen can use it
    ctx.targets.llvm_tblgen_exe = ctx.b.addExecutable(.{
        .name = "tblgen",
        .root_module = ctx.makeHostModule(), // this exe runs on the host
    });
    ctx.targets.llvm_tblgen_exe.?.addCSourceFiles(.{
        .root = ctx.paths.clang.utils.tablegen.path,
        .files = sources.tablegen_cpp_files,
        .flags = &.{},
        .language = .cpp,
    });
    ctx.targets.llvm_tblgen_exe.?.linkLibCpp();
    ctx.targets.llvm_tblgen_exe.?.addIncludePath(ctx.paths.llvm.include.path);
    ctx.targets.llvm_tblgen_exe.?.addIncludePath(ctx.paths.clang.include.path);
    ctx.targets.llvm_tblgen_exe.?.addConfigHeader(ctx.targets.llvm_public_config_header.?);
    ctx.targets.llvm_tblgen_exe.?.addConfigHeader(ctx.targets.llvm_abi_breaking_config_header.?);
    ctx.targets.llvm_tblgen_exe.?.linkLibrary(ctx.targets.llvm_host_component_support_lib.?);
    ctx.targets.llvm_tblgen_exe.?.linkLibrary(ctx.targets.llvm_host_component_demangle_lib.?);
    ctx.targets.llvm_tblgen_exe.?.linkLibrary(ctx.targets.llvm_host_component_tablegen_lib.?);
    ctx.targets.llvm_tblgen_exe.?.linkLibrary(ctx.targets.clang_host_component_support_lib.?);

    const writefile_step = ctx.b.addWriteFiles();

    // generate all the needed .inc files and copy them into the subdir
    clangBasicAddInc(ctx, writefile_step, ctx.paths.clang.include.clang.basic.attr_td);
    clangBasicAddInc(ctx, writefile_step, ctx.paths.clang.include.clang.basic.declnodes_td);
    clangBasicAddInc(ctx, writefile_step, ctx.paths.clang.include.clang.basic.diagnostic_td);

    ctx.targets.clang_tablegenerated_incs = writefile_step.getDirectory();
}
