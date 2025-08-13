// This file provides a zig version of the cmake functionality found in
// llvm/lib/Support/CMakeLists.txt

const std = @import("std");

const Context = @import("build.zig").Context;

pub fn build(
    ctx: *Context,
    module_options: std.Build.Module.CreateOptions,
) *std.Build.Step.Compile {
    const support_lib = ctx.addLLVMLibrary(.{
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
        .files = cpp_files,
        .root = ctx.paths.llvm.lib.support.path,
        .flags = flags.toOwnedSlice() catch @panic("OOM"),
    });
    support_lib.addCSourceFiles(.{
        .language = .c,
        .files = c_files,
        .root = ctx.paths.llvm.lib.support.path,
        .flags = flags.toOwnedSlice() catch @panic("OOM"),
    });
    support_lib.addIncludePath(ctx.paths.llvm.include.llvm.support.path);
    support_lib.addIncludePath(ctx.paths.llvm.include.llvm.adt.path);
    support_lib.addIncludePath(ctx.paths.llvm.lib.support.windows.path);
    support_lib.addIncludePath(ctx.paths.llvm.lib.support.unix.path);

    if (ctx.targets.zlib) |zlib| {
        support_lib.linkLibrary(zlib);
    } else {
        std.debug.assert(!ctx.opts.llvm_enable_zlib);
    }

    return support_lib;
}

const cpp_files = &.{
    "ABIBreak.cpp",
    "AMDGPUMetadata.cpp",
    "APFixedPoint.cpp",
    "APFloat.cpp",
    "APInt.cpp",
    "APSInt.cpp",
    "ARMBuildAttributes.cpp",
    "AArch64BuildAttributes.cpp",
    "ARMAttributeParser.cpp",
    "ARMWinEH.cpp",
    "Allocator.cpp",
    "AutoConvert.cpp",
    "Base64.cpp",
    "BalancedPartitioning.cpp",
    "BinaryStreamError.cpp",
    "BinaryStreamReader.cpp",
    "BinaryStreamRef.cpp",
    "BinaryStreamWriter.cpp",
    "BlockFrequency.cpp",
    "BranchProbability.cpp",
    "BuryPointer.cpp",
    "CachePruning.cpp",
    "Caching.cpp",
    "circular_raw_ostream.cpp",
    "Chrono.cpp",
    "COM.cpp",
    "CodeGenCoverage.cpp",
    "CommandLine.cpp",
    "Compression.cpp",
    "CRC.cpp",
    "ConvertUTF.cpp",
    "ConvertEBCDIC.cpp",
    "ConvertUTFWrapper.cpp",
    "CrashRecoveryContext.cpp",
    "CSKYAttributes.cpp",
    "CSKYAttributeParser.cpp",
    "DataExtractor.cpp",
    "Debug.cpp",
    "DebugCounter.cpp",
    "DeltaAlgorithm.cpp",
    "DeltaTree.cpp",
    "DivisionByConstantInfo.cpp",
    "DAGDeltaAlgorithm.cpp",
    "DJB.cpp",
    "DynamicAPInt.cpp",
    "ELFAttributeParser.cpp",
    "ELFAttributes.cpp",
    "Error.cpp",
    "ErrorHandling.cpp",
    "ExponentialBackoff.cpp",
    "ExtensibleRTTI.cpp",
    "FileCollector.cpp",
    "FileUtilities.cpp",
    "FileOutputBuffer.cpp",
    "FloatingPointMode.cpp",
    "FoldingSet.cpp",
    "FormattedStream.cpp",
    "FormatVariadic.cpp",
    "GlobPattern.cpp",
    "GraphWriter.cpp",
    "HexagonAttributeParser.cpp",
    "HexagonAttributes.cpp",
    "InitLLVM.cpp",
    "InstructionCost.cpp",
    "IntEqClasses.cpp",
    "IntervalMap.cpp",
    "JSON.cpp",
    "KnownBits.cpp",
    "LEB128.cpp",
    "LineIterator.cpp",
    "Locale.cpp",
    "LockFileManager.cpp",
    "ManagedStatic.cpp",
    "MathExtras.cpp",
    "MemAlloc.cpp",
    "MemoryBuffer.cpp",
    "MemoryBufferRef.cpp",
    "ModRef.cpp",
    "MD5.cpp",
    "MSP430Attributes.cpp",
    "MSP430AttributeParser.cpp",
    "NativeFormatting.cpp",
    "OptimizedStructLayout.cpp",
    "Optional.cpp",
    "OptionStrCmp.cpp",
    "PGOOptions.cpp",
    "Parallel.cpp",
    "PluginLoader.cpp",
    "PrettyStackTrace.cpp",
    "RandomNumberGenerator.cpp",
    "Regex.cpp",
    "RewriteBuffer.cpp",
    "RewriteRope.cpp",
    "RISCVAttributes.cpp",
    "RISCVAttributeParser.cpp",
    "RISCVISAUtils.cpp",
    "ScaledNumber.cpp",
    "ScopedPrinter.cpp",
    "SHA1.cpp",
    "SHA256.cpp",
    "Signposts.cpp",
    "SipHash.cpp",
    "SlowDynamicAPInt.cpp",
    "SmallPtrSet.cpp",
    "SmallVector.cpp",
    "SourceMgr.cpp",
    "SpecialCaseList.cpp",
    "Statistic.cpp",
    "StringExtras.cpp",
    "StringMap.cpp",
    "StringSaver.cpp",
    "StringRef.cpp",
    "SuffixTreeNode.cpp",
    "SuffixTree.cpp",
    "SystemUtils.cpp",
    "TarWriter.cpp",
    "ThreadPool.cpp",
    "TimeProfiler.cpp",
    "Timer.cpp",
    "ToolOutputFile.cpp",
    "TrieRawHashMap.cpp",
    "Twine.cpp",
    "TypeSize.cpp",
    "Unicode.cpp",
    "UnicodeCaseFold.cpp",
    "UnicodeNameToCodepoint.cpp",
    "UnicodeNameToCodepointGenerated.cpp",
    "VersionTuple.cpp",
    "VirtualFileSystem.cpp",
    "WithColor.cpp",
    "YAMLParser.cpp",
    "YAMLTraits.cpp",
    "raw_os_ostream.cpp",
    "raw_ostream.cpp",
    "raw_socket_stream.cpp",
    "xxhash.cpp",
    "Z3Solver.cpp",
    // System
    "Atomic.cpp",
    "DynamicLibrary.cpp",
    "Errno.cpp",
    "Memory.cpp",
    "Path.cpp",
    "Process.cpp",
    "Program.cpp",
    "RWMutex.cpp",
    "Signals.cpp",
    "Threading.cpp",
    "Valgrind.cpp",
    "Watchdog.cpp",
};

const c_files = &.{
    "regcomp.c",
    "regerror.c",
    "regexec.c",
    "regfree.c",
    "regstrlcpy.c",
};

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
