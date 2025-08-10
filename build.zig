const std = @import("std");
const builtin = @import("builtin");
const zlib_builder = @import("zlib.zig");

const sources = @import("clangd_sources.zig");
const Compile = std.Build.Step.Compile;
const LazyPath = std.Build.LazyPath;
const tblgen_descriptions = @import("tblgen_descriptions.zig");
const ClangTablegenDescription = tblgen_descriptions.ClangTablegenDescription;
pub const version = std.SemanticVersion{ .major = 20, .minor = 1, .patch = 8 };
pub const version_string = "20.1.8";
pub const bug_report_url = "https://github.com/llvm/llvm-project/issues/";

pub const Options = struct {
    // NOTE: if a field of this struct has a default value, thats because it
    // is not exposed via build options, and just uses that constant default
    // value
    enable_grpc_reflection: bool,

    // options for llvm subdir
    llvm_enable_zlib: bool,
    llvm_enable_dump: bool,
    llvm_default_target_triple: []const u8,
    llvm_enable_threads: bool,
    llvm_unreachable_optimize: bool,
    llvm_reverse_iteration: bool,
    llvm_abi_breaking_checks: ABIBreakingChecks,

    // clangd specific options
    clangd_malloc_trim: bool,
    clangd_tidy_checks: bool,
    clangd_decision_forest: bool,
    clangd_enable_remote: bool,
    clangd_build_xpc: bool,

    clang_enable_libxml2: bool = false,
    // llvm_enable_libxml2: bool = false,
    // llvm_install_toolchain_only: bool = false,
    // llvm_force_use_old_toolchain: bool = false,
    // clang_enable_bootstrap: bool = false,
    clang_default_pie_on_linux: bool = true,
    clang_systemz_default_arch: []const u8 = "z10",
    clang_default_openmp_runtime: []const u8 = "libomp",
    clang_default_objcopy: []const u8 = "objcopy",
    clang_default_unwindlib: []const u8 = "none", // or "libgcc" or "libunwind"
    clang_default_rtlib: []const u8 = "platform", // or "libgcc" or "compiler-rt"
    clang_default_cxx_stdlib: []const u8 = "libc++",
    clang_default_linker: []const u8 = "lld",
    clang_resource_dir: []const u8 = "",
    clang_c_include_dirs: []const u8 = "",
    default_sysroot: []const u8 = "",
    gcc_install_prefix: []const u8 = "",
    host_link_version: usize = 0,
    enable_linker_build_id: bool = false,
    enable_x86_relax_relocations: bool = true,
    ppc_linux_default_ieeelongdouble: bool = false,
    clang_enable_arcmt: bool = false, // true in original cmake
    clang_enable_static_analyzer: bool = false, // true in original cmake
    clang_spawn_cc1: bool = false,
    clang_enable_cir: bool = false,
    // clang_build_tools: bool = true,
    // clang_enable_arcmt: bool = false, // default is true in llvm project
    // clang_enable_static_analyzer: bool = true,
    // clang_enable_proto_fuzzer: bool = false,
    // clang_force_matching_libclang_soversion: bool = true,
    // clang_include_tests: bool = false,
    // clang_enable_hlsl: bool = false,
    // clang_build_examples: bool = false,
    // clang_include_docs: bool = false,

    supported_targets: LLVMSupportedTargets,
};

pub const ConfigHeader = struct {
    output_include_path: []const u8,
    unconfigured_header_path: LazyPath,

    const CHOptions = std.Build.Step.ConfigHeader.Options;

    pub fn makeOptions(self: *const @This()) CHOptions {
        return CHOptions{
            .style = .{ .cmake = self.unconfigured_header_path },
            .include_path = self.output_include_path,
        };
    }
};

pub const ABIBreakingChecks = enum {
    WITH_ASSERTS,
    FORCE_ON,
    FORCE_OFF,

    pub const desc = "Used to decide if LLVM should be built with ABI " ++
        "breaking checks or not.  Allowed values are `WITH_ASSERTS` " ++
        "(default), `FORCE_ON` and `FORCE_OFF`.  `WITH_ASSERTS` turns " ++
        "on ABI breaking checks in an assertion enabled build.  " ++
        "`FORCE_ON` (`FORCE_OFF`) turns them on (off) irrespective of " ++
        "whether normal (`NDEBUG`-based) assertions are enabled or not.  " ++
        "A version of LLVM built with ABI breaking checks is not ABI " ++
        "compatible with a version built without it.";

    pub fn default() @This() {
        return .WITH_ASSERTS;
    }
};

pub const TableGenOptions = struct {
    source_file: std.Build.LazyPath,
    output_filename: []const u8,
    args: []const []const u8 = &.{},
    // these directories will have -I prefixing them and then be passed as args
    include_dir_args: []const std.Build.LazyPath = &.{},
};

