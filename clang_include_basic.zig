const std = @import("std");

const Context = @import("build.zig").Context;
const sources = @import("clangd_sources.zig");

const RunArtifactResultFile = @import("build.zig").RunArtifactResultFile;

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
) RunArtifactResultFile {
    const tblgen_invocation = ctx.b.addRunArtifact(ctx.targets.llvm_tblgen_exe.?);
    tblgen_invocation.addFileArg(options.source_file);
    tblgen_invocation.addArg("-o");
    const generated_file = tblgen_invocation.addOutputFileArg(options.output_filename);
    tblgen_invocation.addArgs(options.args);
    for (options.include_dir_args) |include_dir| {
        tblgen_invocation.addPrefixedDirectoryArg("-I", include_dir);
    }
    return RunArtifactResultFile{
        .outputted_file = generated_file,
        .step = &tblgen_invocation.step,
    };
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

    // generate RegularKeywordAttrInfo.inc
    const regular_keyword_attr_info_result_file = @import("clang_include_basic.zig").clangTablegen(ctx, .{
        .output_filename = "RegularKeywordAttrInfo.inc",
        .args = &.{"-gen-clang-regular-keyword-attr-info"},
        .include_dir_args = &.{ctx.paths.clang.include.path},
        .source_file = ctx.paths.clang.include.clang.basic.attr_td,
    });
    // put RegularKeywordAttrInfo.inc into clang/Basic
    const regular_keyword_attr_info_with_subdir = ctx.b.addWriteFiles();
    ctx.targets.llvm_regular_keyword_attr_info_inc = .{
        .step = &regular_keyword_attr_info_with_subdir.step,
        .outputted_file = regular_keyword_attr_info_with_subdir.addCopyFile(
            regular_keyword_attr_info_result_file.outputted_file,
            "clang/Basic/RegularKeywordAttrInfo.inc",
        ),
    };

    ctx.targets.llvm_regular_keyword_attr_info_inc = regular_keyword_attr_info_result_file;
}
