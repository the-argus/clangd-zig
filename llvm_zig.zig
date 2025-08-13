const std = @import("std");
const builtin = @import("builtin");

const Build = @import("build.zig");
const Context = Build.Context;
const LazyPath = std.Build.LazyPath;
const ConfigHeader = std.Build.Step.ConfigHeader;
const Compile = std.Build.Step.Compile;
const ABIBreakingChecks = Build.ABIBreakingChecks;
const version = Build.version;
const version_string = Build.version_string;
const sources = @import("clangd_sources.zig");

pub const LLVMExportedArtifacts = struct {
    support_lib: *Compile,
    frontend_openmp_lib: *Compile,
    option_lib: *Compile,
    target_parser_lib: *Compile,
    // all_targets_infos_lib: *Compile,

    // llvm/include/llvm/Config/llvm-config.h.cmake
    public_config_header: *ConfigHeader,
    // llvm/include/llvm/Config/config.h.cmake
    //private_config_header: *ConfigHeader,
    // llvm/include/llvm/Config/abi-breaking.h.cmake
    abi_breaking_config_header: *ConfigHeader,
    features_inc_config_header: *ConfigHeader,
    targets_def_config_header: *ConfigHeader,
    asm_parsers_def_config_header: *ConfigHeader,
    asm_printers_def_config_header: *ConfigHeader,
    disassemblers_def_config_header: *ConfigHeader,
    target_exegesis_def_config_header: *ConfigHeader,
    target_mcas_def_config_header: *ConfigHeader,

    host_component_demangle_lib: *Compile,
    host_component_support_lib: *Compile,
    host_component_tablegen_lib: *Compile,
    host_component_tblgen_exe: *Compile,

    tablegenerated_incs: LazyPath,

    // llvm_demangle_lib: ?*Compile = null,
    // llvm_binary_format_lib: ?*Compile = null,
    // llvm_remarks_lib: ?*Compile = null,
    // llvm_object_lib: ?*Compile = null,
    // llvm_core_lib: ?*Compile = null,
    // llvm_analysis_lib: ?*Compile = null,
    // llvm_bitcode_reader_lib: ?*Compile = null,
    // llvm_bitcode_writer_lib: ?*Compile = null,
    // llvm_bitstream_reader_lib: ?*Compile = null,
    // llvm_transforms_utils_lib: ?*Compile = null,
    // llvm_debug_info_btf_lib: ?*Compile = null,
    // llvm_debug_info_codeview_lib: ?*Compile = null,
    // llvm_debug_info_dwarf_lib: ?*Compile = null,
    // llvm_debug_info_msf_lib: ?*Compile = null,
    // llvm_debug_info_pdb_lib: ?*Compile = null,
    // llvm_debug_info_symbolize_lib: ?*Compile = null,
    // llvm_profile_data_lib: ?*Compile = null,
};

const llvm_all_targets = &[_][]const u8{
    "AArch64",
    "AMDGPU",
    "ARM",
    "AVR",
    "BPF",
    "Hexagon",
    "Lanai",
    "LoongArch",
    "Mips",
    "MSP430",
    "NVPTX",
    "PowerPC",
    "RISCV",
    "Sparc",
    "SPIRV",
    "SystemZ",
    "VE",
    "WebAssembly",
    "X86",
    "XCore",
};

// TODO: does native refer to the compilation host?
const llvm_native_arch = getLLVMNativeArch(builtin.cpu.arch);

// underscore because starting a function with llvm makes llvm thing we're
// trying to define an intrinsic
fn llvmTargetToolString(ctx: *const Context, str: []const u8) []const u8 {
    return ctx.b.fmt("LLVMInitialize{s}{s}", .{ llvm_native_arch, str });
}

var llvm_headers: ?[]*std.Build.Step.ConfigHeader = null;
var llvm_include_paths: ?[]LazyPath = null;

fn llvmLink(c: *Compile) void {
    c.linkLibCpp();
    Context.configAll(c, llvm_headers.?);
    Context.includeAll(c, llvm_include_paths.?);
}

fn addLLVMLibrary(ctx: *const Context, options: std.Build.LibraryOptions) *Compile {
    const out = ctx.b.addLibrary(options);
    llvmLink(out);
    return out;
}

fn addLLVMExecutable(ctx: *const Context, options: std.Build.ExecutableOptions) *Compile {
    const out = ctx.b.addExecutable(options);
    llvmLink(out);
    return out;
}

fn addLLVMObject(ctx: *const Context, options: std.Build.ObjectOptions) *Compile {
    const out = ctx.b.addObject(options);
    llvmLink(out);
    return out;
}