pub const Paths = struct {
    root: LazyPath,
    // subdirs in the root directory
    clang_tools_extra: struct {
        path: LazyPath,

        // subdirs in the clang_tools_extra directory
        clangd: struct {
            path: LazyPath,
            tool: struct { path: LazyPath },
        },

        clang_tidy: struct {
            clang_tidy_config_config_header: ConfigHeader,
        },

        include_cleaner: struct {
            include: struct {
                path: LazyPath,
            },
        },
    },

    clang: struct {
        include: struct {
            path: LazyPath,
            clang: struct {
                config: struct {
                    config_config_header: ConfigHeader,
                },
                basic: struct {
                    path: LazyPath,
                    clang_basic_version_config_header: ConfigHeader,
                },
            },
        },
        lib: struct {
            support: struct {
                path: LazyPath,
            },
            ast: struct {
                path: LazyPath,
            },
            ast_matchers: struct {
                path: LazyPath,
            },
            basic: struct {
                path: LazyPath,
            },
            driver: struct {
                path: LazyPath,
            },
            format: struct {
                path: LazyPath,
            },
            frontend: struct {
                path: LazyPath,
            },
            index: struct {
                path: LazyPath,
            },
            rewrite: struct {
                path: LazyPath,
            },
            lex: struct {
                path: LazyPath,
            },
            sema: struct {
                path: LazyPath,
            },
            serialization: struct {
                path: LazyPath,
            },
            tooling: struct {
                path: LazyPath,
                dependency_scanning: struct {
                    path: LazyPath,
                },
                inclusions: struct {
                    path: LazyPath,
                    stdlib: struct {
                        path: LazyPath,
                    },
                },
                syntax: struct {
                    path: LazyPath,
                },
                core: struct {
                    path: LazyPath,
                },
            },
        },
        utils: struct {
            tablegen: struct {
                path: LazyPath,
            },
        },
    },

    llvm: struct {
        include: struct {
            path: LazyPath,
            llvm: struct {
                config: struct {
                    llvm_private_config_header: ConfigHeader,
                    llvm_public_config_header: ConfigHeader,
                    llvm_abi_breaking_config_header: ConfigHeader,
                    llvm_targets_def_config_header: ConfigHeader,
                    llvm_asm_printers_def_config_header: ConfigHeader,
                    llvm_asm_parsers_def_config_header: ConfigHeader,
                    llvm_disassemblers_def_config_header: ConfigHeader,
                    llvm_target_exegesis_def_config_header: ConfigHeader,
                    llvm_target_mcas_def_config_header: ConfigHeader,
                },
                frontend: struct {
                    path: LazyPath,
                    openmp: struct {
                        path: LazyPath,
                    },
                },
                support: struct {
                    path: LazyPath,
                },
                tablegen: struct {
                    path: LazyPath,
                },
                adt: struct {
                    path: LazyPath,
                },
            },
        },

        lib: struct {
            path: LazyPath,
            target: struct {
                path: LazyPath,
            },
            demangle: struct {
                path: LazyPath,
            },
            tablegen: struct {
                path: LazyPath,
            },
            support: struct {
                path: LazyPath,

                unix: struct {
                    path: LazyPath,
                },
                windows: struct {
                    path: LazyPath,
                },
            },
        },
        utils: struct {
            path: LazyPath,
            tablegen: struct {
                path: LazyPath,
                basic: struct {
                    path: LazyPath,
                },
                common: struct {
                    path: LazyPath,
                    globalisel: struct {
                        path: LazyPath,
                    },
                },
            },
        },
    },

    pub fn new(b: *std.Build, root: LazyPath) *const Paths {
        const out = b.allocator.create(Paths) catch @panic("OOM");
        const cte = "clang-tools-extra/";

        out.* = Paths{
            .root = root,
            .clang_tools_extra = .{
                .path = root.path(b, cte),
                .clangd = .{
                    .path = root.path(b, cte ++ "clangd"),
                    .tool = .{
                        .path = root.path(b, cte ++ "clangd/tool"),
                    },
                },
                .include_cleaner = .{
                    .include = .{
                        .path = root.path(b, cte ++ "include-cleaner/include"),
                    },
                },
                .clang_tidy = .{
                    .clang_tidy_config_config_header = ConfigHeader{
                        .output_include_path = "clang-tidy-config.h",
                        .unconfigured_header_path = root.path(
                            b,
                            cte ++ "clang-tidy/clang-tidy-config.h.cmake",
                        ),
                    },
                },
            },
            .clang = .{
                .include = .{
                    .path = root.path(b, "clang/include"),
                    .clang = .{
                        .config = .{
                            .config_config_header = ConfigHeader{
                                .output_include_path = "clang/Config/config.h",
                                .unconfigured_header_path = root.path(b, "clang/include/clang/Config/config.h.cmake"),
                            },
                        },
                        .basic = .{
                            .path = root.path(b, "clang/include/clang/Basic"),
                            .clang_basic_version_config_header = ConfigHeader{
                                .output_include_path = "clang/Basic/Version.inc",
                                .unconfigured_header_path = root.path(b, "clang/include/clang/Basic/Version.inc.in"),
                            },
                        },
                    },
                },
                .lib = .{
                    .support = .{
                        .path = root.path(b, "clang/lib/Support"),
                    },
                    .ast = .{
                        .path = root.path(b, "clang/lib/AST"),
                    },
                    .ast_matchers = .{
                        .path = root.path(b, "clang/lib/ASTMatchers"),
                    },
                    .basic = .{
                        .path = root.path(b, "clang/lib/Basic"),
                    },
                    .driver = .{
                        .path = root.path(b, "clang/lib/Driver"),
                    },
                    .format = .{
                        .path = root.path(b, "clang/lib/Format"),
                    },
                    .frontend = .{
                        .path = root.path(b, "clang/lib/Frontend"),
                    },
                    .index = .{
                        .path = root.path(b, "clang/lib/Index"),
                    },
                    .rewrite = .{
                        .path = root.path(b, "clang/lib/Rewrite"),
                    },
                    .lex = .{
                        .path = root.path(b, "clang/lib/Lex"),
                    },
                    .sema = .{
                        .path = root.path(b, "clang/lib/Sema"),
                    },
                    .serialization = .{
                        .path = root.path(b, "clang/lib/Serialization"),
                    },
                    .tooling = .{
                        .path = root.path(b, "clang/lib/Tooling"),
                        .dependency_scanning = .{
                            .path = root.path(b, "clang/lib/Tooling/DependencyScanning"),
                        },
                        .inclusions = .{
                            .path = root.path(b, "clang/lib/Tooling/Inclusions"),
                            .stdlib = .{
                                .path = root.path(b, "clang/lib/Tooling/Inclusions/Stdlib"),
                            },
                        },
                        .syntax = .{
                            .path = root.path(b, "clang/lib/Tooling/Syntax"),
                        },
                        .core = .{
                            .path = root.path(b, "clang/lib/Tooling/Core"),
                        },
                    },
                },
                .utils = .{
                    .tablegen = .{
                        .path = root.path(b, "clang/utils/TableGen"),
                    },
                },
            },
            .llvm = .{
                .include = .{
                    .path = root.path(b, "llvm/include"),
                    .llvm = .{
                        .config = .{
                            .llvm_public_config_header = ConfigHeader{
                                .unconfigured_header_path = root.path(b, "llvm/include/llvm/Config/llvm-config.h.cmake"),
                                .output_include_path = "llvm/Config/llvm-config.h",
                            },
                            .llvm_private_config_header = ConfigHeader{
                                .unconfigured_header_path = root.path(b, "llvm/include/llvm/Config/config.h.cmake"),
                                .output_include_path = "llvm/Config/config.h",
                            },
                            .llvm_abi_breaking_config_header = ConfigHeader{
                                .unconfigured_header_path = root.path(b, "llvm/include/llvm/Config/abi-breaking.h.cmake"),
                                .output_include_path = "llvm/Config/abi-breaking.h",
                            },
                            .llvm_targets_def_config_header = ConfigHeader{
                                .unconfigured_header_path = root.path(b, "llvm/include/llvm/Config/Targets.def.in"),
                                .output_include_path = "llvm/Config/Targets.def",
                            },
                            .llvm_asm_printers_def_config_header = ConfigHeader{
                                .unconfigured_header_path = root.path(b, "llvm/include/llvm/Config/AsmPrinters.def.in"),
                                .output_include_path = "llvm/Config/AsmPrinters.def",
                            },
                            .llvm_asm_parsers_def_config_header = ConfigHeader{
                                .unconfigured_header_path = root.path(b, "llvm/include/llvm/Config/AsmParsers.def.in"),
                                .output_include_path = "llvm/Config/AsmParsers.def",
                            },
                            .llvm_disassemblers_def_config_header = ConfigHeader{
                                .unconfigured_header_path = root.path(b, "llvm/include/llvm/Config/Disassemblers.def.in"),
                                .output_include_path = "llvm/Config/Disassemblers.def",
                            },
                            .llvm_target_exegesis_def_config_header = ConfigHeader{
                                .unconfigured_header_path = root.path(b, "llvm/include/llvm/Config/TargetExegesis.def.in"),
                                .output_include_path = "llvm/Config/TargetExegesis.def",
                            },
                            .llvm_target_mcas_def_config_header = ConfigHeader{
                                .unconfigured_header_path = root.path(b, "llvm/include/llvm/Config/TargetMCAs.def.in"),
                                .output_include_path = "llvm/Config/TargetMCAs.def",
                            },
                        },
                        .frontend = .{
                            .path = root.path(b, "llvm/include/llvm/Frontend"),
                            .openmp = .{
                                .path = root.path(b, "llvm/include/llvm/Frontend/OpenMP"),
                            },
                        },
                        .support = .{
                            .path = root.path(b, "llvm/include/llvm/Support"),
                        },
                        .tablegen = .{
                            .path = root.path(b, "llvm/include/llvm/TableGen"),
                        },
                        .adt = .{
                            .path = root.path(b, "llvm/include/llvm/ADT"),
                        },
                    },
                },
                .lib = .{
                    .path = root.path(b, "llvm/lib"),
                    .target = .{
                        .path = root.path(b, "llvm/lib/Target"),
                    },
                    .demangle = .{
                        .path = root.path(b, "llvm/lib/Demangle"),
                    },
                    .tablegen = .{
                        .path = root.path(b, "llvm/lib/TableGen"),
                    },
                    .support = .{
                        .path = root.path(b, "llvm/lib/Support"),
                        .unix = .{
                            .path = root.path(b, "llvm/lib/Support/Unix"),
                        },
                        .windows = .{
                            .path = root.path(b, "llvm/lib/Support/Windows"),
                        },
                    },
                },
                .utils = .{
                    .path = root.path(b, "llvm/utils"),
                    .tablegen = .{
                        .path = root.path(b, "llvm/utils/TableGen"),
                        .basic = .{
                            .path = root.path(b, "llvm/utils/TableGen/Basic"),
                        },
                        .common = .{
                            .path = root.path(b, "llvm/utils/TableGen/Common"),
                            .globalisel = .{
                                .path = root.path(b, "llvm/utils/TableGen/Common/GlobalISel"),
                            },
                        },
                    },
                },
            },
        };

        return out;
    }
};

