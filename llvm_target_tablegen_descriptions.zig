pub const Description = struct {
    output_basename: []const u8,
    flags: []const []const u8,
};

fn tblgen(basename: []const u8, flags: []const []const u8) Description {
    return Description{
        .output_basename = basename,
        .flags = flags,
    };
}

const std = @import("std");
const Context = @import("build.zig").Context;
const ClangTablegenDescription = @import("tblgen_descriptions.zig").ClangTablegenDescription;
const ClangTablegenTarget = @import("tblgen_descriptions.zig").ClangTablegenTarget;

/// Returns a hashmap which maps names of targets to their generated files, with
/// one LazyPath per .td file. for example:
/// {
///   "AArch64": [
///       "some/lazy/path/for/stuff/generated/from/AArch64.td",
///   ],
///   "X86": [
///       "some/lazy/path/for/stuff/generated/from/X86.td",
///       "some/lazy/path/for/stuff/generated/from/X86OtherThing.td",
///   ],
/// }
pub fn generateTablesForAllTargets(
    tablegen_exe: *std.Build.Step.Compile,
    ctx: *const Context,
) std.StringArrayHashMap([]std.Build.LazyPath) {
    var steps = std.StringArrayHashMap([]std.Build.LazyPath).init(ctx.b.allocator);
    const target_fields = @typeInfo(@TypeOf(targets_tablegens)).@"struct".fields;
    steps.ensureTotalCapacity(target_fields.len) catch @panic("OOM");

    inline for (target_fields) |target_field| {
        const tdfile_struct = @field(targets_tablegens, target_field.name);

        if (@field(ctx.opts.supported_targets, target_field.name)) {
            const tdfile_fields = @typeInfo(@TypeOf(tdfile_struct)).@"struct".fields;

            const lazy_paths_per_td_file = ctx.b.allocator.alloc(std.Build.LazyPath, tdfile_fields.len) catch @panic("OOM");

            inline for (tdfile_fields, lazy_paths_per_td_file) |tdfile, *lazypath_out| {
                const descriptions_for_file: []const Description = @field(tdfile_struct, tdfile.name);
                var tblgen_targets: [descriptions_for_file.len]ClangTablegenTarget = undefined;
                for (descriptions_for_file, &tblgen_targets) |desc, *undef| {
                    undef.* = ClangTablegenTarget{
                        .flags = desc.flags,
                        .output_basename = desc.output_basename,
                        .folder = .{ .custom = "Target/" ++ target_field.name },
                    };
                }

                const wfs = ctx.b.addWriteFiles();
                ctx.addTablegenOutputFileToWriteFileStep(wfs, tablegen_exe, ClangTablegenDescription{
                    .td_file = ctx.srcPath("llvm/lib/Target/" ++ target_field.name ++ "/" ++ tdfile.name),
                    .targets = &tblgen_targets,
                    .td_includes = &.{},
                });

                lazypath_out.* = wfs.getDirectory();
            }

            steps.put(target_field.name, lazy_paths_per_td_file) catch @panic("OOM");
        }
    }

    return steps;
}