/// Fills out all the fields in Context.targets that start with llvm_*, pulling
/// from Context.options. called from root build.zig
pub fn build(ctx: *const Context) LLVMExportedArtifacts {
    const abi_breaking_opts = ctx.paths.llvm.include.llvm.config.llvm_abi_breaking_config_header.makeOptions();
    const abi_breaking_config_header = ctx.b.addConfigHeader(abi_breaking_opts, .{
        .LLVM_ENABLE_REVERSE_ITERATION = ctx.opts.llvm_reverse_iteration,
        .LLVM_ENABLE_ABI_BREAKING_CHECKS = std.enums.tagName(
            ABIBreakingChecks,
            ctx.opts.llvm_abi_breaking_checks,
        ),
    });

    const features_inc_config_header = ctx.b.addConfigHeader(
        .{ .style = .{ .cmake = ctx.srcPath("clang-tools-extra/clangd/Features.inc.in") }, .include_path = "Features.inc" },
        .{
            .CLANGD_BUILD_XPC = ctx.opts.clangd_build_xpc,
            .CLANGD_ENABLE_REMOTE = ctx.opts.clangd_enable_remote,
            .ENABLE_GRPC_REFLECTION = ctx.opts.enable_grpc_reflection,
            .CLANGD_MALLOC_TRIM = ctx.opts.clangd_malloc_trim,
            .CLANGD_TIDY_CHECKS = ctx.opts.clangd_tidy_checks,
            .CLANGD_DECISION_FOREST = ctx.opts.clangd_decision_forest,
        },
    );

    const public_opts = ctx.paths.llvm.include.llvm.config.llvm_public_config_header.makeOptions();
    const public_config_header = ctx.b.addConfigHeader(public_opts, .{
        // render_cmake in ConfigHeader niceley interprets these correctly
        .LLVM_ENABLE_DUMP = ctx.opts.llvm_enable_dump,
        .LLVM_DEFAULT_TARGET_TRIPLE = ctx.opts.llvm_default_target_triple,
        .LLVM_ENABLE_THREADS = ctx.opts.llvm_enable_threads,
        .LLVM_HAS_ATOMICS = true, // zig is clang which has gnu atomics
        // TODO: convert this triple to gnu style triple
        .LLVM_HOST_TRIPLE = builtin.target.zigTriple(ctx.b.allocator) catch @panic("OOM"),
        .LLVM_NATIVE_ARCH = llvm_native_arch,
        .LLVM_NATIVE_ASMPARSER = llvmTargetToolString(ctx, "AsmParser"),
        .LLVM_NATIVE_ASMPRINTER = llvmTargetToolString(ctx, "AsmPrinter"),
        .LLVM_NATIVE_DISASSEMBLER = llvmTargetToolString(ctx, "Disassembler"),
        .LLVM_NATIVE_TARGET = llvmTargetToolString(ctx, "Target"),
        .LLVM_NATIVE_TARGETINFO = llvmTargetToolString(ctx, "TargetInfo"),
        .LLVM_NATIVE_TARGETMC = llvmTargetToolString(ctx, "TargetMC"),
        .LLVM_NATIVE_TARGETMCA = llvmTargetToolString(ctx, "TargetMCA"),
        .LLVM_ON_UNIX = Context.osIsUnixLike(builtin.os.tag),
        .LLVM_USE_INTEL_JITEVENTS = false,
        .LLVM_USE_OPROFILE = false,
        .LLVM_USE_PERF = false,
        .LLVM_VERSION_MAJOR = @as(i64, version.major),
        .LLVM_VERSION_MINOR = @as(i64, version.minor),
        .LLVM_VERSION_PATCH = @as(i64, version.patch),
        .PACKAGE_VERSION = version_string,
        .LLVM_FORCE_ENABLE_STATS = false,
        .LLVM_WITH_Z3 = false,
        .LLVM_ENABLE_CURL = false,
        .LLVM_ENABLE_HTTPLIB = false,
        .LLVM_ENABLE_ZLIB = ctx.opts.llvm_enable_zlib,
        .LLVM_ENABLE_ZSTD = false, // TODO: this is on by default in llvm
        .LLVM_HAVE_TFLITE = false,
        .HAVE_SYSEXITS_H = true,
        .LLVM_BUILD_LLVM_DYLIB = false,
        .LLVM_BUILD_SHARED_LIBS = false,
        .LLVM_FORCE_USE_OLD_TOOLCHAIN = false,
        .LLVM_ENABLE_DIA_SDK = false,
        .LLVM_ENABLE_PLUGINS = false,
        .LLVM_HAS_LOGF128 = false,
    });

    // track all targets as a big string for Targets.def config header
    var supported_targets = std.ArrayList(u8).init(ctx.b.allocator);
    var enum_asm_printers = std.ArrayList(u8).init(ctx.b.allocator);
    var enum_asm_parsers = std.ArrayList(u8).init(ctx.b.allocator);
    var enum_disassemblers = std.ArrayList(u8).init(ctx.b.allocator);
    var enum_exegesis = std.ArrayList(u8).init(ctx.b.allocator);
    var enum_mcas = std.ArrayList(u8).init(ctx.b.allocator);
    supported_targets.ensureTotalCapacity(1000) catch @panic("OOM");
    enum_asm_printers.ensureTotalCapacity(1000) catch @panic("OOM");
    enum_asm_parsers.ensureTotalCapacity(1000) catch @panic("OOM");
    enum_disassemblers.ensureTotalCapacity(1000) catch @panic("OOM");
    enum_exegesis.ensureTotalCapacity(1000) catch @panic("OOM");
    enum_mcas.ensureTotalCapacity(1000) catch @panic("OOM");
    var supported_targets_writer = supported_targets.writer();
    var asm_printers_writer = enum_asm_printers.writer();
    var asm_parsers_writer = enum_asm_parsers.writer();
    var disassemblers_writer = enum_disassemblers.writer();
    var exegesis_writer = enum_exegesis.writer();
    var mcas_writer = enum_mcas.writer();

    // add defines to config header for every field in supported targets structs
    inline for (@typeInfo(@import("build.zig").LLVMSupportedTargets).@"struct".fields) |field| {
        inline for (@typeInfo(field.type).@"struct".fields) |target_field| {
            const field_name = std.fmt.comptimePrint("LLVM_HAS_{s}_TARGET", .{target_field.name});
            const is_supported = @field(@field(
                ctx.opts.supported_targets,
                field.name,
            ), target_field.name);
            public_config_header.addValue(field_name, bool, is_supported);

            if (is_supported) {
                const Set = std.static_string_map.StaticStringMap(void);
                supported_targets_writer.print("LLVM_TARGET({s})\n", .{target_field.name}) catch @panic("OOM, or format error");
                // NOTE: in normal LLVM there is a check to make sure llvm/lib/Target/${targetname}/*AsmPrinter.cpp exists,
                // but all targets currently have one so we just skip that
                asm_printers_writer.print("LLVM_ASM_PRINTER({s})\n", .{target_field.name}) catch @panic("OOM, or format error");
                if (!Set.initComptime(.{ .{"ARC"}, .{"DirectX"}, .{"NVPTX"}, .{"SPIRV"}, .{"XCore"} }).has(target_field.name)) {
                    asm_parsers_writer.print("LLVM_ASM_PARSER({s})\n", .{target_field.name}) catch @panic("OOM, or format error");
                }

                if (!Set.initComptime(.{ .{"DirectX"}, .{"NVPTX"}, .{"SPIRV"} }).has(target_field.name)) {
                    disassemblers_writer.print("LLVM_DISASSEMBLER({s})\n", .{target_field.name}) catch @panic("OOM, or format error");
                }

                // inclusion list instead of exclusion
                if (Set.initComptime(.{ .{"AMDGPU"}, .{"RISCV"}, .{"X86"} }).has(target_field.name)) {
                    mcas_writer.print("LLVM_TARGETMCA({s})\n", .{target_field.name}) catch @panic("OOM, or format error");
                }

                if (Set.initComptime(.{ .{"AArch64"}, .{"Mips"}, .{"PowerPC"}, .{"RISCV"}, .{"X86"} }).has(target_field.name)) {
                    exegesis_writer.print("LLVM_EXEGESIS({s})\n", .{target_field.name}) catch @panic("OOM, or format error");
                }
            }
        }
    }

    const targets_def_config_header = ctx.b.addConfigHeader(
        ctx.paths.llvm.include.llvm.config.llvm_targets_def_config_header.makeOptions(),
        .{
            .LLVM_ENUM_TARGETS = supported_targets.toOwnedSlice() catch @panic("OOM"),
        },
    );
    const asm_printers_def_config_header = ctx.b.addConfigHeader(
        ctx.paths.llvm.include.llvm.config.llvm_asm_printers_def_config_header.makeOptions(),
        .{
            .LLVM_ENUM_ASM_PRINTERS = enum_asm_printers.toOwnedSlice() catch @panic("OOM"),
        },
    );
    const asm_parsers_def_config_header = ctx.b.addConfigHeader(
        ctx.paths.llvm.include.llvm.config.llvm_asm_parsers_def_config_header.makeOptions(),
        .{
            .LLVM_ENUM_ASM_PARSERS = enum_asm_parsers.toOwnedSlice() catch @panic("OOM"),
        },
    );
    const disassemblers_def_config_header = ctx.b.addConfigHeader(
        ctx.paths.llvm.include.llvm.config.llvm_disassemblers_def_config_header.makeOptions(),
        .{
            .LLVM_ENUM_DISASSEMBLERS = enum_disassemblers.toOwnedSlice() catch @panic("OOM"),
        },
    );
    const target_exegesis_def_config_header = ctx.b.addConfigHeader(
        ctx.paths.llvm.include.llvm.config.llvm_target_exegesis_def_config_header.makeOptions(),
        .{
            .LLVM_ENUM_EXEGESIS = enum_exegesis.toOwnedSlice() catch @panic("OOM"),
        },
    );
    const target_mcas_def_config_header = ctx.b.addConfigHeader(
        ctx.paths.llvm.include.llvm.config.llvm_target_mcas_def_config_header.makeOptions(),
        .{
            .LLVM_ENUM_TARGETMCAS = enum_mcas.toOwnedSlice() catch @panic("OOM"),
        },
    );

    const private_opts = ctx.paths.llvm.include.llvm.config.llvm_private_config_header.makeOptions();
    const target = ctx.module_opts.target.?.result;
    const private_config_header = ctx.b.addConfigHeader(private_opts, .{
        .BUG_REPORT_URL = Build.bug_report_url,
        .ENABLE_BACKTRACES = false,
        .ENABLE_CRASH_OVERRIDES = false,
        .LLVM_ENABLE_CRASH_DUMPS = false,
        .ENABLE_DEBUGLOC_COVERAGE_TRACKING = false,
        .LLVM_WINDOWS_PREFER_FORWARD_SLASH = false,
        .HAVE_BACKTRACE = false,
        .BACKTRACE_HEADER = "",
        .HAVE_CRASHREPORTERCLIENT_H = false,
        .HAVE_CRASHREPORTER_INFO = false,
        .HAVE_DECL_ARC4RANDOM = false,
        .HAVE_DECL_FE_ALL_EXCEPT = false,
        .HAVE_DECL_FE_INEXACT = false,
        .HAVE_DECL_STRERROR_S = false,
        .HAVE_DLOPEN = false,
        .HAVE_REGISTER_FRAME = false,
        .HAVE_DEREGISTER_FRAME = false,
        .HAVE_UNW_ADD_DYNAMIC_FDE = false,
        .HAVE_FFI_CALL = false, // libffi
        .HAVE_FFI_FFI_H = false,
        .HAVE_FFI_H = false,
        .HAVE_FUTIMENS = false,
        .HAVE_FUTIMES = false,
        .HAVE_GETPAGESIZE = Context.targetHasSymbol(target, .GETPAGESIZE),
        .HAVE_GETRUSAGE = false,
        .HAVE_ISATTY = false,
        .HAVE_LIBEDIT = false,
        .HAVE_LIBPFM = false,
        .LIBPFM_HAS_FIELD_CYCLES = false,
        .HAVE_LIBPSAPI = false,
        .HAVE_LIBPTHREAD = true, // TODO: zig should always provide this? yes?
        .HAVE_PTHREAD_GETNAME_NP = false,
        .HAVE_PTHREAD_SETNAME_NP = false,
        .HAVE_PTHREAD_GET_NAME_NP = false,
        .HAVE_PTHREAD_SET_NAME_NP = false,
        .HAVE_MACH_MACH_H = Context.targetHasHeader(target, .MACH_MACH_H),
        .HAVE_MALLCTL = false,
        .HAVE_MALLINFO = false,
        .HAVE_MALLINFO2 = false,
        .HAVE_MALLOC_MALLOC_H = Context.targetHasHeader(target, .MALLOC_MALLOC_H),
        .HAVE_MALLOC_ZONE_STATISTICS = false,
        .HAVE_POSIX_SPAWN = false,
        .HAVE_PREAD = false,
        .HAVE_PTHREAD_H = Context.targetHasHeader(target, .PTHREAD_H),
        .HAVE_PTHREAD_MUTEX_LOCK = true,
        .HAVE_PTHREAD_RWLOCK_INIT = true,
        .HAVE_SBRK = true, // i hope so
        .HAVE_SETENV = true,
        .HAVE_SIGALTSTACK = false,
        .HAVE_STRERROR_R = false,
        .HAVE_SYSCONF = Context.targetHasSymbol(target, .SYSCONF),
        .HAVE_SYS_MMAN_H = Context.targetHasHeader(target, .SYS_MMAN_H),
        .HAVE_STRUCT_STAT_ST_MTIMESPEC_TV_NSEC = false,
        .HAVE_STRUCT_STAT_ST_MTIM_TV_NSEC = false,
        .HAVE_UNISTD_H = Context.targetHasHeader(target, .UNISTD_H),
        .HAVE_VALGRIND_VALGRIND_H = false,
        .HAVE__ALLOCA = false,
        .HAVE___ALLOCA = false,
        .HAVE__CHSIZE_S = false,
        .HAVE__UNWIND_BACKTRACE = false,
        .HAVE___ASHLDI3 = false,
        .HAVE___ASHRDI3 = false,
        .HAVE___CHKSTK = false,
        .HAVE___CHKSTK_MS = false,
        .HAVE___CMPDI2 = false,
        .HAVE___DIVDI3 = false,
        .HAVE___FIXDFDI = false,
        .HAVE___FIXSFDI = false,
        .HAVE___FLOATDIDF = false,
        .HAVE___LSHRDI3 = false,
        .HAVE___MAIN = false,
        .HAVE___MODDI3 = false,
        .HAVE___UDIVDI3 = false,
        .HAVE___UMODDI3 = false,
        .HAVE____CHKSTK = false,
        .HAVE____CHKSTK_MS = false,
        .HOST_LINK_VERSION = "0.0.1", // TODO
        .LLVM_TARGET_TRIPLE_ENV = false,
        .LLVM_VERSION_PRINTER_SHOW_HOST_TARGET_INFO = false,
        .LLVM_VERSION_PRINTER_SHOW_BUILD_CONFIG = false,
        .LLVM_ENABLE_LIBXML2 = false,
        .LTDL_SHLIB_EXT = ".so", // TODO: get library extension per OS
        .LLVM_PLUGIN_EXT = ".so",
        .PACKAGE_BUGREPORT = "DUMMY ADDRESS",
        .PACKAGE_NAME = "llvm-zig",
        .PACKAGE_STRING = "dummy",
        .PACKAGE_VERSION = @import("build.zig").version_string,
        .PACKAGE_VENDOR = "the-argus on github",
        .stricmp = "stricmp",
        .strdup = "strdup",
        .LLVM_GISEL_COV_ENABLED = false,
        .LLVM_GISEL_COV_PREFIX = false,
        .LLVM_SUPPORT_XCODE_SIGNPOSTS = false,
        .HAVE_PROC_PID_RUSAGE = false,
        .HAVE_BUILTIN_THREAD_POINTER = false,
    });

    var headers = [_]*ConfigHeader{
        public_config_header,
        private_config_header,
        abi_breaking_config_header,
        features_inc_config_header,
        targets_def_config_header,
        asm_parsers_def_config_header,
        disassemblers_def_config_header,
        asm_printers_def_config_header,
        target_exegesis_def_config_header,
        target_mcas_def_config_header,
    };
    llvm_headers = &headers;
    var include_paths = [_]LazyPath{
        ctx.srcPath("llvm/include"),
    };
    llvm_include_paths = &include_paths;

    const hostOptions = std.Build.Module.CreateOptions{
        .optimize = .Debug,
        .target = ctx.b.graph.host,
    };
    const targetOptions = ctx.module_opts;

    const host_component_demangle_lib = buildDemangle(ctx, hostOptions);
    const llvm_demangle_lib = buildDemangle(ctx, targetOptions);

    // depends on demangle lib along with the abi-breaking, public and private config headers
    const host_component_support_lib = buildSupport(ctx, hostOptions);
    host_component_support_lib.linkLibrary(host_component_demangle_lib);
    const llvm_support_lib = buildSupport(ctx, targetOptions);
    llvm_support_lib.linkLibrary(llvm_demangle_lib);

    // build llvm tablegen lib
    const host_component_tablegen_lib = addLLVMLibrary(ctx, .{
        .name = "LLVMTableGen",
        .root_module = ctx.makeHostModule(),
    });
    host_component_tablegen_lib.addCSourceFiles(.{
        .root = ctx.llvmLib("TableGen"),
        .files = sources.llvm_tablegen_lib_cpp_files,
        .flags = ctx.dupeGlobalFlags(),
        .language = .cpp,
    });
    host_component_tablegen_lib.addIncludePath(ctx.llvmLib("TableGen"));
    host_component_tablegen_lib.linkLibrary(host_component_support_lib);

    const host_component_tblgen_basic_lib = addLLVMObject(ctx, .{
        .name = "LLVMTableGenBasic",
        .root_module = ctx.makeHostModule(),
    });
    host_component_tblgen_basic_lib.addCSourceFiles(.{
        .root = ctx.srcPath("llvm/utils/TableGen/Basic"),
        .files = sources.llvm_tablegen_basic_lib_cpp_files,
        .flags = ctx.dupeGlobalFlags(),
        .language = .cpp,
    });
    host_component_tblgen_basic_lib.linkLibrary(host_component_tablegen_lib);
    host_component_tblgen_basic_lib.installHeadersDirectory(ctx.srcPath("llvm/utils/TableGen/Basic"), "Basic/", .{});

    // create llvm-min-tablgen to bootstrap regular llvm tablegen
    const host_component_tblgen_min_exe = addLLVMExecutable(ctx, .{
        .name = "llvm-min-tablgen",
        .root_module = ctx.makeHostModule(),
    });
    host_component_tblgen_min_exe.addCSourceFiles(.{
        .root = ctx.srcPath("llvm/utils/TableGen"),
        .flags = ctx.dupeGlobalFlags(),
        .files = sources.llvm_min_tablegen_cpp_files,
        .language = .cpp,
    });
    host_component_tblgen_min_exe.addObject(host_component_tblgen_basic_lib);

    const llvm_min_tablegenerated_incs = block: {
        const writefile_step = ctx.b.addWriteFiles();
        for (ctx.llvm_min_tablegen_files) |desc| {
            ctx.addTablegenOutputFileToWriteFileStep(writefile_step, host_component_tblgen_min_exe, desc);
        }
        break :block writefile_step.getDirectory();
    };

    // build llvm/utils/TableGen/Common
    const host_component_tblgen_common_lib = addLLVMObject(ctx, .{
        .name = "LLVMTableGenCommon",
        .root_module = ctx.makeHostModule(),
    });
    host_component_tblgen_common_lib.addCSourceFiles(.{
        .root = ctx.llvmUtil("TableGen/Common"),
        .files = sources.llvm_tablegen_common_lib_cpp_files,
        .flags = ctx.dupeGlobalFlags(),
        .language = .cpp,
    });
    host_component_tblgen_common_lib.addIncludePath(llvm_min_tablegenerated_incs);
    // installHeadersDirectory is not recursive
    host_component_tblgen_common_lib.installHeadersDirectory(ctx.llvmUtil("TableGen/Common"), "Common/", .{});
    host_component_tblgen_common_lib.installHeadersDirectory(
        ctx.llvmUtil("TableGen/Common/GlobalISel"),
        "Common/GlobalISel/",
        .{},
    );
    // TODO: why is this necessary? installHeadersDirectory should add these folders to the include path, right?
    host_component_tblgen_common_lib.addIncludePath(ctx.llvmUtil("TableGen"));

    // link libLLVMTableGen lib into executable
    const host_component_tblgen_exe = block: {
        const lib = addLLVMExecutable(ctx, .{
            .name = "llvm-tblgen",
            .root_module = ctx.makeHostModule(),
        });
        lib.addCSourceFiles(.{
            .root = ctx.llvmUtil("TableGen"),
            .files = sources.llvm_tablegen_cpp_files,
            .flags = ctx.dupeGlobalFlags(),
            .language = .cpp,
        });
        lib.addIncludePath(llvm_min_tablegenerated_incs);
        lib.addObject(host_component_tblgen_common_lib);
        lib.addObject(host_component_tblgen_basic_lib);
        break :block lib;
    };

    const tablegenerated_incs = block: {
        const writefile_step = ctx.b.addWriteFiles();
        for (ctx.llvm_tablegen_files) |desc| {
            ctx.addTablegenOutputFileToWriteFileStep(writefile_step, host_component_tblgen_exe, desc);
        }
        // also do everything that tablegen min had
        for (ctx.llvm_min_tablegen_files) |desc| {
            ctx.addTablegenOutputFileToWriteFileStep(writefile_step, host_component_tblgen_exe, desc);
        }
        break :block writefile_step.getDirectory();
    };

    const llvm_core_lib = block: {
        const lib = ctx.b.addLibrary(.{
            .name = "llvmCore",
            .root_module = ctx.makeModule(),
        });
        lib.addCSourceFiles(.{
            .root = ctx.llvmLib("IR"),
            .files = sources.llvm_core_lib_cpp_files,
            .flags = ctx.dupeGlobalFlags(),
            .language = .cpp,
        });

        lib.addIncludePath(tablegenerated_incs);
        lib.linkLibrary(llvm_support_lib);
        break :block lib;
    };

    const llvm_option_lib = block: {
        const lib = ctx.b.addLibrary(.{
            .name = "llvmOption",
            .root_module = ctx.makeModule(),
        });
        lib.addCSourceFiles(.{
            .root = ctx.llvmLib("Option"),
            .files = sources.llvm_option_lib_cpp_files,
            .flags = ctx.dupeGlobalFlags(),
            .language = .cpp,
        });

        lib.addIncludePath(tablegenerated_incs);
        lib.addIncludePath(ctx.llvmInc("Option"));
        lib.linkLibrary(llvm_support_lib);
        break :block lib;
    };

    const llvm_target_parser_lib = block: {
        const lib = ctx.b.addLibrary(.{
            .name = "llvmTargetParser",
            .root_module = ctx.makeModule(),
        });
        lib.addCSourceFiles(.{
            .root = ctx.llvmLib("TargetParser"),
            .files = sources.llvm_target_parser_lib_cpp_files,
            .flags = ctx.dupeGlobalFlags(),
            .language = .cpp,
        });

        lib.addIncludePath(tablegenerated_incs);
        lib.linkLibrary(llvm_support_lib);
        break :block lib;
    };

    const llvm_binary_format_lib = block: {
        const lib = ctx.b.addLibrary(.{
            .name = "llvmBinaryFormat",
            .root_module = ctx.makeModule(),
        });
        lib.addCSourceFiles(.{
            .root = ctx.llvmLib("BinaryFormat"),
            .files = sources.llvm_binary_format_lib_cpp_files,
            .flags = ctx.dupeGlobalFlags(),
            .language = .cpp,
        });

        lib.addIncludePath(tablegenerated_incs);
        lib.linkLibrary(llvm_support_lib);
        lib.linkLibrary(llvm_target_parser_lib);
        break :block lib;
    };

    const llvm_bitstream_reader_lib = block: {
        const lib = ctx.b.addLibrary(.{
            .name = "llvmBitstreamReader",
            .root_module = ctx.makeModule(),
        });
        lib.addCSourceFiles(.{
            .root = ctx.llvmLib("Bitstream/Reader"),
            .files = sources.llvm_bitstream_reader_lib_cpp_files,
            .flags = ctx.dupeGlobalFlags(),
            .language = .cpp,
        });

        lib.addIncludePath(tablegenerated_incs);
        lib.addIncludePath(ctx.llvmLib("Bitcode"));
        lib.addIncludePath(ctx.llvmLib("Bitstream"));
        lib.linkLibrary(llvm_support_lib);
        break :block lib;
    };

    const llvm_bitcode_reader_lib = block: {
        const lib = ctx.b.addLibrary(.{
            .name = "llvmBitcodeReader",
            .root_module = ctx.makeModule(),
        });
        lib.addCSourceFiles(.{
            .root = ctx.llvmLib("Bitcode/Reader"),
            .files = sources.llvm_bitcode_reader_lib_cpp_files,
            .flags = ctx.dupeGlobalFlags(),
            .language = .cpp,
        });

        lib.addIncludePath(tablegenerated_incs);
        lib.addIncludePath(ctx.llvmLib("Bitcode"));
        lib.addIncludePath(ctx.llvmLib("Bitstream"));
        lib.linkLibrary(llvm_support_lib);
        lib.linkLibrary(llvm_core_lib);
        lib.linkLibrary(llvm_target_parser_lib);
        lib.linkLibrary(llvm_bitstream_reader_lib);
        break :block lib;
    };

    const llvm_object_lib = block: {
        const lib = ctx.b.addLibrary(.{
            .name = "llvmObject",
            .root_module = ctx.makeModule(),
        });
        lib.addCSourceFiles(.{
            .root = ctx.llvmLib("Object"),
            .files = sources.llvm_object_lib_cpp_files,
            .flags = ctx.dupeGlobalFlags(),
            .language = .cpp,
        });

        lib.addIncludePath(tablegenerated_incs);
        lib.linkLibrary(llvm_core_lib);
        lib.linkLibrary(llvm_bitcode_reader_lib);
        break :block lib;
    };

    const llvm_debug_info_msf_lib = block: {
        const lib = ctx.b.addLibrary(.{
            .name = "llvmDebugInfoMSF",
            .root_module = ctx.makeModule(),
        });
        lib.addCSourceFiles(.{
            .root = ctx.llvmLib("DebugInfo/MSF"),
            .files = sources.llvm_debug_info_msf_lib_cpp_files,
            .flags = ctx.dupeGlobalFlags(),
            .language = .cpp,
        });

        lib.addIncludePath(tablegenerated_incs);
        lib.addIncludePath(ctx.llvmInc("DebugInfo/MSF"));
        lib.linkLibrary(llvm_support_lib);
        break :block lib;
    };

    const llvm_debug_info_codeview_lib = block: {
        const lib = ctx.b.addLibrary(.{
            .name = "llvmDebugInfoCodeView",
            .root_module = ctx.makeModule(),
        });
        lib.addCSourceFiles(.{
            .root = ctx.llvmLib("DebugInfo/CodeView"),
            .files = sources.llvm_debug_info_codeview_lib_cpp_files,
            .flags = ctx.dupeGlobalFlags(),
            .language = .cpp,
        });

        lib.addIncludePath(tablegenerated_incs);
        lib.addIncludePath(ctx.llvmInc("DebugInfo/CodeView"));
        lib.linkLibrary(llvm_support_lib);
        break :block lib;
    };

    const llvm_debug_info_btf_lib = block: {
        const lib = ctx.b.addLibrary(.{
            .name = "llvmDebugInfoBTF",
            .root_module = ctx.makeModule(),
        });
        lib.addCSourceFiles(.{
            .root = ctx.llvmLib("DebugInfo/BTF"),
            .files = sources.llvm_debug_info_btf_lib_cpp_files,
            .flags = ctx.dupeGlobalFlags(),
            .language = .cpp,
        });

        lib.addIncludePath(tablegenerated_incs);
        lib.addIncludePath(ctx.llvmInc("DebugInfo/BTF"));
        lib.linkLibrary(llvm_support_lib);
        break :block lib;
    };

    const llvm_debug_info_pdb_lib = block: {
        const lib = ctx.b.addLibrary(.{
            .name = "llvmDebugInfoPDB",
            .root_module = ctx.makeModule(),
        });
        lib.addCSourceFiles(.{
            .root = ctx.llvmLib("DebugInfo/PDB"),
            .files = sources.llvm_debug_info_pdb_lib_cpp_files,
            .flags = ctx.dupeGlobalFlags(),
            .language = .cpp,
        });

        // TODO: support DIA sdk for pdb?
        lib.addIncludePath(ctx.llvmInc("DebugInfo/PDB"));
        lib.addCSourceFiles(.{
            .root = ctx.llvmLib("DebugInfo/PDB"),
            .files = sources.llvm_debug_info_pdb_native_folder_cpp_files,
            .flags = ctx.dupeGlobalFlags(),
            .language = .cpp,
        });

        lib.addIncludePath(tablegenerated_incs);
        lib.addIncludePath(ctx.llvmInc("DebugInfo/PDB"));

        lib.linkLibrary(llvm_support_lib);
        lib.linkLibrary(llvm_object_lib);
        lib.linkLibrary(llvm_binary_format_lib);
        lib.linkLibrary(llvm_debug_info_codeview_lib);
        lib.linkLibrary(llvm_debug_info_msf_lib);
        break :block lib;
    };

    const llvm_debug_info_dwarf_lib = block: {
        const lib = ctx.b.addLibrary(.{
            .name = "llvmDebugInfoDWARF",
            .root_module = ctx.makeModule(),
        });
        lib.addCSourceFiles(.{
            .root = ctx.llvmLib("DebugInfo/DWARF"),
            .files = sources.llvm_debug_info_dwarf_lib_cpp_files,
            .flags = ctx.dupeGlobalFlags(),
            .language = .cpp,
        });

        lib.addIncludePath(tablegenerated_incs);
        lib.addIncludePath(ctx.llvmInc("DebugInfo/DWARF"));
        lib.addIncludePath(ctx.llvmInc("DebugInfo"));
        lib.linkLibrary(llvm_binary_format_lib);
        lib.linkLibrary(llvm_object_lib);
        lib.linkLibrary(llvm_support_lib);
        lib.linkLibrary(llvm_target_parser_lib);
        break :block lib;
    };

    const llvm_debug_info_symbolize_lib = block: {
        const lib = ctx.b.addLibrary(.{
            .name = "llvmDebugInfoSymbolize",
            .root_module = ctx.makeModule(),
        });
        lib.addCSourceFiles(.{
            .root = ctx.llvmLib("DebugInfo/Symbolize"),
            .files = sources.llvm_debug_info_symbolize_lib_cpp_files,
            .flags = ctx.dupeGlobalFlags(),
            .language = .cpp,
        });

        lib.addIncludePath(tablegenerated_incs);
        lib.addIncludePath(ctx.llvmLib("DebugInfo/Symbolize"));
        lib.linkLibrary(llvm_debug_info_dwarf_lib);
        lib.linkLibrary(llvm_debug_info_pdb_lib);
        lib.linkLibrary(llvm_debug_info_btf_lib);
        lib.linkLibrary(llvm_object_lib);
        lib.linkLibrary(llvm_support_lib);
        lib.linkLibrary(llvm_demangle_lib);
        lib.linkLibrary(llvm_target_parser_lib);
        break :block lib;
    };

    const llvm_profile_data_lib = block: {
        const lib = ctx.b.addLibrary(.{
            .name = "llvmProfileData",
            .root_module = ctx.makeModule(),
        });
        lib.addCSourceFiles(.{
            .root = ctx.llvmLib("ProfileData"),
            .files = sources.llvm_profile_data_lib_cpp_files,
            .flags = ctx.dupeGlobalFlags(),
            .language = .cpp,
        });

        lib.addIncludePath(tablegenerated_incs);
        lib.linkLibrary(llvm_bitstream_reader_lib);
        lib.linkLibrary(llvm_core_lib);
        lib.linkLibrary(llvm_object_lib);
        lib.linkLibrary(llvm_support_lib);
        lib.linkLibrary(llvm_demangle_lib);
        lib.linkLibrary(llvm_debug_info_symbolize_lib);
        lib.linkLibrary(llvm_debug_info_dwarf_lib);
        lib.linkLibrary(llvm_target_parser_lib);
        break :block lib;
    };

    const llvm_analysis_lib = block: {
        const lib = ctx.b.addLibrary(.{
            .name = "llvmAnalysis",
            .root_module = ctx.makeModule(),
        });
        lib.addCSourceFiles(.{
            .root = ctx.llvmLib("Analysis"),
            .files = sources.llvm_analysis_lib_cpp_files,
            .flags = ctx.dupeGlobalFlags(),
            .language = .cpp,
        });

        lib.addIncludePath(tablegenerated_incs);
        lib.linkLibrary(llvm_binary_format_lib);
        lib.linkLibrary(llvm_core_lib);
        lib.linkLibrary(llvm_object_lib);
        lib.linkLibrary(llvm_profile_data_lib);
        lib.linkLibrary(llvm_support_lib);
        lib.linkLibrary(llvm_target_parser_lib);
        break :block lib;
    };

    const llvm_transforms_utils_lib = block: {
        const lib = ctx.b.addLibrary(.{
            .name = "llvmFrontendOpenMP",
            .root_module = ctx.makeModule(),
        });
        lib.addCSourceFiles(.{
            .root = ctx.llvmLib("Transforms/Utils"),
            .files = sources.llvm_transforms_utils_lib_cpp_files,
            .flags = ctx.dupeGlobalFlags(),
            .language = .cpp,
        });

        lib.addIncludePath(tablegenerated_incs);
        lib.addIncludePath(ctx.llvmInc("Transforms"));
        lib.addIncludePath(ctx.llvmInc("Transforms/Utils"));
        lib.linkLibrary(llvm_analysis_lib);
        lib.linkLibrary(llvm_core_lib);
        lib.linkLibrary(llvm_support_lib);
        lib.linkLibrary(llvm_target_parser_lib);
        break :block lib;
    };

    const llvm_frontend_openmp_lib = block: {
        const lib = ctx.b.addLibrary(.{
            .name = "llvmFrontendOpenMP",
            .root_module = ctx.makeModule(),
        });
        lib.addCSourceFiles(.{
            .root = ctx.llvmLib("Frontend/OpenMP"),
            .files = sources.llvm_frontend_openmp_lib_cpp_files,
            .flags = ctx.dupeGlobalFlags(),
            .language = .cpp,
        });

        lib.addIncludePath(tablegenerated_incs);
        lib.addIncludePath(ctx.llvmInc("Frontend"));
        lib.addIncludePath(ctx.llvmInc("Frontend/OpenMP"));
        lib.linkLibrary(llvm_core_lib);
        lib.linkLibrary(llvm_support_lib);
        lib.linkLibrary(llvm_target_parser_lib);
        lib.linkLibrary(llvm_transforms_utils_lib);
        lib.linkLibrary(llvm_analysis_lib);
        lib.linkLibrary(llvm_demangle_lib);
        break :block lib;
    };

    return LLVMExportedArtifacts{
        .option_lib = llvm_option_lib,
        .support_lib = llvm_support_lib,
        .target_parser_lib = llvm_target_parser_lib,
        .frontend_openmp_lib = llvm_frontend_openmp_lib,
        //.all_targets_infos_lib = ,

        .public_config_header = public_config_header,
        //.private_config_header = private_config_header,
        .targets_def_config_header = targets_def_config_header,
        .host_component_tblgen_exe = host_component_tblgen_exe,
        .abi_breaking_config_header = abi_breaking_config_header,
        .features_inc_config_header = features_inc_config_header,
        .host_component_support_lib = host_component_support_lib,
        .host_component_demangle_lib = host_component_demangle_lib,
        .host_component_tablegen_lib = host_component_tablegen_lib,
        .asm_parsers_def_config_header = asm_parsers_def_config_header,
        .target_mcas_def_config_header = target_mcas_def_config_header,
        .asm_printers_def_config_header = asm_printers_def_config_header,
        .disassemblers_def_config_header = disassemblers_def_config_header,
        .target_exegesis_def_config_header = target_exegesis_def_config_header,

        .tablegenerated_incs = tablegenerated_incs,
    };
}