pub const Targets = struct {
    zlib: ?*Compile = null,
    clangd_lib: ?*Compile = null,
    clangd_main_lib: ?*Compile = null,
    clangd_exe: ?*Compile = null,

    // llvm/include/llvm/Config/llvm-config.h.cmake
    llvm_public_config_header: ?*std.Build.Step.ConfigHeader = null,
    // llvm/include/llvm/Config/config.h.cmake
    llvm_private_config_header: ?*std.Build.Step.ConfigHeader = null,
    // llvm/include/llvm/Config/abi-breaking.h.cmake
    llvm_abi_breaking_config_header: ?*std.Build.Step.ConfigHeader = null,
    llvm_features_inc_config_header: ?*std.Build.Step.ConfigHeader = null,
    llvm_targets_def_config_header: ?*std.Build.Step.ConfigHeader = null,
    llvm_asm_parsers_def_config_header: ?*std.Build.Step.ConfigHeader = null,
    llvm_asm_printers_def_config_header: ?*std.Build.Step.ConfigHeader = null,
    llvm_disassemblers_def_config_header: ?*std.Build.Step.ConfigHeader = null,
    llvm_target_exegesis_def_config_header: ?*std.Build.Step.ConfigHeader = null,
    llvm_target_mcas_def_config_header: ?*std.Build.Step.ConfigHeader = null,

    llvm_host_component_demangle_lib: ?*Compile = null,
    llvm_host_component_support_lib: ?*Compile = null,
    llvm_host_component_tablegen_lib: ?*Compile = null,
    llvm_host_component_tblgen_basic_lib: ?*Compile = null,
    llvm_host_component_tblgen_common_lib: ?*Compile = null,
    llvm_host_component_tblgen_exe: ?*Compile = null,
    llvm_host_component_tblgen_min_exe: ?*Compile = null, // for bootstrapping

    clang_host_component_tblgen_exe: ?*Compile = null,
    clang_host_component_support_lib: ?*Compile = null,
    clang_ast_lib: ?*Compile = null,
    clang_ast_matchers_lib: ?*Compile = null,
    clang_basic_lib: ?*Compile = null,
    clang_driver_lib: ?*Compile = null,
    clang_format_lib: ?*Compile = null,
    clang_frontend_lib: ?*Compile = null,
    clang_index_lib: ?*Compile = null,
    clang_lex_lib: ?*Compile = null,
    clang_sema_lib: ?*Compile = null,
    clang_serialization_lib: ?*Compile = null,
    clang_tooling_lib: ?*Compile = null,
    clang_tooling_core_lib: ?*Compile = null,
    clang_tooling_syntax_lib: ?*Compile = null,
    clang_tooling_inclusions_lib: ?*Compile = null,
    clang_tooling_inclusions_stdlib_lib: ?*Compile = null,
    clang_tooling_dependency_scanning_lib: ?*Compile = null,
    clang_rewrite_lib: ?*Compile = null,
    clang_basic_version_config_header: ?*std.Build.Step.ConfigHeader = null,
    clang_version_inc: ?LazyPath = null,
    clang_config_config_header: ?*std.Build.Step.ConfigHeader = null,

    clang_tablegenerated_incs: ?LazyPath = null,
    llvm_tablegenerated_incs: ?LazyPath = null,

    // cte short for clang_tools_extra
    cte_clang_tidy_config_config_header: ?*std.Build.Step.ConfigHeader = null,
};

