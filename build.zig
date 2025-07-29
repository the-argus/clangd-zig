const std = @import("std");
const builtin = @import("builtin");
const zlib_builder = @import("zlib.zig");

const sources = @import("clangd_sources.zig");
const Compile = std.Build.Step.Compile;
const LazyPath = std.Build.LazyPath;
pub const version = std.SemanticVersion{ .major = 20, .minor = 1, .patch = 8 };
pub const version_string = "20.1.8";

pub const Options = struct {
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

pub const RunArtifactResultFile = struct {
    outputted_file: std.Build.LazyPath,
    step: *std.Build.Step,
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
                basic: struct {
                    path: LazyPath,
                    attr_td: LazyPath,
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
            },
            .clang = .{
                .include = .{
                    .path = root.path(b, "clang/include"),
                    .clang = .{
                        .basic = .{
                            .path = root.path(b, "clang/include/clang/Basic"),
                            .attr_td = root.path(b, "clang/include/clang/Basic/Attr.td"),
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
                    .llvm = .{ .config = .{
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
                    } },
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
    llvm_tblgen_exe: ?*Compile = null,

    // llvm/include/llvm/Config/llvm-config.h.cmake
    llvm_public_config_header: ?*std.Build.Step.ConfigHeader = null,
    // llvm/include/llvm/Config/config.h.cmake
    llvm_private_config_header: ?*std.Build.Step.ConfigHeader = null,
    // llvm/include/llvm/Config/abi-breaking.h.cmake
    llvm_abi_breaking_config_header: ?*std.Build.Step.ConfigHeader = null,
    llvm_regular_keyword_attr_info_inc: ?RunArtifactResultFile = null,
};

pub const Context = struct {
    b: *std.Build,
    module_opts: std.Build.Module.CreateOptions,
    targets: Targets,
    paths: *const Paths,
    opts: *const Options,

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
        };
        return out;
    }

    pub fn makeModule(self: @This()) *std.Build.Module {
        return self.b.createModule(self.module_opts);
    }

    /// Module which targets the host system
    pub fn makeHostModule(self: @This()) *std.Build.Module {
        var opts_copy = self.module_opts;
        opts_copy.target.?.query = .{};
        opts_copy.target.?.result = builtin.target;
        return self.b.createModule(opts_copy);
    }
};

// this function is the equivalent of clang_target_link_libraries in
// AddClang.cmake in the llvm source code. right now it just links the libraries
// but in the future could be used to link the llvm-driver.
fn clangTargetLinkLibraries(target: *Compile, libs: []*Compile) void {
    for (libs) |lib| {
        target.linkLibrary(lib);
    }
}

// this function is the equivalent of add_clang_tool in the AddClang.cmake file
// of the llvm source code. It
fn addClangTool(ctx: *Context, name: []const u8) *Compile {
    const out = ctx.b.addExecutable(.{
        .name = name,
        .root_module = ctx.makeModule(),
    });
    ctx.b.installArtifact(out);
    return out;
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

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

    const llvm_project = b.dependency("llvm_project", .{});

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
    });

    if (llvm_enable_zlib) {
        const zlib_dep = b.lazyDependency("zlib", .{}).?;
        ctx.targets.zlib = zlib_builder.build(zlib_dep, ctx.makeModule());
    }

    // fill out the components of ctx.targets which begin with "llvm_"
    @import("llvm_zig.zig").build(ctx);

    ctx.targets.clangd_lib = b.addLibrary(.{
        .name = "clangd_lib",
        .linkage = .static,
        .root_module = ctx.makeModule(),
    });
    ctx.targets.clangd_lib.?.linkLibCpp();
    ctx.targets.clangd_lib.?.addIncludePath(ctx.paths.clang_tools_extra.include_cleaner.include.path);
    ctx.targets.clangd_lib.?.addIncludePath(ctx.paths.clang_tools_extra.clangd.path);
    ctx.targets.clangd_lib.?.addIncludePath(ctx.paths.clang.include.path);
    ctx.targets.clangd_lib.?.addIncludePath(ctx.targets.llvm_regular_keyword_attr_info_inc.?.outputted_file);
    // TODO: is this necessary? its already a generated file and should keep track of dependencies
    ctx.targets.clangd_lib.?.step.dependOn(ctx.targets.llvm_regular_keyword_attr_info_inc.?.step);
    ctx.targets.clangd_lib.?.addIncludePath(ctx.paths.llvm.include.path);
    ctx.targets.clangd_lib.?.addConfigHeader(ctx.targets.llvm_public_config_header.?);
    ctx.targets.clangd_lib.?.addConfigHeader(ctx.targets.llvm_abi_breaking_config_header.?);
    // TODO: configure and install clang-tidy headers, add the build dir as include path

    ctx.targets.clangd_lib.?.addConfigHeader(b.addConfigHeader(
        .{ .style = .{ .cmake = ctx.paths.clang_tools_extra.clangd.path.path(b, "Features.inc.in") } },
        .{
            .CLANGD_BUILD_XPC = clangd_build_xpc,
            .CLANGD_ENABLE_REMOTE = clangd_enable_remote,
            .ENABLE_GRPC_REFLECTION = enable_grpc_reflection,
            .CLANGD_MALLOC_TRIM = clangd_malloc_trim,
            .CLANGD_TIDY_CHECKS = clangd_tidy_checks,
            .CLANGD_DECISION_FOREST = clangd_decision_forest,
        },
    ));
    ctx.targets.clangd_lib.?.addCSourceFiles(.{
        .root = ctx.paths.clang_tools_extra.clangd.path,
        .files = sources.cpp_files,
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

    // TODO: include generated COMPLETIONMODEL headers and necessary sources
    // ctx.targets.clangd_lib.?.addIncludePath(...);

    // tool subdir where we build clangd executable ----------------------------

    ctx.targets.clangd_main_lib = b.addLibrary(.{
        .name = "clangd_main_lib",
        .linkage = .static,
        .root_module = ctx.makeModule(),
    });
    ctx.targets.clangd_main_lib.?.linkLibCpp();
    ctx.targets.clangd_main_lib.?.addCSourceFiles(.{
        .root = ctx.paths.clang_tools_extra.clangd.tool.path,
        .files = sources.tool_lib_cpp_files,
        .flags = &.{},
    });
    ctx.targets.clangd_main_lib.?.addIncludePath(ctx.paths.llvm.include.path);
    ctx.targets.clangd_main_lib.?.addConfigHeader(ctx.targets.llvm_public_config_header.?);
    ctx.targets.clangd_main_lib.?.addConfigHeader(ctx.targets.llvm_abi_breaking_config_header.?);

    ctx.targets.clangd_exe = addClangTool(ctx, "clangd");
    ctx.targets.clangd_exe.?.linkLibrary(ctx.targets.clangd_lib.?);
    ctx.targets.clangd_exe.?.linkLibrary(ctx.targets.clangd_main_lib.?);
}