fn buildDemangle(ctx: *const Context, module_options: std.Build.Module.CreateOptions) *Compile {
    const out = addLLVMLibrary(ctx, .{
        .name = "demangle",
        .root_module = ctx.b.createModule(module_options),
        .linkage = .static,
    });
    out.addCSourceFiles(.{
        .root = ctx.llvmLib("Demangle"),
        .files = sources.demangle_cpp_files,
        .language = .cpp,
        .flags = ctx.dupeGlobalFlags(),
    });
    return out;
}

fn getLLVMNativeArch(arch: std.Target.Cpu.Arch) []const u8 {
    return switch (arch) {
        .x86, .x86_64 => "X86",
        .sparc => "sparc",
        .sparc64 => "sparc64",
        .powerpc, .powerpcle, .powerpc64le, .powerpc64 => "PowerPC",
        .aarch64, .aarch64_be => "AArch64",
        .arm => "ARM",
        .avr => "AVR",
        .mips, .mipsel, .mips64, .mips64el => "Mips",
        .xcore => "XCore",
        .msp430 => "MSP430",
        .hexagon => "Hexagon",
        .s390x => "SystemZ",
        .wasm32, .wasm64 => "WebAssembly",
        .riscv32, .riscv64 => "RISCV",
        .m68k => "M68k",
        .loongarch32, .loongarch64 => "LoongArch",
        else => @panic("Unsupported architecture passed to getLLVMNativeArch"),
    };
}