pub const Context = struct {
    b: *std.Build,
    module_opts: std.Build.Module.CreateOptions,
    targets: Targets,
    paths: *const Paths,
    opts: *const Options,
    clang_tablegen_files: []const ClangTablegenDescription,
    llvm_tablegen_files: []const ClangTablegenDescription,
    llvm_min_tablegen_files: []const ClangTablegenDescription,

    target: struct {
        is_64_bit: bool,
        pointer_bit_width: usize,
    },

    global_system_libraries: std.ArrayList([]const u8),
    global_flags: std.ArrayList([]const u8),

    pub fn new(
        b: *std.Build,
        module_opts: std.Build.Module.CreateOptions,
        llvm_source_root: LazyPath,
        opts: Options,
    ) *Context {
        const out = b.allocator.create(Context) catch @panic("OOM");
        const allocated_opts = b.allocator.create(Options) catch @panic("OOM");
        allocated_opts.* = opts;
        out.* = .{
            .b = b,
            .module_opts = module_opts,
            .targets = .{},
            .paths = Paths.new(b, llvm_source_root),
            .opts = allocated_opts,
            .target = .{
                .is_64_bit = module_opts.target.?.result.ptrBitWidth() == 64,
                .pointer_bit_width = module_opts.target.?.result.ptrBitWidth(),
            },
            .clang_tablegen_files = tblgen_descriptions.getClangTablegenDescriptions(b, llvm_source_root),
            .llvm_tablegen_files = tblgen_descriptions.getLLVMTablegenDescriptions(b, llvm_source_root),
            .llvm_min_tablegen_files = tblgen_descriptions.getLLVMMinTablegenDescriptions(b, llvm_source_root),
            .global_system_libraries = std.ArrayList([]const u8).initCapacity(b.allocator, 50) catch @panic("OOM"),
            .global_flags = std.ArrayList([]const u8).initCapacity(b.allocator, 50) catch @panic("OOM"),
        };

        // TODO: is abi gnu check the correct thing here, or should it check libc
        if (module_opts.target.?.result.abi.isGnu()) {
            out.global_flags.append("-D_GNU_SOURCE") catch @panic("OOM");

            if (out.target.pointer_bit_width == 32) {
                // enable 64bit off_t on 32bit systems using glibc
                out.global_flags.append("-D_FILE_OFFSET_BITS=64") catch @panic("OOM");
            }
        }

        return out;
    }

    fn addLLVMIncludesAndLinks(ctx: @This(), c: *Compile) *Compile {
        c.addIncludePath(ctx.paths.llvm.include.path);
        c.addConfigHeader(ctx.targets.llvm_public_config_header.?);
        c.addConfigHeader(ctx.targets.llvm_private_config_header.?);
        c.addConfigHeader(ctx.targets.llvm_abi_breaking_config_header.?);
        c.addConfigHeader(ctx.targets.llvm_features_inc_config_header.?);
        c.addConfigHeader(ctx.targets.llvm_targets_def_config_header.?);
        c.addConfigHeader(ctx.targets.llvm_asm_parsers_def_config_header.?);
        c.addConfigHeader(ctx.targets.llvm_disassemblers_def_config_header.?);
        c.addConfigHeader(ctx.targets.llvm_asm_printers_def_config_header.?);
        c.addConfigHeader(ctx.targets.llvm_target_exegesis_def_config_header.?);
        c.addConfigHeader(ctx.targets.llvm_target_mcas_def_config_header.?);
        c.linkLibCpp();
        return c;
    }

    fn addClangIncludesAndLinks(ctx: @This(), c: *Compile) *Compile {
        addLLVMIncludesAndLinks(ctx, c).addIncludePath(ctx.paths.clang.include.path);
        c.addConfigHeader(ctx.targets.clang_basic_version_config_header.?);
        c.addConfigHeader(ctx.targets.clang_config_config_header.?);
        c.addIncludePath(ctx.targets.clang_version_inc.?);
        return c;
    }

    pub fn addLLVMLibrary(ctx: @This(), options: std.Build.LibraryOptions) *Compile {
        return addLLVMIncludesAndLinks(ctx, ctx.b.addLibrary(options));
    }

    pub fn addLLVMExecutable(ctx: @This(), options: std.Build.ExecutableOptions) *Compile {
        return addLLVMIncludesAndLinks(ctx, ctx.b.addExecutable(options));
    }

    pub fn addLLVMObject(ctx: @This(), options: std.Build.ObjectOptions) *Compile {
        return addLLVMIncludesAndLinks(ctx, ctx.b.addObject(options));
    }

    pub fn addClangLibrary(ctx: @This(), options: std.Build.LibraryOptions) *Compile {
        return addClangIncludesAndLinks(ctx, ctx.b.addLibrary(options));
    }

    pub fn addClangExecutable(ctx: @This(), options: std.Build.ExecutableOptions) *Compile {
        return addClangIncludesAndLinks(ctx, ctx.b.addExecutable(options));
    }

    fn tablegen(
        ctx: @This(),
        executable: *Compile,
        options: TableGenOptions,
    ) std.Build.LazyPath {
        const tblgen_invocation = ctx.b.addRunArtifact(executable);
        tblgen_invocation.addFileArg(options.source_file);
        tblgen_invocation.addArg("-o");

        const generated_file = tblgen_invocation.addOutputFileArg(options.output_filename);
        tblgen_invocation.addArgs(options.args);

        for (options.include_dir_args) |include_dir| {
            tblgen_invocation.addPrefixedDirectoryArg("-I", include_dir);
        }

        return generated_file;
    }

    pub fn addTablegenOutputFileToWriteFileStep(
        ctx: @This(),
        wfs: *std.Build.Step.WriteFile,
        tblgen_exe: *Compile,
        desc: ClangTablegenDescription,
    ) void {
        for (desc.targets) |target| {
            var args = std.ArrayList([]const u8).init(ctx.b.allocator);
            args.ensureTotalCapacity(target.flags.len + 1) catch @panic("OOM");
            args.appendSlice(target.flags) catch @panic("OOM");
            args.append("--write-if-changed") catch @panic("OOM");

            const result_file = ctx.tablegen(tblgen_exe, .{
                .output_filename = target.output_basename,
                .args = args.toOwnedSlice() catch @panic("OOM"),
                .include_dir_args = desc.td_includes,
                .source_file = desc.td_file,
            });

            _ = wfs.addCopyFile(
                result_file,
                ctx.b.pathJoin(&.{ target.folder.toRelativePath(), target.output_basename }),
            );
        }
    }

    pub fn makeFlags(self: @This()) std.ArrayList([]const u8) {
        var flags = std.ArrayList([]const u8).initCapacity(self.b.allocator, 50) catch @panic("OOM");
        flags.appendSlice(self.global_flags.items) catch @panic("OOM");
        return flags;
    }

    pub fn makeModule(self: @This()) *std.Build.Module {
        return self.b.createModule(self.module_opts);
    }

    /// Module which targets the host system
    pub fn makeHostModule(self: @This()) *std.Build.Module {
        var opts_copy = self.module_opts;
        opts_copy.target = self.b.graph.host;
        return self.b.createModule(opts_copy);
    }

    pub fn dupeGlobalFlags(self: @This()) []const []const u8 {
        return self.b.allocator.dupe([]const u8, self.global_flags.items) catch @panic("OOM");
    }

    pub fn osIsUnixLike(os: std.Target.Os.Tag) bool {
        return switch (os) {
            .linux, .macos, .fuchsia, .haiku => true,
            else => false,
        };
    }

    const SystemHeader = enum {
        MACH_MACH_H,
        MALLOC_MALLOC_H,
        PTHREAD_H,
        SYS_MMAN_H,
        SYSEXITS_H,
        UNISTD_H,
        RLIMITS_H,
        DLFCN_H,
    };

    // TODO: are these headers ever provided by zig for platforms that typically
    // don't support them?
    pub fn targetHasHeader(target: std.Target, header: SystemHeader) bool {
        const default_for_unsupported = true;
        const os = target.os.tag;
        return switch (header) {
            .MACH_MACH_H, .MALLOC_MALLOC_H => switch (os) {
                .linux, .aix, .dragonfly, .freebsd, .netbsd, .haiku, .openbsd => false,
                .macos, .ios => true,
                .zos => false,
                .windows => false,
                else => default_for_unsupported,
            },
            .PTHREAD_H, .SYS_MMAN_H, .UNISTD_H => switch (os) {
                .linux, .aix, .dragonfly, .freebsd, .netbsd, .haiku, .openbsd => true,
                .macos, .ios => true,
                .windows => false,
                .zos => true,
                else => default_for_unsupported,
            },
            .SYSEXITS_H => switch (os) {
                .linux, .aix, .dragonfly, .freebsd, .netbsd, .haiku, .openbsd => true,
                .macos, .ios => true,
                .windows => false,
                .zos => false,
                else => default_for_unsupported,
            },
            .RLIMITS_H, .DLFCN_H => switch (os) {
                .linux => true, // TODO: this is not accurate, also maybe override build option is needed
                else => false,
            },
        };
    }

    const Symbol = enum {
        GETPAGESIZE,
        SYSCONF,
        DLADDR,
    };

    pub fn targetHasSymbol(target: std.Target, sym: Symbol) bool {
        const default_for_unsupported = false;
        const os = target.os.tag;
        return switch (sym) {
            .GETPAGESIZE => switch (os) {
                .linux, .aix, .dragonfly, .freebsd, .netbsd, .haiku, .openbsd => false,
                .macos, .ios => true,
                .zos => false,
                .windows => false,
                else => default_for_unsupported,
            },
            .SYSCONF => switch (os) {
                .linux, .aix, .dragonfly, .freebsd, .netbsd, .haiku, .openbsd => true,
                .macos, .ios => false,
                .zos => false,
                .windows => false,
                else => default_for_unsupported,
            },
            .DLADDR => switch (os) {
                .linux => true, // TODO: this is not accurate, also maybe override build option is needed
                else => false,
            },
        };
    }
};

