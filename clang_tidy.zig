const std = @import("std");

const ConfigHeader = std.Build.Step.ConfigHeader;
const Compile = std.Build.Step.Compile;
const LazyPath = std.Build.LazyPath;

pub const ClangTidyExportedArifacts = struct {
    clang_tidy_lib: *Compile,
    clang_tidy_utils_lib: *Compile,
    config_header: *ConfigHeader,

    clang_tidy_checks: []*Compile,

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

    // confusable gen header for misc_module
    const confusable_table_gen = ctx.b.addExecutable(.{
        .name = "clang-tidy-confusable-chars-gen",
        .root_module = ctx.makeHostModule(),
    });
    confusable_table_gen.linkLibCpp();
    confusable_table_gen.linkLibrary(llvm.host_component_support_lib);
    llvm.includeAll(confusable_table_gen);
    confusable_table_gen.addCSourceFiles(.{
        .root = ctx.srcPath("clang-tools-extra/clang-tidy/misc/ConfusableTable"),
        .files = &.{"BuildConfusableTable.cpp"},
        .flags = ctx.dupeGlobalFlags(),
        .language = .cpp,
    });

    const run_confusable_tablegen = ctx.b.addRunArtifact(confusable_table_gen);
    run_confusable_tablegen.addFileArg(ctx.srcPath("clang-tools-extra/clang-tidy/misc/ConfusableTable/confusables.txt"));
    const confusables_inc = run_confusable_tablegen.addOutputFileArg("Confusables.inc");

    // enough libraries for every module
    const module_libs = &.{
        llvm.frontend_openmp_lib,
        llvm.support_lib,
        llvm.target_parser_lib,
        clang.analysis_lib,
        clang.ast_lib,
        clang.ast_matchers_lib,
        clang.format_lib,
        clang.basic_lib,
        clang.lex_lib,
        clang.serialization_lib,
        clang.tooling_lib,
        clang.tooling_inclusions_lib,
        clang.tooling_inclusions_stdlib_lib,
        // from bugprone module:
        // TODO: clangAnalysisFlowSensitive
        // TODO: clangAnalysisFlowSensitiveModels
        clang.clang_tooling_transformer_lib,
        include_cleaner_lib,
        clang_tidy_lib,
        clang_tidy_utils_lib,
    };

    const fields = @typeInfo(tidy_sources).@"struct".fields;
    var modules = std.ArrayList(*Compile).initCapacity(ctx.b.allocator, fields.len) catch @panic("OOM");
    var modules_named = std.StringArrayHashMap(*Compile).init(ctx.b.allocator);
    modules_named.ensureTotalCapacity(fields.len) catch @panic("OOM");

    inline for (fields) |field| {
        const suffix = "_module";
        std.debug.assert(std.mem.endsWith(u8, field.name, suffix));

        const skip_if_static_analyzer_disabled = std.mem.eql(u8, field.name, "mpi_module");

        if (!(skip_if_static_analyzer_disabled and !ctx.opts.clang_enable_static_analyzer)) {
            const sources_list = field.defaultValue().?;

            const name_without_module = field.name[0..(field.name.len - suffix.len)];

            const lib = ctx.b.addLibrary(.{
                .name = "clangTidyModule_" ++ name_without_module,
                .root_module = ctx.makeModule(),
            });

            lib.addCSourceFiles(.{
                .root = ctx.srcPath("clang-tools-extra/clang-tidy/" ++ name_without_module),
                .files = sources_list,
                .flags = ctx.dupeGlobalFlags(),
                .language = .cpp,
            });
            lib.linkLibCpp();
            llvm.includeAll(lib);
            clang.includeAll(lib);
            Context.linkAll(lib, module_libs);
            Context.includeAll(lib, include_paths);
            lib.addIncludePath(confusables_inc);
            modules.append(lib) catch @panic("OOM");
            modules_named.put(field.name, lib) catch @panic("hashmap put() failure");
        }
    }

    // inter-module deps
    modules_named.get("modernize_module").?.linkLibrary(modules_named.get("readability_module").?);
    modules_named.get("llvmlibc_module").?.linkLibrary(modules_named.get("portability_module").?);
    modules_named.get("llvm_module").?.linkLibrary(modules_named.get("readability_module").?);
    modules_named.get("google_module").?.linkLibrary(modules_named.get("readability_module").?);
    modules_named.get("fuchsia_module").?.linkLibrary(modules_named.get("google_module").?);
    Context.linkAll(modules_named.get("hicpp_module").?, &.{
        modules_named.get("bugprone_module").?,
        modules_named.get("cppcoreguidelines_module").?,
        modules_named.get("google_module").?,
        modules_named.get("misc_module").?,
        modules_named.get("modernize_module").?,
        modules_named.get("performance_module").?,
        modules_named.get("readability_module").?,
    });
    Context.linkAll(modules_named.get("cppcoreguidelines_module").?, &.{
        modules_named.get("bugprone_module").?,
        modules_named.get("misc_module").?,
        modules_named.get("modernize_module").?,
        modules_named.get("performance_module").?,
        modules_named.get("readability_module").?,
    });
    Context.linkAll(modules_named.get("cert_module").?, &.{
        modules_named.get("bugprone_module").?,
        modules_named.get("concurrency_module").?,
        modules_named.get("google_module").?,
        modules_named.get("misc_module").?,
        modules_named.get("performance_module").?,
        modules_named.get("readability_module").?,
    });

    return ClangTidyExportedArifacts{
        .clang_tidy_lib = clang_tidy_lib,
        .clang_tidy_utils_lib = clang_tidy_utils_lib,
        .config_header = config_header,
        .clangd_main_include_dir = clangd_main_include_dir,
        .include_cleaner_main_include_dir = include_cleaner_main_include_dir,
        .clang_tidy_checks = modules.toOwnedSlice() catch @panic("OOM"),
    };
}