fn buildSupport(
    ctx: *const Context,
    module_options: std.Build.Module.CreateOptions,
) *std.Build.Step.Compile {
    const support_lib = addLLVMLibrary(ctx, .{
        .name = "support",
        .root_module = ctx.b.createModule(module_options),
        .linkage = .static,
    });

    var flags = ctx.makeFlags();

    // const target_os_tag = ctx.module_opts.target.?.result.os.tag;
    const host_os_tag = ctx.b.graph.host.result.os.tag;
    const target_os_tag = host_os_tag; // just building for host for now, for use in tblgen
    if (target_os_tag == .windows) {
        const libs_windows = &[_][]const u8{
            "psapi",
            "shell32",
            "ole32",
            "uuid",
            "advapi32",
            "ws2_32",
            "ntdll",
        };
        for (libs_windows) |lib| {
            support_lib.linkSystemLibrary(lib);
        }
    } else if (Context.osIsUnixLike(host_os_tag)) {
        // link llvm atomic lib
        // link llvm pthread lib

        if (Context.osIsUnixLike(target_os_tag) and target_os_tag != .haiku) {
            support_lib.linkSystemLibrary("m");
        }
        if (target_os_tag == .haiku) {
            support_lib.linkSystemLibrary("bsd");
            support_lib.linkSystemLibrary("network");
            flags.append("-D_BSD_SOURCE") catch @panic("OOM");
        }
        if (target_os_tag == .fuchsia) {
            support_lib.linkSystemLibrary("zircon");
        }
    }

    // TODO: Z3 link libraries here if enabled

    support_lib.addCSourceFiles(.{
        .language = .cpp,
        .files = sources.llvm_support_lib_cpp_files,
        .root = ctx.llvmLib("Support"),
        .flags = flags.toOwnedSlice() catch @panic("OOM"),
    });
    support_lib.addCSourceFiles(.{
        .language = .c,
        .files = sources.llvm_support_lib_c_files,
        .root = ctx.llvmLib("Support"),
        .flags = flags.toOwnedSlice() catch @panic("OOM"),
    });
    support_lib.addIncludePath(ctx.llvmInc("Support"));
    support_lib.addIncludePath(ctx.llvmInc("ADT"));
    support_lib.addIncludePath(ctx.llvmLib("Support/Windows"));
    support_lib.addIncludePath(ctx.llvmLib("Support/Unix"));

    if (ctx.targets.zlib) |zlib| {
        support_lib.linkLibrary(zlib);
    } else {
        std.debug.assert(!ctx.opts.llvm_enable_zlib);
    }

    return support_lib;
}

// "${ALLOCATOR_FILES}",
// "$<TARGET_OBJECTS:LLVMSupportBlake3>",

// "ADDITIONAL_HEADER_DIRS",
// "Unix",
// "Windows",
// "${LLVM_MAIN_INCLUDE_DIR}/llvm/ADT",
// "${LLVM_MAIN_INCLUDE_DIR}/llvm/Support",
// "${Backtrace_INCLUDE_DIRS}",

// "LINK_LIBS",
// "${system_libs} ${imported_libs} ${delayload_flags}",

// "LINK_COMPONENTS",
// "Demangle",
