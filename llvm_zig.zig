const std = @import("std");
const builtin = @import("builtin");

const Context = @import("build.zig").Context;
const ABIBreakingChecks = @import("build.zig").ABIBreakingChecks;
const version = @import("build.zig").version;
const version_string = @import("build.zig").version_string;
const sources = @import("clangd_sources.zig");

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
fn llvmTargetToolString(ctx: *Context, str: []const u8) []const u8 {
    return ctx.b.fmt("LLVMInitialize{s}{s}", .{ llvm_native_arch, str });
}

/// Fills out all the fields in Context.targets that start with llvm_*, pulling
/// from Context.options. called from root build.zig
pub fn build(ctx: *Context) void {
    const abi_breaking_opts = ctx.paths.llvm.include.llvm.config.llvm_abi_breaking_config_header.makeOptions();
    ctx.targets.llvm_abi_breaking_config_header = ctx.b.addConfigHeader(abi_breaking_opts, .{
        .LLVM_ENABLE_REVERSE_ITERATION = ctx.opts.llvm_reverse_iteration,
        .LLVM_ENABLE_ABI_BREAKING_CHECKS = std.enums.tagName(
            ABIBreakingChecks,
            ctx.opts.llvm_abi_breaking_checks,
        ),
    });

    ctx.targets.llvm_features_inc_config_header = ctx.b.addConfigHeader(
        .{ .style = .{ .cmake = ctx.paths.clang_tools_extra.clangd.path.path(ctx.b, "Features.inc.in") }, .include_path = "Features.inc" },
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
    ctx.targets.llvm_public_config_header = ctx.b.addConfigHeader(public_opts, .{
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
            ctx.targets.llvm_public_config_header.?.addValue(field_name, bool, is_supported);

            if (is_supported) {
                const Set = std.static_string_map.StaticStringMap(void);
                supported_targets_writer.print("LLVM_TARGET({s})\n", .{target_field.name}) catch @panic("OOM, or format error");
                // NOTE: in normal LLVM there is a check to make sure llvm/lib/Target/${targetname}/*AsmPrinter.cpp exists, but all targets currently have one so we just skip that
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

    ctx.targets.llvm_targets_def_config_header = ctx.b.addConfigHeader(
        ctx.paths.llvm.include.llvm.config.llvm_targets_def_config_header.makeOptions(),
        .{
            .LLVM_ENUM_TARGETS = supported_targets.toOwnedSlice() catch @panic("OOM"),
        },
    );
    ctx.targets.llvm_asm_printers_def_config_header = ctx.b.addConfigHeader(
        ctx.paths.llvm.include.llvm.config.llvm_asm_printers_def_config_header.makeOptions(),
        .{
            .LLVM_ENUM_ASM_PRINTERS = enum_asm_printers.toOwnedSlice() catch @panic("OOM"),
        },
    );
    ctx.targets.llvm_asm_parsers_def_config_header = ctx.b.addConfigHeader(
        ctx.paths.llvm.include.llvm.config.llvm_asm_parsers_def_config_header.makeOptions(),
        .{
            .LLVM_ENUM_ASM_PARSERS = enum_asm_parsers.toOwnedSlice() catch @panic("OOM"),
        },
    );
    ctx.targets.llvm_disassemblers_def_config_header = ctx.b.addConfigHeader(
        ctx.paths.llvm.include.llvm.config.llvm_disassemblers_def_config_header.makeOptions(),
        .{
            .LLVM_ENUM_DISASSEMBLERS = enum_disassemblers.toOwnedSlice() catch @panic("OOM"),
        },
    );
    ctx.targets.llvm_target_exegesis_def_config_header = ctx.b.addConfigHeader(
        ctx.paths.llvm.include.llvm.config.llvm_target_exegesis_def_config_header.makeOptions(),
        .{
            .LLVM_ENUM_EXEGESIS = enum_exegesis.toOwnedSlice() catch @panic("OOM"),
        },
    );
    ctx.targets.llvm_target_mcas_def_config_header = ctx.b.addConfigHeader(
        ctx.paths.llvm.include.llvm.config.llvm_target_mcas_def_config_header.makeOptions(),
        .{
            .LLVM_ENUM_TARGETMCAS = enum_mcas.toOwnedSlice() catch @panic("OOM"),
        },
    );

    const private_opts = ctx.paths.llvm.include.llvm.config.llvm_private_config_header.makeOptions();
    const target = ctx.module_opts.target.?.result;
    ctx.targets.llvm_private_config_header = ctx.b.addConfigHeader(private_opts, .{
        .BUG_REPORT_URL = "https://github.com/llvm/llvm-project/issues/",
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

    ctx.targets.llvm_host_component_demangle_lib = ctx.addLLVMLibrary(.{
        .name = "demangle",
        .root_module = ctx.makeHostModule(),
        .linkage = .static,
    });
    ctx.targets.llvm_host_component_demangle_lib.?.addCSourceFiles(.{
        .root = ctx.paths.llvm.lib.demangle.path,
        .files = sources.demangle_cpp_files,
        .language = .cpp,
        .flags = ctx.dupeGlobalFlags(),
    });

    // depends on demangle lib along with the abi-breaking, public and private config headers
    @import("llvm_zig_support.zig").build(ctx);

    // build llvm tablegen lib
    ctx.targets.llvm_host_component_tablegen_lib = ctx.addLLVMLibrary(.{
        .name = "LLVMTableGen",
        .root_module = ctx.makeHostModule(),
    });
    ctx.targets.llvm_host_component_tablegen_lib.?.addCSourceFiles(.{
        .root = ctx.paths.llvm.lib.tablegen.path,
        .files = sources.llvm_tablegen_lib_cpp_files,
        .flags = ctx.dupeGlobalFlags(),
        .language = .cpp,
    });
    ctx.targets.llvm_host_component_tablegen_lib.?.addIncludePath(ctx.paths.llvm.lib.tablegen.path);
    ctx.targets.llvm_host_component_tablegen_lib.?.linkLibrary(ctx.targets.llvm_host_component_support_lib.?);

    // build llvm/utils/TableGen/Basic
    ctx.targets.llvm_host_component_tblgen_basic_lib = ctx.addLLVMObject(.{
        .name = "LLVMTableGenBasic",
        .root_module = ctx.makeHostModule(),
    });
    ctx.targets.llvm_host_component_tblgen_basic_lib.?.addCSourceFiles(.{
        .root = ctx.paths.llvm.utils.tablegen.basic.path,
        .files = sources.llvm_tablegen_basic_lib_cpp_files,
        .flags = ctx.dupeGlobalFlags(),
        .language = .cpp,
    });
    ctx.targets.llvm_host_component_tblgen_basic_lib.?.linkLibrary(ctx.targets.llvm_host_component_tablegen_lib.?);
    ctx.targets.llvm_host_component_tblgen_basic_lib.?.installHeadersDirectory(ctx.paths.llvm.utils.tablegen.basic.path, "Basic/", .{});

    // create llvm-min-tablgen to bootstrap regular llvm tablegen
    ctx.targets.llvm_host_component_tblgen_min_exe = ctx.addLLVMExecutable(.{
        .name = "llvm-min-tablgen",
        .root_module = ctx.makeHostModule(),
    });
    ctx.targets.llvm_host_component_tblgen_min_exe.?.addCSourceFiles(.{
        .root = ctx.paths.llvm.utils.tablegen.path,
        .flags = ctx.dupeGlobalFlags(),
        .files = sources.llvm_min_tablegen_cpp_files,
        .language = .cpp,
    });
    ctx.targets.llvm_host_component_tblgen_min_exe.?.addObject(ctx.targets.llvm_host_component_tblgen_basic_lib.?);

    const llvm_min_tablegenerated_incs = block: {
        const writefile_step = ctx.b.addWriteFiles();
        for (ctx.llvm_min_tablegen_files) |desc| {
            ctx.addTablegenOutputFileToWriteFileStep(writefile_step, ctx.targets.llvm_host_component_tblgen_min_exe.?, desc);
        }
        break :block writefile_step.getDirectory();
    };

    // build llvm/utils/TableGen/Common
    ctx.targets.llvm_host_component_tblgen_common_lib = ctx.addLLVMObject(.{
        .name = "LLVMTableGenCommon",
        .root_module = ctx.makeHostModule(),
    });
    ctx.targets.llvm_host_component_tblgen_common_lib.?.addCSourceFiles(.{
        .root = ctx.paths.llvm.utils.tablegen.common.path,
        .files = sources.llvm_tablegen_common_lib_cpp_files,
        .flags = ctx.dupeGlobalFlags(),
        .language = .cpp,
    });
    ctx.targets.llvm_host_component_tblgen_common_lib.?.addIncludePath(llvm_min_tablegenerated_incs);
    // installHeadersDirectory is not recursive
    ctx.targets.llvm_host_component_tblgen_common_lib.?.installHeadersDirectory(ctx.paths.llvm.utils.tablegen.common.path, "Common/", .{});
    ctx.targets.llvm_host_component_tblgen_common_lib.?.installHeadersDirectory(ctx.paths.llvm.utils.tablegen.common.globalisel.path, "Common/GlobalISel/", .{});
    // TODO: why is this necessary? installHeadersDirectory should add these folders to the include path, right?
    ctx.targets.llvm_host_component_tblgen_common_lib.?.addIncludePath(ctx.paths.llvm.utils.tablegen.path);

    // link libLLVMTableGen lib into executable
    ctx.targets.llvm_host_component_tblgen_exe = ctx.addLLVMExecutable(.{
        .name = "llvm-tblgen",
        .root_module = ctx.makeHostModule(),
    });
    ctx.targets.llvm_host_component_tblgen_exe.?.addCSourceFiles(.{
        .root = ctx.paths.llvm.utils.tablegen.path,
        .files = sources.llvm_tablegen_cpp_files,
        .flags = ctx.dupeGlobalFlags(),
        .language = .cpp,
    });
    ctx.targets.llvm_host_component_tblgen_exe.?.addIncludePath(llvm_min_tablegenerated_incs);
    ctx.targets.llvm_host_component_tblgen_exe.?.addObject(ctx.targets.llvm_host_component_tblgen_common_lib.?);
    ctx.targets.llvm_host_component_tblgen_exe.?.addObject(ctx.targets.llvm_host_component_tblgen_basic_lib.?);

    {
        const writefile_step = ctx.b.addWriteFiles();
        for (ctx.llvm_tablegen_files) |desc| {
            ctx.addTablegenOutputFileToWriteFileStep(writefile_step, ctx.targets.llvm_host_component_tblgen_exe.?, desc);
        }
        // also do everything that tablegen min had
        for (ctx.llvm_min_tablegen_files) |desc| {
            ctx.addTablegenOutputFileToWriteFileStep(writefile_step, ctx.targets.llvm_host_component_tblgen_exe.?, desc);
        }
        ctx.targets.llvm_tablegenerated_incs = writefile_step.getDirectory();
    }
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