pub const targets_tablegens = .{
    .AArch64 = .{
        .@"AArch64.td" = &.{
            tblgen("AArch64GenAsmMatcher.inc", &.{"-gen-asm-matcher"}),
            tblgen("AArch64GenAsmWriter.inc", &.{"-gen-asm-writer"}),
            tblgen("AArch64GenAsmWriter1.inc", &.{"-gen-asm-writer -asmwriternum=1"}),
            tblgen("AArch64GenCallingConv.inc", &.{"-gen-callingconv"}),
            tblgen("AArch64GenDAGISel.inc", &.{"-gen-dag-isel"}),
            tblgen("AArch64GenDisassemblerTables.inc", &.{"-gen-disassembler"}),
            tblgen("AArch64GenFastISel.inc", &.{"-gen-fast-isel"}),
            tblgen("AArch64GenGlobalISel.inc", &.{"-gen-global-isel"}),
            tblgen("AArch64GenO0PreLegalizeGICombiner.inc", &.{ "-gen-global-isel-combiner", "-combiners=\"AArch64O0PreLegalizerCombiner\"" }),
            tblgen("AArch64GenPreLegalizeGICombiner.inc", &.{ "-gen-global-isel-combiner", "-combiners=\"AArch64PreLegalizerCombiner\"" }),
            tblgen("AArch64GenPostLegalizeGICombiner.inc", &.{ "-gen-global-isel-combiner", "-combiners=\"AArch64PostLegalizerCombiner\"" }),
            tblgen("AArch64GenPostLegalizeGILowering.inc", &.{ "-gen-global-isel-combiner", "-combiners=\"AArch64PostLegalizerLowering\"" }),
            tblgen("AArch64GenInstrInfo.inc", &.{"-gen-instr-info"}),
            tblgen("AArch64GenMCCodeEmitter.inc", &.{"-gen-emitter"}),
            tblgen("AArch64GenMCPseudoLowering.inc", &.{"-gen-pseudo-lowering"}),
            tblgen("AArch64GenRegisterBank.inc", &.{"-gen-register-bank"}),
            tblgen("AArch64GenRegisterInfo.inc", &.{"-gen-register-info"}),
            tblgen("AArch64GenSubtargetInfo.inc", &.{"-gen-subtarget"}),
            tblgen("AArch64GenSystemOperands.inc", &.{"-gen-searchable-tables"}),
            tblgen("AArch64GenExegesis.inc", &.{"-gen-exegesis"}),
        },
    },
    .AMDGPU = .{
        .@"AMDGPU.td" = &.{
            tblgen("AMDGPUGenAsmMatcher.inc", &.{"-gen-asm-matcher"}),
            tblgen("AMDGPUGenAsmWriter.inc", &.{"-gen-asm-writer"}),
            tblgen("AMDGPUGenCallingConv.inc", &.{"-gen-callingconv"}),
            tblgen("AMDGPUGenDAGISel.inc", &.{"-gen-dag-isel"}),
            tblgen("AMDGPUGenDisassemblerTables.inc", &.{"-gen-disassembler"}),
            tblgen("AMDGPUGenInstrInfo.inc", &.{"-gen-instr-info"}),
            tblgen("AMDGPUGenMCCodeEmitter.inc", &.{"-gen-emitter"}),
            tblgen("AMDGPUGenMCPseudoLowering.inc", &.{"-gen-pseudo-lowering"}),
            tblgen("AMDGPUGenRegisterBank.inc", &.{"-gen-register-bank"}),
            tblgen("AMDGPUGenRegisterInfo.inc", &.{"-gen-register-info"}),
            tblgen("AMDGPUGenSearchableTables.inc", &.{"-gen-searchable-tables"}),
            tblgen("AMDGPUGenSubtargetInfo.inc", &.{"-gen-subtarget"}),
        },
        .@"AMDGPUGISel.td" = &.{
            tblgen("AMDGPUGenGlobalISel.inc", &.{"-gen-global-isel"}),
            tblgen("AMDGPUGenPreLegalizeGICombiner.inc", &.{ "-gen-global-isel-combiner", "-combiners=\"AMDGPUPreLegalizerCombiner\"" }),
            tblgen("AMDGPUGenPostLegalizeGICombiner.inc", &.{ "-gen-global-isel-combiner", "-combiners=\"AMDGPUPostLegalizerCombiner\"" }),
            tblgen("AMDGPUGenRegBankGICombiner.inc", &.{ "-gen-global-isel-combiner", "-combiners=\"AMDGPURegBankCombiner\"" }),
        },
        .@"R600.td" = &.{
            tblgen("R600GenAsmWriter.inc", &.{"-gen-asm-writer"}),
            tblgen("R600GenCallingConv.inc", &.{"-gen-callingconv"}),
            tblgen("R600GenDAGISel.inc", &.{"-gen-dag-isel"}),
            tblgen("R600GenDFAPacketizer.inc", &.{"-gen-dfa-packetizer"}),
            tblgen("R600GenInstrInfo.inc", &.{"-gen-instr-info"}),
            tblgen("R600GenMCCodeEmitter.inc", &.{"-gen-emitter"}),
            tblgen("R600GenRegisterInfo.inc", &.{"-gen-register-info"}),
            tblgen("R600GenSubtargetInfo.inc", &.{"-gen-subtarget"}),
        },
        .@"InstCombineTables.td" = &.{
            tblgen("InstCombineTables.inc", &.{"-gen-searchable-tables"}),
        },
    },
    .ARC = .{
        .@"ARC.td" = &.{
            tblgen("ARCGenAsmWriter.inc", &.{"-gen-asm-writer"}),
            tblgen("ARCGenCallingConv.inc", &.{"-gen-callingconv"}),
            tblgen("ARCGenDAGISel.inc", &.{"-gen-dag-isel"}),
            tblgen("ARCGenDisassemblerTables.inc", &.{"-gen-disassembler"}),
            tblgen("ARCGenInstrInfo.inc", &.{"-gen-instr-info"}),
            tblgen("ARCGenRegisterInfo.inc", &.{"-gen-register-info"}),
            tblgen("ARCGenSubtargetInfo.inc", &.{"-gen-subtarget"}),
        },
    },
    .ARM = .{
        .@"ARM.td" = &.{
            tblgen("ARMGenAsmMatcher.inc", &.{"-gen-asm-matcher"}),
            tblgen("ARMGenAsmWriter.inc", &.{"-gen-asm-writer"}),
            tblgen("ARMGenCallingConv.inc", &.{"-gen-callingconv"}),
            tblgen("ARMGenDAGISel.inc", &.{"-gen-dag-isel"}),
            tblgen("ARMGenDisassemblerTables.inc", &.{"-gen-disassembler"}),
            tblgen("ARMGenFastISel.inc", &.{"-gen-fast-isel"}),
            tblgen("ARMGenGlobalISel.inc", &.{"-gen-global-isel"}),
            tblgen("ARMGenInstrInfo.inc", &.{"-gen-instr-info"}),
            tblgen("ARMGenMCCodeEmitter.inc", &.{"-gen-emitter"}),
            tblgen("ARMGenMCPseudoLowering.inc", &.{"-gen-pseudo-lowering"}),
            tblgen("ARMGenRegisterBank.inc", &.{"-gen-register-bank"}),
            tblgen("ARMGenRegisterInfo.inc", &.{"-gen-register-info"}),
            tblgen("ARMGenSubtargetInfo.inc", &.{"-gen-subtarget"}),
            tblgen("ARMGenSystemRegister.inc", &.{"-gen-searchable-tables"}),
        },
    },
    .AVR = .{
        .@"AVR.td" = &.{
            tblgen("AVRGenAsmMatcher.inc", &.{"-gen-asm-matcher"}),
            tblgen("AVRGenAsmWriter.inc", &.{"-gen-asm-writer"}),
            tblgen("AVRGenCallingConv.inc", &.{"-gen-callingconv"}),
            tblgen("AVRGenDAGISel.inc", &.{"-gen-dag-isel"}),
            tblgen("AVRGenDisassemblerTables.inc", &.{"-gen-disassembler"}),
            tblgen("AVRGenInstrInfo.inc", &.{"-gen-instr-info"}),
            tblgen("AVRGenMCCodeEmitter.inc", &.{"-gen-emitter"}),
            tblgen("AVRGenRegisterInfo.inc", &.{"-gen-register-info"}),
            tblgen("AVRGenSubtargetInfo.inc", &.{"-gen-subtarget"}),
        },
    },
    .BPF = .{
        .@"BPF.td" = &.{
            tblgen("BPFGenAsmMatcher.inc", &.{"-gen-asm-matcher"}),
            tblgen("BPFGenAsmWriter.inc", &.{"-gen-asm-writer"}),
            tblgen("BPFGenCallingConv.inc", &.{"-gen-callingconv"}),
            tblgen("BPFGenDAGISel.inc", &.{"-gen-dag-isel"}),
            tblgen("BPFGenDisassemblerTables.inc", &.{"-gen-disassembler"}),
            tblgen("BPFGenInstrInfo.inc", &.{"-gen-instr-info"}),
            tblgen("BPFGenMCCodeEmitter.inc", &.{"-gen-emitter"}),
            tblgen("BPFGenRegisterInfo.inc", &.{"-gen-register-info"}),
            tblgen("BPFGenSubtargetInfo.inc", &.{"-gen-subtarget"}),
            tblgen("BPFGenGlobalISel.inc", &.{"-gen-global-isel"}),
            tblgen("BPFGenRegisterBank.inc", &.{"-gen-register-bank"}),
        },
    },
    .CSKY = .{
        .@"CSKY.td" = &.{
            tblgen("CSKYGenAsmMatcher.inc", &.{"-gen-asm-matcher"}),
            tblgen("CSKYGenAsmWriter.inc", &.{"-gen-asm-writer"}),
            tblgen("CSKYGenCallingConv.inc", &.{"-gen-callingconv"}),
            tblgen("CSKYGenCompressInstEmitter.inc", &.{"-gen-compress-inst-emitter"}),
            tblgen("CSKYGenDAGISel.inc", &.{"-gen-dag-isel"}),
            tblgen("CSKYGenDisassemblerTables.inc", &.{"-gen-disassembler"}),
            tblgen("CSKYGenInstrInfo.inc", &.{"-gen-instr-info"}),
            tblgen("CSKYGenMCCodeEmitter.inc", &.{"-gen-emitter"}),
            tblgen("CSKYGenMCPseudoLowering.inc", &.{"-gen-pseudo-lowering"}),
            tblgen("CSKYGenRegisterInfo.inc", &.{"-gen-register-info"}),
            tblgen("CSKYGenSubtargetInfo.inc", &.{"-gen-subtarget"}),
        },
    },
    .DirectX = .{
        .@"DirectX.td" = &.{
            tblgen("DirectXGenSubtargetInfo.inc", &.{"-gen-subtarget"}),
            tblgen("DirectXGenInstrInfo.inc", &.{"-gen-instr-info"}),
            tblgen("DirectXGenRegisterInfo.inc", &.{"-gen-register-info"}),
        },
        .@"DXIL.td" = &.{
            tblgen("DXILOperation.inc", &.{"-gen-dxil-operation"}),
        },
    },
    .Hexagon = .{
        .@"Hexagon.td" = &.{
            tblgen("HexagonGenAsmMatcher.inc", &.{"-gen-asm-matcher"}),
            tblgen("HexagonGenAsmWriter.inc", &.{"-gen-asm-writer"}),
            tblgen("HexagonGenCallingConv.inc", &.{"-gen-callingconv"}),
            tblgen("HexagonGenDAGISel.inc", &.{"-gen-dag-isel"}),
            tblgen("HexagonGenDFAPacketizer.inc", &.{"-gen-dfa-packetizer"}),
            tblgen("HexagonGenDisassemblerTables.inc", &.{"-gen-disassembler"}),
            tblgen("HexagonGenInstrInfo.inc", &.{"-gen-instr-info"}),
            tblgen("HexagonGenMCCodeEmitter.inc", &.{"-gen-emitter"}),
            tblgen("HexagonGenRegisterInfo.inc", &.{"-gen-register-info"}),
            tblgen("HexagonGenSubtargetInfo.inc", &.{"-gen-subtarget"}),
        },
    },
    .Lanai = .{
        .@"Lanai.td" = &.{
            tblgen("LanaiGenAsmMatcher.inc", &.{"-gen-asm-matcher"}),
            tblgen("LanaiGenAsmWriter.inc", &.{"-gen-asm-writer"}),
            tblgen("LanaiGenCallingConv.inc", &.{"-gen-callingconv"}),
            tblgen("LanaiGenDAGISel.inc", &.{"-gen-dag-isel"}),
            tblgen("LanaiGenDisassemblerTables.inc", &.{"-gen-disassembler"}),
            tblgen("LanaiGenInstrInfo.inc", &.{"-gen-instr-info"}),
            tblgen("LanaiGenMCCodeEmitter.inc", &.{"-gen-emitter"}),
            tblgen("LanaiGenRegisterInfo.inc", &.{"-gen-register-info"}),
            tblgen("LanaiGenSubtargetInfo.inc", &.{"-gen-subtarget"}),
        },
    },
    .LoongArch = .{
        .@"LoongArch.td" = &.{
            tblgen("LoongArchGenAsmMatcher.inc", &.{"-gen-asm-matcher"}),
            tblgen("LoongArchGenAsmWriter.inc", &.{"-gen-asm-writer"}),
            tblgen("LoongArchGenDAGISel.inc", &.{"-gen-dag-isel"}),
            tblgen("LoongArchGenDisassemblerTables.inc", &.{"-gen-disassembler"}),
            tblgen("LoongArchGenInstrInfo.inc", &.{"-gen-instr-info"}),
            tblgen("LoongArchGenMCPseudoLowering.inc", &.{"-gen-pseudo-lowering"}),
            tblgen("LoongArchGenMCCodeEmitter.inc", &.{"-gen-emitter"}),
            tblgen("LoongArchGenRegisterInfo.inc", &.{"-gen-register-info"}),
            tblgen("LoongArchGenSubtargetInfo.inc", &.{"-gen-subtarget"}),
        },
    },
    .M68k = .{
        .@"M68k.td" = &.{
            tblgen("M68kGenGlobalISel.inc", &.{"-gen-global-isel"}),
            tblgen("M68kGenRegisterInfo.inc", &.{"-gen-register-info"}),
            tblgen("M68kGenRegisterBank.inc", &.{"-gen-register-bank"}),
            tblgen("M68kGenInstrInfo.inc", &.{"-gen-instr-info"}),
            tblgen("M68kGenSubtargetInfo.inc", &.{"-gen-subtarget"}),
            tblgen("M68kGenMCCodeEmitter.inc", &.{"-gen-emitter"}),
            tblgen("M68kGenMCPseudoLowering.inc", &.{"-gen-pseudo-lowering"}),
            tblgen("M68kGenDAGISel.inc", &.{"-gen-dag-isel"}),
            tblgen("M68kGenCallingConv.inc", &.{"-gen-callingconv"}),
            tblgen("M68kGenAsmWriter.inc", &.{"-gen-asm-writer"}),
            tblgen("M68kGenAsmMatcher.inc", &.{"-gen-asm-matcher"}),
            tblgen("M68kGenDisassemblerTable.inc", &.{"-gen-disassembler"}),
        },
    },
    .Mips = .{
        .@"Mips.td" = &.{
            tblgen("MipsGenAsmMatcher.inc", &.{"-gen-asm-matcher"}),
            tblgen("MipsGenAsmWriter.inc", &.{"-gen-asm-writer"}),
            tblgen("MipsGenCallingConv.inc", &.{"-gen-callingconv"}),
            tblgen("MipsGenDAGISel.inc", &.{"-gen-dag-isel"}),
            tblgen("MipsGenDisassemblerTables.inc", &.{"-gen-disassembler"}),
            tblgen("MipsGenFastISel.inc", &.{"-gen-fast-isel"}),
            tblgen("MipsGenGlobalISel.inc", &.{"-gen-global-isel"}),
            tblgen("MipsGenPostLegalizeGICombiner.inc", &.{ "-gen-global-isel-combiner", "-combiners=\"MipsPostLegalizerCombiner\"" }),
            tblgen("MipsGenInstrInfo.inc", &.{"-gen-instr-info"}),
            tblgen("MipsGenMCCodeEmitter.inc", &.{"-gen-emitter"}),
            tblgen("MipsGenMCPseudoLowering.inc", &.{"-gen-pseudo-lowering"}),
            tblgen("MipsGenRegisterBank.inc", &.{"-gen-register-bank"}),
            tblgen("MipsGenRegisterInfo.inc", &.{"-gen-register-info"}),
            tblgen("MipsGenSubtargetInfo.inc", &.{"-gen-subtarget"}),
            tblgen("MipsGenExegesis.inc", &.{"-gen-exegesis"}),
        },
    },
    .MSP430 = .{
        .@"MSP430.td" = &.{
            tblgen("MSP430GenAsmMatcher.inc", &.{"-gen-asm-matcher"}),
            tblgen("MSP430GenAsmWriter.inc", &.{"-gen-asm-writer"}),
            tblgen("MSP430GenCallingConv.inc", &.{"-gen-callingconv"}),
            tblgen("MSP430GenDAGISel.inc", &.{"-gen-dag-isel"}),
            tblgen("MSP430GenDisassemblerTables.inc", &.{"-gen-disassembler"}),
            tblgen("MSP430GenInstrInfo.inc", &.{"-gen-instr-info"}),
            tblgen("MSP430GenMCCodeEmitter.inc", &.{"-gen-emitter"}),
            tblgen("MSP430GenRegisterInfo.inc", &.{"-gen-register-info"}),
            tblgen("MSP430GenSubtargetInfo.inc", &.{"-gen-subtarget"}),
        },
    },
    .NVPTX = .{
        .@"NVPTX.td" = &.{
            tblgen("NVPTXGenAsmWriter.inc", &.{"-gen-asm-writer"}),
            tblgen("NVPTXGenDAGISel.inc", &.{"-gen-dag-isel"}),
            tblgen("NVPTXGenInstrInfo.inc", &.{"-gen-instr-info"}),
            tblgen("NVPTXGenRegisterInfo.inc", &.{"-gen-register-info"}),
            tblgen("NVPTXGenSubtargetInfo.inc", &.{"-gen-subtarget"}),
        },
    },
    .PowerPC = .{
        .@"PPC.td" = &.{
            tblgen("PPCGenAsmMatcher.inc", &.{"-gen-asm-matcher"}),
            tblgen("PPCGenAsmWriter.inc", &.{"-gen-asm-writer"}),
            tblgen("PPCGenCallingConv.inc", &.{"-gen-callingconv"}),
            tblgen("PPCGenDAGISel.inc", &.{"-gen-dag-isel"}),
            tblgen("PPCGenDisassemblerTables.inc", &.{"-gen-disassembler"}),
            tblgen("PPCGenFastISel.inc", &.{"-gen-fast-isel"}),
            tblgen("PPCGenInstrInfo.inc", &.{"-gen-instr-info"}),
            tblgen("PPCGenMCCodeEmitter.inc", &.{"-gen-emitter"}),
            tblgen("PPCGenRegisterInfo.inc", &.{"-gen-register-info"}),
            tblgen("PPCGenSubtargetInfo.inc", &.{"-gen-subtarget"}),
            tblgen("PPCGenExegesis.inc", &.{"-gen-exegesis"}),
            tblgen("PPCGenRegisterBank.inc", &.{"-gen-register-bank"}),
            tblgen("PPCGenGlobalISel.inc", &.{"-gen-global-isel"}),
        },
    },
    .RISCV = .{
        .@"RISCV.td" = &.{
            tblgen("RISCVGenAsmMatcher.inc", &.{"-gen-asm-matcher"}),
            tblgen("RISCVGenAsmWriter.inc", &.{"-gen-asm-writer"}),
            tblgen("RISCVGenCompressInstEmitter.inc", &.{"-gen-compress-inst-emitter"}),
            tblgen("RISCVGenMacroFusion.inc", &.{"-gen-macro-fusion-pred"}),
            tblgen("RISCVGenDAGISel.inc", &.{"-gen-dag-isel"}),
            tblgen("RISCVGenDisassemblerTables.inc", &.{"-gen-disassembler"}),
            tblgen("RISCVGenInstrInfo.inc", &.{"-gen-instr-info"}),
            tblgen("RISCVGenMCCodeEmitter.inc", &.{"-gen-emitter"}),
            tblgen("RISCVGenMCPseudoLowering.inc", &.{"-gen-pseudo-lowering"}),
            tblgen("RISCVGenRegisterBank.inc", &.{"-gen-register-bank"}),
            tblgen("RISCVGenRegisterInfo.inc", &.{"-gen-register-info"}),
            tblgen("RISCVGenSearchableTables.inc", &.{"-gen-searchable-tables"}),
            tblgen("RISCVGenSubtargetInfo.inc", &.{"-gen-subtarget"}),
            tblgen("RISCVGenExegesis.inc", &.{"-gen-exegesis"}),
        },
        .@"RISCVGISel.td" = &.{
            tblgen("RISCVGenGlobalISel.inc", &.{"-gen-global-isel"}),
            tblgen("RISCVGenO0PreLegalizeGICombiner.inc", &.{ "-gen-global-isel-combiner", "-combiners=\"RISCVO0PreLegalizerCombiner\"" }),
            tblgen("RISCVGenPreLegalizeGICombiner.inc", &.{ "-gen-global-isel-combiner", "-combiners=\"RISCVPreLegalizerCombiner\"" }),
            tblgen("RISCVGenPostLegalizeGICombiner.inc", &.{ "-gen-global-isel-combiner", "-combiners=\"RISCVPostLegalizerCombiner\"" }),
        },
    },
    .Sparc = .{
        .@"Sparc.td" = &.{
            tblgen("SparcGenAsmMatcher.inc", &.{"-gen-asm-matcher"}),
            tblgen("SparcGenAsmWriter.inc", &.{"-gen-asm-writer"}),
            tblgen("SparcGenCallingConv.inc", &.{"-gen-callingconv"}),
            tblgen("SparcGenDAGISel.inc", &.{"-gen-dag-isel"}),
            tblgen("SparcGenDisassemblerTables.inc", &.{"-gen-disassembler"}),
            tblgen("SparcGenInstrInfo.inc", &.{"-gen-instr-info"}),
            tblgen("SparcGenMCCodeEmitter.inc", &.{"-gen-emitter"}),
            tblgen("SparcGenRegisterInfo.inc", &.{"-gen-register-info"}),
            tblgen("SparcGenSearchableTables.inc", &.{"-gen-searchable-tables"}),
            tblgen("SparcGenSubtargetInfo.inc", &.{"-gen-subtarget"}),
        },
    },
    .SPIRV = .{
        .@"SPIRV.td" = &.{
            tblgen("SPIRVGenAsmWriter.inc", &.{"-gen-asm-writer"}),
            tblgen("SPIRVGenGlobalISel.inc", &.{"-gen-global-isel"}),
            tblgen("SPIRVGenInstrInfo.inc", &.{"-gen-instr-info"}),
            tblgen("SPIRVGenMCCodeEmitter.inc", &.{"-gen-emitter"}),
            tblgen("SPIRVGenRegisterBank.inc", &.{"-gen-register-bank"}),
            tblgen("SPIRVGenRegisterInfo.inc", &.{"-gen-register-info"}),
            tblgen("SPIRVGenSubtargetInfo.inc", &.{"-gen-subtarget"}),
            tblgen("SPIRVGenTables.inc", &.{"-gen-searchable-tables"}),
            tblgen("SPIRVGenPreLegalizeGICombiner.inc", &.{ "-gen-global-isel-combiner", "-combiners=\"SPIRVPreLegalizerCombiner\"" }),
        },
    },
    .SystemZ = .{
        .@"SystemZ.td" = &.{
            tblgen("SystemZGenAsmMatcher.inc", &.{"-gen-asm-matcher"}),
            tblgen("SystemZGenGNUAsmWriter.inc", &.{"-gen-asm-writer"}),
            tblgen("SystemZGenHLASMAsmWriter.inc", &.{"-gen-asm-writer -asmwriternum=1"}),
            tblgen("SystemZGenCallingConv.inc", &.{"-gen-callingconv"}),
            tblgen("SystemZGenDAGISel.inc", &.{"-gen-dag-isel"}),
            tblgen("SystemZGenDisassemblerTables.inc", &.{"-gen-disassembler"}),
            tblgen("SystemZGenInstrInfo.inc", &.{"-gen-instr-info"}),
            tblgen("SystemZGenMCCodeEmitter.inc", &.{"-gen-emitter"}),
            tblgen("SystemZGenRegisterInfo.inc", &.{"-gen-register-info"}),
            tblgen("SystemZGenSubtargetInfo.inc", &.{"-gen-subtarget"}),
        },
    },
    .VE = .{
        .@"VE.td" = &.{
            tblgen("VEGenRegisterInfo.inc", &.{"-gen-register-info"}),
            tblgen("VEGenInstrInfo.inc", &.{"-gen-instr-info"}),
            tblgen("VEGenDisassemblerTables.inc", &.{"-gen-disassembler"}),
            tblgen("VEGenMCCodeEmitter.inc", &.{"-gen-emitter"}),
            tblgen("VEGenAsmWriter.inc", &.{"-gen-asm-writer"}),
            tblgen("VEGenAsmMatcher.inc", &.{"-gen-asm-matcher"}),
            tblgen("VEGenDAGISel.inc", &.{"-gen-dag-isel"}),
            tblgen("VEGenSubtargetInfo.inc", &.{"-gen-subtarget"}),
            tblgen("VEGenCallingConv.inc", &.{"-gen-callingconv"}),
        },
    },
    .WebAssembly = .{
        .@"WebAssembly.td" = &.{
            tblgen("WebAssemblyGenAsmMatcher.inc", &.{"-gen-asm-matcher"}),
            tblgen("WebAssemblyGenAsmWriter.inc", &.{"-gen-asm-writer"}),
            tblgen("WebAssemblyGenDAGISel.inc", &.{"-gen-dag-isel"}),
            tblgen("WebAssemblyGenDisassemblerTables.inc", &.{"-gen-disassembler"}),
            tblgen("WebAssemblyGenFastISel.inc", &.{"-gen-fast-isel"}),
            tblgen("WebAssemblyGenInstrInfo.inc", &.{"-gen-instr-info"}),
            tblgen("WebAssemblyGenMCCodeEmitter.inc", &.{"-gen-emitter"}),
            tblgen("WebAssemblyGenRegisterInfo.inc", &.{"-gen-register-info"}),
            tblgen("WebAssemblyGenSubtargetInfo.inc", &.{"-gen-subtarget"}),
        },
    },
    .X86 = .{
        .@"X86.td" = &.{
            tblgen("X86GenAsmMatcher.inc", &.{"-gen-asm-matcher"}),
            tblgen("X86GenAsmWriter.inc", &.{"-gen-asm-writer"}),
            tblgen("X86GenAsmWriter1.inc", &.{"-gen-asm-writer -asmwriternum=1"}),
            tblgen("X86GenCallingConv.inc", &.{"-gen-callingconv"}),
            tblgen("X86GenDAGISel.inc", &.{"-gen-dag-isel"}),
            tblgen("X86GenDisassemblerTables.inc", &.{"-gen-disassembler"}),
            tblgen("X86GenInstrMapping.inc", &.{"-gen-x86-instr-mapping"}),
            tblgen("X86GenExegesis.inc", &.{"-gen-exegesis"}),
            tblgen("X86GenFastISel.inc", &.{"-gen-fast-isel"}),
            tblgen("X86GenGlobalISel.inc", &.{"-gen-global-isel"}),
            tblgen("X86GenInstrInfo.inc", &.{ "-gen-instr-info", "-instr-info-expand-mi-operand-info=0" }),
            tblgen("X86GenMnemonicTables.inc", &.{ "-gen-x86-mnemonic-tables", "-asmwriternum=1" }),
            tblgen("X86GenRegisterBank.inc", &.{"-gen-register-bank"}),
            tblgen("X86GenRegisterInfo.inc", &.{"-gen-register-info"}),
            tblgen("X86GenSubtargetInfo.inc", &.{"-gen-subtarget"}),
            tblgen("X86GenFoldTables.inc", &.{ "-gen-x86-fold-tables", "-asmwriternum=1" }),
        },
    },
    .XCore = .{
        .@"XCore.td" = &.{
            tblgen("XCoreGenAsmWriter.inc", &.{"-gen-asm-writer"}),
            tblgen("XCoreGenCallingConv.inc", &.{"-gen-callingconv"}),
            tblgen("XCoreGenDAGISel.inc", &.{"-gen-dag-isel"}),
            tblgen("XCoreGenDisassemblerTables.inc", &.{"-gen-disassembler"}),
            tblgen("XCoreGenInstrInfo.inc", &.{"-gen-instr-info"}),
            tblgen("XCoreGenRegisterInfo.inc", &.{"-gen-register-info"}),
            tblgen("XCoreGenSubtargetInfo.inc", &.{"-gen-subtarget"}),
        },
    },
    .Xtensa = .{
        .@"Xtensa.td" = &.{
            tblgen("XtensaGenAsmMatcher.inc", &.{"-gen-asm-matcher"}),
            tblgen("XtensaGenAsmWriter.inc", &.{"-gen-asm-writer"}),
            tblgen("XtensaGenCallingConv.inc", &.{"-gen-callingconv"}),
            tblgen("XtensaGenDAGISel.inc", &.{"-gen-dag-isel"}),
            tblgen("XtensaGenDisassemblerTables.inc", &.{"-gen-disassembler"}),
            tblgen("XtensaGenInstrInfo.inc", &.{"-gen-instr-info"}),
            tblgen("XtensaGenMCCodeEmitter.inc", &.{"-gen-emitter"}),
            tblgen("XtensaGenRegisterInfo.inc", &.{"-gen-register-info"}),
            tblgen("XtensaGenSubtargetInfo.inc", &.{"-gen-subtarget"}),
        },
    },
};

// pub const targets_main_sources = .{
//     .AArch64 = &.{},
//     .ARC = &.{},
//     .ARM = &.{},
//     .AVR = &.{},
//     .BPF = &.{},
//     .CSKY = &.{},
//     .DirectX = &.{},
//     .Hexagon = &.{},
//     .Lanai = &.{},
//     .LoongArch = &.{},
//     .M68k = &.{},
//     .Mips = &.{},
//     .MSP430 = &.{},
//     .NVPTX = &.{},
//     .PowerPC = &.{},
//     .RISCV = &.{},
//     .Sparc = &.{},
//     .SPIRV = &.{},
//     .SystemZ = &.{},
//     .VE = &.{},
//     .WebAssembly = &.{},
//     .X86 = &.{},
//     .XCore = &.{},
//     .Xtensa = &.{},
// };