pub const LLVMSupportedTargets = struct {
    all: LLVMALLTargets,
    experimental: LLVMExperimentalTargets,
};

pub const LLVMALLTargets = struct {
    AArch64: bool = true,
    AMDGPU: bool = true,
    ARM: bool = true,
    AVR: bool = true,
    BPF: bool = true,
    Hexagon: bool = true,
    Lanai: bool = true,
    LoongArch: bool = true,
    Mips: bool = true,
    MSP430: bool = true,
    NVPTX: bool = true,
    PowerPC: bool = true,
    RISCV: bool = true,
    Sparc: bool = true,
    SPIRV: bool = true,
    SystemZ: bool = true,
    VE: bool = true,
    WebAssembly: bool = true,
    X86: bool = true,
    XCore: bool = true,
};

pub const LLVMExperimentalTargets = struct {
    ARC: bool = false,
    CSKY: bool = false,
    DirectX: bool = false,
    M68k: bool = false,
    Xtensa: bool = false,
};

fn asciiToLower(comptime size: u64, str: [size]u8) [size]u8 {
    var copy = str;
    for (copy, 0..) |c, i| {
        copy[i] = std.ascii.toLower(c);
    }
    return copy;
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const clangd_malloc_trim = b.option(
        bool,
        "clangd_malloc_trim",
        "Call malloc_trim(3) periodically in clangd. Only takes effect when using glibc. (default: true if using glibc, false otherwise)",
    ) orelse target.result.isGnuLibC();
    const clangd_tidy_checks = b.option(
        bool,
        "clangd_tidy_checks",
        "Link all clang-tidy checks into clangd. (default: true)",
    ) orelse true;
    const clangd_decision_forest = b.option(
        bool,
        "clangd_decision_forest",
        "Enable decision forest model for ranking code completion items. Requires python (default: false)",
    ) orelse false;
    if (clangd_decision_forest) {
        @panic("clangd_decision_forest not currently implemented as it introduces a system dependency on python for generating headers.");
    }
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

    const llvm_enable_dump = b.option(
        bool,
        "llvm_enable_dump",
        "Enable dump functions even when assertions are disabled. (default: false)",
    ) orelse false;
    const llvm_unreachable_optimize = b.option(
        bool,
        "llvm_unreachable_optimize",
        "Optimize llvm_unreachable() as undefined behavior, guaranteed trap when false. (default: true)",
    ) orelse true;

    const clangd_build_xpc_default = target.result.os.tag == .macos;
    const clangd_build_xpc = b.option(
        bool,
        "clangd_build_xpc",
        "Use gRPC library to enable remote index support for clangd. (default: false, unless on macos darwin)",
    ) orelse clangd_build_xpc_default;

    const llvm_enable_threads_default = target.result.os.tag == .zos;
    const llvm_enable_threads = b.option(
        bool,
        "llvm_enable_threads",
        "Use threads if available. (default: true, unless on z/OS)",
    ) orelse llvm_enable_threads_default;
    const llvm_reverse_iteration = b.option(
        bool,
        "llvm_reverse_iteration",
        "If enabled, all supported unordered llvm containers would be iterated in reverse order. This is useful for uncovering non-determinism caused by iteration of unordered containers. (default: false)",
    ) orelse false;
    const llvm_abi_breaking_checks = b.option(
        ABIBreakingChecks,
        "llvm_abi_breaking_checks",
        ABIBreakingChecks.desc,
    ) orelse ABIBreakingChecks.default();

    // no FORCE_ON option needed here as we build zlib ourselves
    const llvm_enable_zlib = b.option(
        bool,
        "llvm_enable_zlib",
        "Use zlib for compression/decompression. (default: true)",
    ) orelse true;

    var supported_targets = LLVMSupportedTargets{
        .all = .{},
        .experimental = .{},
    };

    // go through all the fields and fill them out by creating options for them
    inline for (@typeInfo(LLVMSupportedTargets).@"struct".fields) |field| {
        inline for (@typeInfo(field.type).@"struct".fields) |target_option_field| {
            // jumping through hoops here to do compile time toLower...
            var array_fieldname: [target_option_field.name.len]u8 = undefined;
            std.mem.copyForwards(u8, &array_fieldname, target_option_field.name);
            array_fieldname = asciiToLower(array_fieldname.len, array_fieldname);

            @field(@field(supported_targets, field.name), target_option_field.name) = b.option(
                bool,
                b.fmt("support_{s}", .{&array_fieldname}),
                std.fmt.comptimePrint(
                    "Whether this build of LLVM should support generating code for the {s} platform. (default: {})",
                    .{ target_option_field.name, target_option_field.defaultValue().? },
                ),
            ) orelse target_option_field.defaultValue().?;
        }
    }

    const llvm_project = b.dependency("llvm_project", .{});

    // dummy dependency which is used when determining what lazy dependencies to
    // fetch. could also be llvm_project
    var default_dependency = std.Build.Dependency{ .builder = b };

    var ctx = Context.new(b, .{
        .target = target,
        .optimize = optimize,
    }, llvm_project.path("."), Options{
        .llvm_enable_zlib = llvm_enable_zlib,
        .llvm_enable_dump = llvm_enable_dump,
        // TODO: convert this to gnu style triple
        .llvm_default_target_triple = try target.result.zigTriple(b.allocator),
        .llvm_enable_threads = llvm_enable_threads,
        .llvm_unreachable_optimize = llvm_unreachable_optimize,
        .llvm_reverse_iteration = llvm_reverse_iteration,
        .llvm_abi_breaking_checks = llvm_abi_breaking_checks,
        .enable_grpc_reflection = enable_grpc_reflection,
        .clangd_build_xpc = clangd_build_xpc,
        .clangd_malloc_trim = clangd_malloc_trim,
        .clangd_tidy_checks = clangd_tidy_checks,
        .clangd_enable_remote = clangd_enable_remote,
        .clangd_decision_forest = clangd_decision_forest,
        .supported_targets = supported_targets,
    });

    if (ctx.opts.llvm_enable_zlib) {
        const zlib_dep = b.lazyDependency("zlib", .{}) orelse &default_dependency;
        ctx.targets.zlib = zlib_builder.build(zlib_dep, ctx.makeModule());
    }

    // fill out the components of ctx.targets which begin with "llvm_"
    @import("llvm_zig.zig").build(ctx);
    @import("clang.zig").build(ctx);

    // clang tools extra stuff

    {
        const opts = ctx.paths.clang_tools_extra.clang_tidy.clang_tidy_config_config_header.makeOptions();
        ctx.targets.cte_clang_tidy_config_config_header = ctx.b.addConfigHeader(opts, .{
            .CLANG_TIDY_ENABLE_STATIC_ANALYZER = true,
        });
    }

    ctx.targets.clangd_lib = ctx.addClangLibrary(.{
        .name = "clangd_lib",
        .linkage = .static,
        .root_module = ctx.makeModule(),
    });
    ctx.targets.clangd_lib.?.linkLibCpp();
    ctx.targets.clangd_lib.?.addIncludePath(ctx.paths.clang_tools_extra.include_cleaner.include.path);
    ctx.targets.clangd_lib.?.addIncludePath(ctx.paths.clang_tools_extra.clangd.path);
    ctx.targets.clangd_lib.?.addIncludePath(ctx.targets.clang_tablegenerated_incs.?);
    ctx.targets.clangd_lib.?.addIncludePath(ctx.targets.llvm_tablegenerated_incs.?);
    // TODO: configure and install clang-tidy headers, add the build dir as include path
    ctx.targets.clangd_lib.?.addConfigHeader(ctx.targets.cte_clang_tidy_config_config_header.?);

    ctx.targets.clangd_lib.?.addCSourceFiles(.{
        .root = ctx.paths.clang_tools_extra.clangd.path,
        .files = sources.cpp_files,
        .flags = &.{},
        .language = .cpp,
    });

    ctx.targets.clangd_lib.?.linkLibrary(ctx.targets.clang_ast_lib.?);
    ctx.targets.clangd_lib.?.linkLibrary(ctx.targets.clang_ast_matchers_lib.?);
    ctx.targets.clangd_lib.?.linkLibrary(ctx.targets.clang_basic_lib.?);
    ctx.targets.clangd_lib.?.linkLibrary(ctx.targets.clang_format_lib.?);
    ctx.targets.clangd_lib.?.linkLibrary(ctx.targets.clang_lex_lib.?);
    ctx.targets.clangd_lib.?.linkLibrary(ctx.targets.clang_tooling_core_lib.?);
    ctx.targets.clangd_lib.?.linkLibrary(ctx.targets.clang_tooling_inclusions_lib.?);

    // libs to build and link
    // clangDependencyScanning
    // clangDriver
    // clangFrontend
    // clangIndex
    // clangSema
    // clangSerialization
    // clangTooling
    // clangToolingInclusionsStdlib
    // clangToolingSyntax
    //
    // ${LLVM_PTHREAD_LIB}
    // clangIncludeCleaner
    // clangTidy
    // clangTidyUtils
    // clangdSupport

    // TODO: link ALL_CLANG_TIDY_CHECKS libraries if (clangd_tidy_checks)

    // TODO: include generated COMPLETIONMODEL headers and necessary sources
    // ctx.targets.clangd_lib.?.addIncludePath(...);

    ctx.targets.clangd_main_lib = ctx.addClangLibrary(.{
        .name = "clangd_main_lib",
        .linkage = .static,
        .root_module = ctx.makeModule(),
    });
    ctx.targets.clangd_main_lib.?.linkLibCpp();
    ctx.targets.clangd_main_lib.?.addCSourceFiles(.{
        .root = ctx.paths.clang_tools_extra.clangd.tool.path,
        .files = sources.tool_lib_cpp_files,
        .flags = ctx.dupeGlobalFlags(),
    });
    ctx.targets.clangd_main_lib.?.addIncludePath(ctx.paths.clang_tools_extra.clangd.path);
    ctx.targets.clangd_main_lib.?.addIncludePath(ctx.paths.clang_tools_extra.include_cleaner.include.path);
    ctx.targets.clangd_main_lib.?.addIncludePath(ctx.targets.clang_tablegenerated_incs.?);
    ctx.targets.clangd_main_lib.?.addIncludePath(ctx.targets.llvm_tablegenerated_incs.?);
    ctx.targets.clangd_main_lib.?.addConfigHeader(ctx.targets.cte_clang_tidy_config_config_header.?);

    ctx.targets.clangd_exe = b.addExecutable(.{
        .name = "clangd",
        .root_module = ctx.makeModule(),
    });
    ctx.targets.clangd_exe.?.addCSourceFiles(.{
        .root = ctx.paths.clang_tools_extra.clangd.tool.path,
        .files = sources.tool_cpp_files,
        .flags = ctx.dupeGlobalFlags(),
        .language = .cpp,
    });
    ctx.b.installArtifact(ctx.targets.clangd_exe.?);
    ctx.targets.clangd_exe.?.linkLibrary(ctx.targets.clangd_lib.?);
    ctx.targets.clangd_exe.?.linkLibrary(ctx.targets.clangd_main_lib.?);
}
