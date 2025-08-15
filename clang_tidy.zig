const std = @import("std");

const ConfigHeader = std.Build.Step.ConfigHeader;
const Compile = std.Build.Step.Compile;
const LazyPath = std.Build.LazyPath;

pub const ClangTidyExportedArifacts = struct {
    clang_tidy_lib: *Compile,
    clang_tidy_utils_lib: *Compile,
    config_header: *ConfigHeader,

    clangd_main_include_dir: LazyPath,
    include_cleaner_main_include_dir: LazyPath,

    pub fn includeAll(llvm: *const @This(), c: *Compile) void {
        // .Target doesnt matter- no linking
        Context.linkIncludeAndConfigureExportedType(@This(), llvm, c, .Target, .LinkNone);
    }
};

const LLVMExportedArtifacts = @import("llvm_zig.zig").LLVMExportedArtifacts;
const ClangExportedArtifacts = @import("clang.zig").ClangExportedArtifacts;

const Build = @import("build.zig");
const sources = @import("clangd_sources.zig");
const tidy_sources = @import("clang_tidy_sources.zig");

const Context = Build.Context;

pub fn build(ctx: *const Context, llvm: *const LLVMExportedArtifacts, clang: *const ClangExportedArtifacts) ClangTidyExportedArifacts {
    const config_header = ctx.b.addConfigHeader(.{ .style = .{
        .cmake = ctx.srcPath("clang-tools-extra/clang-tidy/clang-tidy-config.h.cmake"),
    }, .include_path = "clang-tidy-config.h" }, .{
        .CLANG_TIDY_ENABLE_STATIC_ANALYZER = false,
    });

    const include_cleaner_main_include_dir = ctx.srcPath("clang-tools-extra/include-cleaner/include");
    const clangd_main_include_dir = ctx.srcPath("clang-tools-extra/clangd");
    const include_paths = &.{
        include_cleaner_main_include_dir,
        clangd_main_include_dir,
    };

    const clang_tidy_lib = block: {
        const lib = ctx.b.addLibrary(.{
            .name = "clangTidy",
            .root_module = ctx.makeModule(),
        });
        lib.addCSourceFiles(.{
            .root = ctx.srcPath("clang-tools-extra/clang-tidy"),
            .files = sources.clang_tidy_lib_cpp_files,
            .flags = ctx.dupeGlobalFlags(),
            .language = .cpp,
        });
        lib.linkLibCpp();
        llvm.includeAll(lib);
        clang.includeAll(lib);
        Context.linkAll(lib, &.{
            llvm.frontend_openmp_lib,
            llvm.support_lib,
            clang.ast_lib,
            clang.ast_matchers_lib,
            clang.analysis_lib,
            clang.basic_lib,
            clang.format_lib,
            clang.frontend_lib,
            clang.lex_lib,
            clang.rewrite_lib,
            clang.serialization_lib,
            clang.tooling_lib,
            clang.tooling_core_lib,
        });
        Context.configAll(lib, &.{config_header});
        Context.includeAll(lib, include_paths);
        break :block lib;
    };

    const include_cleaner_lib = block: {
        const lib = ctx.b.addLibrary(.{
            .name = "clangIncludeCleaner",
            .root_module = ctx.makeModule(),
        });
        lib.addCSourceFiles(.{
            .root = ctx.srcPath("clang-tools-extra/include-cleaner/lib"),
            .files = sources.clang_tooling_extra_include_cleaner_lib_cpp_files,
            .flags = ctx.dupeGlobalFlags(),
            .language = .cpp,
        });
        lib.linkLibCpp();
        llvm.includeAll(lib);
        clang.includeAll(lib);
        Context.linkAll(lib, &.{
            llvm.support_lib,
            clang.ast_lib,
            clang.basic_lib,
            clang.format_lib,
            clang.lex_lib,
            clang.tooling_core_lib,
            clang.tooling_inclusions_lib,
            clang.tooling_inclusions_stdlib_lib,
        });
        Context.configAll(lib, &.{config_header});
        Context.includeAll(lib, include_paths);
        break :block lib;
    };

    const clang_tidy_utils_lib = block: {
        const lib = ctx.b.addLibrary(.{
            .name = "clangTidyUtils",
            .root_module = ctx.makeModule(),
        });
        lib.addCSourceFiles(.{
            .root = ctx.srcPath("clang-tools-extra/clang-tidy/utils"),
            .files = sources.clang_tidy_utils_lib_cpp_files,
            .flags = ctx.dupeGlobalFlags(),
            .language = .cpp,
        });
        lib.linkLibCpp();
        llvm.includeAll(lib);
        clang.includeAll(lib);
        Context.linkAll(lib, &.{
            llvm.frontend_openmp_lib,
            llvm.support_lib,
            clang_tidy_lib,
            include_cleaner_lib,
            clang.ast_lib,
            clang.ast_matchers_lib,
            clang.basic_lib,
            clang.lex_lib,
            clang.sema_lib,
            clang.tooling_lib,
            clang.clang_tooling_transformer_lib,
        });
        Context.configAll(lib, &.{config_header});
        Context.includeAll(lib, include_paths);
        break :block lib;
    };

    return ClangTidyExportedArifacts{
        .clang_tidy_lib = clang_tidy_lib,
        .clang_tidy_utils_lib = clang_tidy_utils_lib,
        .config_header = config_header,
        .clangd_main_include_dir = clangd_main_include_dir,
        .include_cleaner_main_include_dir = include_cleaner_main_include_dir,
    };
}
