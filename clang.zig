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

    {
        ctx.targets.clang_basic_lib = ctx.addClangLibrary(.{
            .name = "clangBasic",
            .root_module = ctx.makeModule(),
        });
        ctx.targets.clang_basic_lib.?.addCSourceFiles(.{
            .root = ctx.paths.clang.lib.basic.path,
            .files = sources.clang_basic_lib_cpp_files,
            .flags = ctx.dupeGlobalFlags(),
            .language = .cpp,
        });
        ctx.targets.clang_basic_lib.?.addIncludePath(ctx.targets.clang_tablegenerated_incs.?);
        ctx.targets.clang_basic_lib.?.addIncludePath(ctx.targets.llvm_tablegenerated_incs.?);
    }

    {
        ctx.targets.clang_lex_lib = ctx.addClangLibrary(.{
            .name = "clangLex",
            .root_module = ctx.makeModule(),
        });
        ctx.targets.clang_lex_lib.?.addCSourceFiles(.{
            .root = ctx.paths.clang.lib.lex.path,
            .files = sources.clang_lex_lib_cpp_files,
            .flags = ctx.dupeGlobalFlags(),
            .language = .cpp,
        });
        ctx.targets.clang_lex_lib.?.addIncludePath(ctx.targets.clang_tablegenerated_incs.?);
        ctx.targets.clang_lex_lib.?.addIncludePath(ctx.targets.llvm_tablegenerated_incs.?);
        ctx.targets.clang_lex_lib.?.linkLibrary(ctx.targets.clang_basic_lib.?);
    }

    {
        ctx.targets.clang_ast_lib = ctx.addClangLibrary(.{
            .name = "clangAST",
            .root_module = ctx.makeModule(),
        });
        ctx.targets.clang_ast_lib.?.addCSourceFiles(.{
            .root = ctx.paths.clang.lib.ast.path,
            .files = sources.clang_ast_lib_cpp_files,
            .flags = ctx.dupeGlobalFlags(),
            .language = .cpp,
        });
        ctx.targets.clang_ast_lib.?.addIncludePath(ctx.targets.clang_tablegenerated_incs.?);
        ctx.targets.clang_ast_lib.?.linkLibrary(ctx.targets.clang_basic_lib.?);
        ctx.targets.clang_ast_lib.?.linkLibrary(ctx.targets.clang_lex_lib.?);
    }

    {
        ctx.targets.clang_ast_matchers_lib = ctx.addClangLibrary(.{
            .name = "clangASTMatchers",
            .root_module = ctx.makeModule(),
        });
        ctx.targets.clang_ast_matchers_lib.?.addCSourceFiles(.{
            .root = ctx.paths.clang.lib.ast.path,
            .files = sources.clang_ast_matchers_lib_cpp_files,
            .flags = ctx.dupeGlobalFlags(),
            .language = .cpp,
        });
        ctx.targets.clang_ast_matchers_lib.?.addIncludePath(ctx.targets.clang_tablegenerated_incs.?);
        ctx.targets.clang_ast_matchers_lib.?.addIncludePath(ctx.targets.llvm_tablegenerated_incs.?);
        ctx.targets.clang_ast_matchers_lib.?.linkLibrary(ctx.targets.clang_ast_lib.?);
        ctx.targets.clang_ast_matchers_lib.?.linkLibrary(ctx.targets.clang_basic_lib.?);
        ctx.targets.clang_ast_matchers_lib.?.linkLibrary(ctx.targets.clang_lex_lib.?);
    }

    {
        ctx.targets.clang_driver_lib = ctx.addClangLibrary(.{
            .name = "clangDriver",
            .root_module = ctx.makeModule(),
        });
        ctx.targets.clang_driver_lib.?.addCSourceFiles(.{
            .root = ctx.paths.clang.lib.driver.path,
            .files = sources.clang_driver_lib_cpp_files,
            .flags = ctx.dupeGlobalFlags(),
            .language = .cpp,
        });
        ctx.targets.clang_driver_lib.?.addIncludePath(ctx.targets.clang_tablegenerated_incs.?);
        ctx.targets.clang_driver_lib.?.addIncludePath(ctx.targets.llvm_tablegenerated_incs.?);
        ctx.targets.clang_driver_lib.?.linkLibrary(ctx.targets.clang_basic_lib.?);
    }

    {
        ctx.targets.clang_rewrite_lib = ctx.addClangLibrary(.{
            .name = "clangRewrite",
            .root_module = ctx.makeModule(),
        });
        ctx.targets.clang_rewrite_lib.?.addCSourceFiles(.{
            .root = ctx.paths.clang.lib.rewrite.path,
            .files = sources.clang_rewrite_lib_cpp_files,
            .flags = ctx.dupeGlobalFlags(),
            .language = .cpp,
        });
        ctx.targets.clang_rewrite_lib.?.addIncludePath(ctx.targets.clang_tablegenerated_incs.?);
        ctx.targets.clang_rewrite_lib.?.addIncludePath(ctx.targets.llvm_tablegenerated_incs.?);
        ctx.targets.clang_rewrite_lib.?.linkLibrary(ctx.targets.clang_basic_lib.?);
        ctx.targets.clang_rewrite_lib.?.linkLibrary(ctx.targets.clang_lex_lib.?);
    }

    {
        ctx.targets.clang_tooling_core_lib = ctx.addClangLibrary(.{
            .name = "clangToolingCore",
            .root_module = ctx.makeModule(),
        });
        ctx.targets.clang_tooling_core_lib.?.addCSourceFiles(.{
            .root = ctx.paths.clang.lib.tooling.core.path,
            .files = sources.clang_tooling_core_lib_cpp_files,
            .flags = ctx.dupeGlobalFlags(),
            .language = .cpp,
        });
        ctx.targets.clang_tooling_core_lib.?.addIncludePath(ctx.targets.clang_tablegenerated_incs.?);
        ctx.targets.clang_tooling_core_lib.?.addIncludePath(ctx.targets.llvm_tablegenerated_incs.?);
        ctx.targets.clang_tooling_core_lib.?.linkLibrary(ctx.targets.clang_basic_lib.?);
        ctx.targets.clang_tooling_core_lib.?.linkLibrary(ctx.targets.clang_lex_lib.?);
        ctx.targets.clang_tooling_core_lib.?.linkLibrary(ctx.targets.clang_rewrite_lib.?);
    }

    {
        ctx.targets.clang_tooling_inclusions_lib = ctx.addClangLibrary(.{
            .name = "clangToolingInclusions",
            .root_module = ctx.makeModule(),
        });
        ctx.targets.clang_tooling_inclusions_lib.?.addCSourceFiles(.{
            .root = ctx.paths.clang.lib.tooling.inclusions.path,
            .files = sources.clang_tooling_inclusions_lib_cpp_files,
            .flags = ctx.dupeGlobalFlags(),
            .language = .cpp,
        });
        ctx.targets.clang_tooling_inclusions_lib.?.addIncludePath(ctx.targets.clang_tablegenerated_incs.?);
        ctx.targets.clang_tooling_inclusions_lib.?.addIncludePath(ctx.targets.llvm_tablegenerated_incs.?);
        ctx.targets.clang_tooling_inclusions_lib.?.linkLibrary(ctx.targets.clang_basic_lib.?);
        ctx.targets.clang_tooling_inclusions_lib.?.linkLibrary(ctx.targets.clang_lex_lib.?);
        ctx.targets.clang_tooling_inclusions_lib.?.linkLibrary(ctx.targets.clang_tooling_core_lib.?);
    }

    {
        ctx.targets.clang_format_lib = ctx.addClangLibrary(.{
            .name = "clangFormat",
            .root_module = ctx.makeModule(),
        });
        ctx.targets.clang_format_lib.?.addCSourceFiles(.{
            .root = ctx.paths.clang.lib.format.path,
            .files = sources.clang_format_lib_cpp_files,
            .flags = ctx.dupeGlobalFlags(),
            .language = .cpp,
        });
        ctx.targets.clang_format_lib.?.addIncludePath(ctx.targets.clang_tablegenerated_incs.?);
        ctx.targets.clang_format_lib.?.addIncludePath(ctx.targets.llvm_tablegenerated_incs.?);
        ctx.targets.clang_format_lib.?.linkLibrary(ctx.targets.clang_basic_lib.?);
        ctx.targets.clang_format_lib.?.linkLibrary(ctx.targets.clang_lex_lib.?);
        ctx.targets.clang_format_lib.?.linkLibrary(ctx.targets.clang_tooling_core_lib.?);
        ctx.targets.clang_format_lib.?.linkLibrary(ctx.targets.clang_tooling_inclusions_lib.?);
    }
}
