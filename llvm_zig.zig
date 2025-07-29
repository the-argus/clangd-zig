const std = @import("std");
const builtin = @import("builtin");

const Context = @import("build.zig").Context;
const RunArtifactResultFile = @import("build.zig").RunArtifactResultFile;
const ABIBreakingChecks = @import("build.zig").ABIBreakingChecks;
const version = @import("build.zig").version;
const version_string = @import("build.zig").version_string;

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

const TableGenOptions = struct {
    source_file: std.Build.LazyPath,
    output_filename: []const u8,
    args: []const []const u8 = &.{},
    // these directories will have -I prefixing them and then be passed as args
    include_dir_args: []const std.Build.LazyPath = &.{},
};

fn clangTablegen(
    ctx: *Context,
    options: TableGenOptions,
) RunArtifactResultFile {
    const tblgen_invocation = ctx.b.addRunArtifact(ctx.targets.llvm_tblgen_exe.?);
    tblgen_invocation.addFileArg(options.source_file);
    const generated_file = tblgen_invocation.addPrefixedOutputFileArg("-o", options.output_filename);
    tblgen_invocation.addArgs(options.args);
    for (options.include_dir_args) |include_dir| {
        tblgen_invocation.addPrefixedDirectoryArg("-I", include_dir);
    }
    return RunArtifactResultFile{
        .outputted_file = generated_file,
        .step = &tblgen_invocation.step,
    };
}

/// Fills out all the fields in Context.targets that start with llvm_*, pulling
/// from Context.options
pub fn build(ctx: *Context) void {
    // create tablegen executable artifact so fn clangTablegen can use it
    ctx.targets.llvm_tblgen_exe = ctx.b.addExecutable(.{
        .name = "tblgen",
        .root_module = ctx.makeHostModule(), // this exe runs on the host
    });
    ctx.targets.llvm_tblgen_exe.?.addCSourceFiles(.{
        .root = ctx.paths.clang.utils.tablegen.path,
        .files = @import("clangd_sources.zig").tablegen_cpp_files,
        .flags = &.{},
        .language = .cpp,
    });
    ctx.targets.llvm_tblgen_exe.?.linkLibCpp();

    // generate RegularKeywordAttrInfo.inc
    const regular_keyword_attr_info_result_file = clangTablegen(ctx, .{
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

    const abi_breaking_opts = ctx.paths.llvm.include.llvm.config.llvm_abi_breaking_config_header.makeOptions();
    ctx.targets.llvm_abi_breaking_config_header = ctx.b.addConfigHeader(abi_breaking_opts, .{
        .LLVM_ENABLE_REVERSE_ITERATION = ctx.opts.llvm_reverse_iteration,
        .LLVM_ENABLE_ABI_BREAKING_CHECKS = std.enums.tagName(
            ABIBreakingChecks,
            ctx.opts.llvm_abi_breaking_checks,
        ),
    });

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
        // targets included in llvm_all_targets
        // NOTE: this is just the default, all regular targets enabled. options
        // to really customize this are not exposed in this build script yet
        .LLVM_HAS_AARCH64_TARGET = true,
        .LLVM_HAS_AMDGPU_TARGET = true,
        .LLVM_HAS_ARM_TARGET = true,
        .LLVM_HAS_AVR_TARGET = true,
        .LLVM_HAS_BPF_TARGET = true,
        .LLVM_HAS_HEXAGON_TARGET = true,
        .LLVM_HAS_LANAI_TARGET = true,
        .LLVM_HAS_LOONGARCH_TARGET = true,
        .LLVM_HAS_MIPS_TARGET = true,
        .LLVM_HAS_MSP430_TARGET = true,
        .LLVM_HAS_NVPTX_TARGET = true,
        .LLVM_HAS_POWERPC_TARGET = true,
        .LLVM_HAS_RISCV_TARGET = true,
        .LLVM_HAS_SPARC_TARGET = true,
        .LLVM_HAS_SPIRV_TARGET = true,
        .LLVM_HAS_SYSTEMZ_TARGET = true,
        .LLVM_HAS_VE_TARGET = true,
        .LLVM_HAS_WEBASSEMBLY_TARGET = true,
        .LLVM_HAS_X86_TARGET = true,
        .LLVM_HAS_XCORE_TARGET = true,

        // experimental targets that aren't in llvm_all_targets
        .LLVM_HAS_ARC_TARGET = false,
        .LLVM_HAS_CSKY_TARGET = false,
        .LLVM_HAS_DIRECTX_TARGET = false,
        .LLVM_HAS_M68K_TARGET = false,
        .LLVM_HAS_XTENSA_TARGET = false,

        .LLVM_ON_UNIX = osIsUnixLike(builtin.os.tag),
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
        .LLVM_ENABLE_ZSTD = false,
        .LLVM_HAVE_TFLITE = false,
        .HAVE_SYSEXITS_H = true,
        .LLVM_BUILD_LLVM_DYLIB = false,
        .LLVM_BUILD_SHARED_LIBS = false,
        .LLVM_FORCE_USE_OLD_TOOLCHAIN = false,
        .LLVM_ENABLE_DIA_SDK = false,
        .LLVM_ENABLE_PLUGINS = false,
        .LLVM_HAS_LOGF128 = false,
    });
}

fn osIsUnixLike(os: std.Target.Os.Tag) bool {
    return switch (os) {
        .linux, .macos, .fuchsia => true,
        else => false,
    };
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
