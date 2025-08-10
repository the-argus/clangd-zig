const std = @import("std");

const LazyPath = std.Build.LazyPath;

pub const ClangTablegenTarget = struct {
    output_basename: []const u8,
    flags: []const []const u8,
    folder: TablegenOutputFolder = .basic,
};

pub const TablegenOutputFolder = enum {
    basic,
    basic_root,
    ast,
    driver,
    openmp,
    codegen,
    ir,
    checkers,
    syntax,
    none,
    sema,
    target_parser,

    pub fn toRelativePath(self: @This()) []const u8 {
        return switch (self) {
            .basic => "clang/Basic",
            .basic_root => "Basic",
            .ast => "clang/AST",
            .driver => "clang/Driver",
            .openmp => "llvm/Frontend/OpenMP",
            .codegen => "llvm/CodeGen",
            .ir => "llvm/IR",
            .checkers => "clang/StaticAnalyzer/Checkers",
            .syntax => "clang/Tooling/Syntax",
            .none => "",
            .sema => "clang/Sema",
            .target_parser => "llvm/TargetParser",
        };
    }
};

pub const ClangTablegenDescription = struct {
    td_file: LazyPath,
    targets: []const ClangTablegenTarget,
    td_includes: []const LazyPath,
};

pub fn getClangTablegenDescriptions(b: *std.Build, root: std.Build.LazyPath) []const ClangTablegenDescription {
    const includes = b.allocator.create([3]LazyPath) catch @panic("OOM");
    includes.* = [_]LazyPath{
        root.path(b, "clang/include/"),
        root.path(b, "clang/include/clang/Basic"),
        root.path(b, "clang/include/clang/StaticAnalyzer/Checkers"),
    };

    const initial_diag_target_list = &.{
        ClangTablegenTarget{
            .output_basename = "DiagnosticGroups.inc",
            .flags = &.{"-gen-clang-diag-groups"},
        },
        ClangTablegenTarget{
            .output_basename = "DiagnosticIndexName.inc",
            .flags = &.{"-gen-clang-diags-index-name"},
        },
    };

    var diag_target_list = std.ArrayList(ClangTablegenTarget).initCapacity(b.allocator, 50) catch @panic("OOM");
    diag_target_list.appendSlice(initial_diag_target_list) catch @panic("OOM");

    const diag_targets = &[_][]const u8{
        "Analysis",
        "AST",
        "Comment",
        "Common",
        "CrossTU",
        "Driver",
        "Frontend",
        "InstallAPI",
        "Lex",
        "Parse",
        "Refactoring",
        "Sema",
        "Serialization",
    };

    for (diag_targets) |targetname| {
        const component_flag = b.fmt("-clang-component={s}", .{targetname});
        const flags = b.allocator.create([4][]const u8) catch @panic("OOM");
        flags.* = .{ "-gen-clang-diags-defs", component_flag, "-gen-clang-diags-enums", component_flag };
        diag_target_list.appendSlice(&.{
            .{
                .output_basename = b.fmt("Diagnostic{s}Kinds.inc", .{targetname}),
                .flags = flags[0..2],
            },
            .{
                .output_basename = b.fmt("Diagnostic{s}Enums.inc", .{targetname}),
                .flags = flags[2..],
            },
        }) catch @panic("OOM");
    }

    const attr_targets = &[_]ClangTablegenTarget{
        .{ .output_basename = "Attrs.inc", .flags = &.{"-gen-clang-attr-classes"} },
        .{ .output_basename = "AttrList.inc", .flags = &.{"-gen-clang-attr-list"} },
        .{ .output_basename = "AttrParsedAttrList.inc", .flags = &.{"-gen-clang-attr-parsed-attr-list"} },
        .{ .output_basename = "AttrSubMatchRulesList.inc", .flags = &.{"-gen-clang-attr-subject-match-rule-list"} },
        .{ .output_basename = "RegularKeywordAttrInfo.inc", .flags = &.{"-gen-clang-regular-keyword-attr-info"} },
        .{ .output_basename = "AttrHasAttributeImpl.inc", .flags = &.{"-gen-clang-attr-has-attribute-impl"} },
        .{ .output_basename = "CXX11AttributeInfo.inc", .flags = &.{"-gen-cxx11-attribute-info"} },
        .{ .output_basename = "Attrs.inc", .flags = &.{"-gen-clang-attr-classes"}, .folder = .ast },
        .{ .output_basename = "AttrImpl.inc", .flags = &.{"-gen-clang-attr-impl"}, .folder = .ast },
        .{ .output_basename = "AttrsImpl.inc", .flags = &.{"-gen-clang-attr-impl"}, .folder = .ast },
        .{ .output_basename = "AttrTextNodeDump.inc", .flags = &.{"-gen-clang-attr-text-node-dump"}, .folder = .ast },
        .{ .output_basename = "AttrNodeTraverse.inc", .flags = &.{"-gen-clang-attr-node-traverse"}, .folder = .ast },
        .{ .output_basename = "AttrVisitor.inc", .flags = &.{"-gen-clang-attr-ast-visitor"}, .folder = .ast },
        .{ .output_basename = "AttrDocTable.inc", .flags = &.{"-gen-clang-attr-doc-table"}, .folder = .none },
        .{ .output_basename = "AttrTemplateInstantiate.inc", .flags = &.{"-gen-clang-attr-template-instantiate"}, .folder = .sema },
        .{ .output_basename = "AttrParsedAttrKinds.inc", .flags = &.{"-gen-clang-attr-parsed-attr-kinds"}, .folder = .sema },
        .{ .output_basename = "AttrSpellingListIndex.inc", .flags = &.{"-gen-clang-attr-spelling-index"}, .folder = .sema },
        .{ .output_basename = "AttrParsedAttrImpl.inc", .flags = &.{"-gen-clang-attr-parsed-attr-impl"}, .folder = .sema },
    };
    const declnode_targets = &[_]ClangTablegenTarget{
        .{ .output_basename = "DeclNodes.inc", .flags = &.{"-gen-clang-decl-nodes"} },
        .{ .output_basename = "DeclNodes.inc", .flags = &.{"-gen-clang-decl-nodes"}, .folder = .ast },
    };

    const opencl_builtins_targets = &[_]ClangTablegenTarget{
        .{ .output_basename = "OpenCLBuiltins.inc", .flags = &.{"-gen-clang-opencl-builtins"}, .folder = .none },
    };

    const stmt_nodes_targets = &[_]ClangTablegenTarget{.{ .output_basename = "StmtNodes.inc", .flags = &.{"-gen-clang-stmt-nodes"}, .folder = .ast }};

    const builtins_targets = &[_]ClangTablegenTarget{.{ .output_basename = "Builtins.inc", .flags = &.{"-gen-clang-builtins"} }};
    const builtins_bpf_targets = &[_]ClangTablegenTarget{.{ .output_basename = "BuiltinsBPF.inc", .flags = &.{"-gen-clang-builtins"} }};
    const builtins_hexagon_targets = &[_]ClangTablegenTarget{.{ .output_basename = "BuiltinsHexagon.inc", .flags = &.{"-gen-clang-builtins"} }};
    const builtins_nvptx_targets = &[_]ClangTablegenTarget{.{ .output_basename = "BuiltinsNVPTX.inc", .flags = &.{"-gen-clang-builtins"} }};
    const builtins_riscv_targets = &[_]ClangTablegenTarget{.{ .output_basename = "BuiltinsRISCV.inc", .flags = &.{"-gen-clang-builtins"} }};
    const builtins_spirv_targets = &[_]ClangTablegenTarget{.{ .output_basename = "BuiltinsSPIRV.inc", .flags = &.{"-gen-clang-builtins"} }};
    const builtins_x86_targets = &[_]ClangTablegenTarget{.{ .output_basename = "BuiltinsX86.inc", .flags = &.{"-gen-clang-builtins"} }};
    const builtins_x86_64_targets = &[_]ClangTablegenTarget{.{ .output_basename = "BuiltinsX86_64.inc", .flags = &.{"-gen-clang-builtins"} }};
    const arm_neon_targets = &[_]ClangTablegenTarget{.{ .output_basename = "arm_neon.inc", .flags = &.{"-gen-arm-neon-sema"} }};
    const arm_fp16_targets = &[_]ClangTablegenTarget{.{ .output_basename = "arm_fp16.inc", .flags = &.{"-gen-arm-neon-sema"} }};
    const arm_immcheck_types_targets = &[_]ClangTablegenTarget{.{ .output_basename = "arm_immcheck_types.inc", .flags = &.{"-gen-arm-immcheck-types"} }};
    const arm_mve_builtins_targets = &[_]ClangTablegenTarget{.{ .output_basename = "arm_mve_builtins.inc", .flags = &.{"-gen-arm-mve-builtin-def"} }};
    const arm_mve_builtin_cg_targets = &[_]ClangTablegenTarget{.{ .output_basename = "arm_mve_builtin_cg.inc", .flags = &.{"-gen-arm-mve-builtin-codegen"} }};
    const arm_mve_builtin_sema_targets = &[_]ClangTablegenTarget{.{ .output_basename = "arm_mve_builtin_sema.inc", .flags = &.{"-gen-arm-mve-builtin-sema"} }};
    const arm_mve_builtin_aliases_targets = &[_]ClangTablegenTarget{.{ .output_basename = "arm_mve_builtin_aliases.inc", .flags = &.{"-gen-arm-mve-builtin-aliases"} }};
    const arm_sve_builtins_targets = &[_]ClangTablegenTarget{.{ .output_basename = "arm_sve_builtins.inc", .flags = &.{"-gen-arm-sve-builtins"} }};
    const arm_sve_builtin_cg_targets = &[_]ClangTablegenTarget{.{ .output_basename = "arm_sve_builtin_cg.inc", .flags = &.{"-gen-arm-sve-builtin-codegen"} }};
    const arm_sve_typeflags_targets = &[_]ClangTablegenTarget{.{ .output_basename = "arm_sve_typeflags.inc", .flags = &.{"-gen-arm-sve-typeflags"} }};
    const arm_sve_sema_rangechecks_targets = &[_]ClangTablegenTarget{.{ .output_basename = "arm_sve_sema_rangechecks.inc", .flags = &.{"-gen-arm-sve-sema-rangechecks"} }};
    const arm_sve_streaming_attrs_targets = &[_]ClangTablegenTarget{.{ .output_basename = "arm_sve_streaming_attrs.inc", .flags = &.{"-gen-arm-sve-streaming-attrs"} }};
    const arm_sme_builtins_targets = &[_]ClangTablegenTarget{.{ .output_basename = "arm_sme_builtins.inc", .flags = &.{"-gen-arm-sme-builtins"} }};
    const arm_sme_builtin_cg_targets = &[_]ClangTablegenTarget{.{ .output_basename = "arm_sme_builtin_cg.inc", .flags = &.{"-gen-arm-sme-builtin-codegen"} }};
    const arm_sme_sema_rangechecks_targets = &[_]ClangTablegenTarget{.{ .output_basename = "arm_sme_sema_rangechecks.inc", .flags = &.{"-gen-arm-sme-sema-rangechecks"} }};
    const arm_sme_streaming_attrs_targets = &[_]ClangTablegenTarget{.{ .output_basename = "arm_sme_streaming_attrs.inc", .flags = &.{"-gen-arm-sme-streaming-attrs"} }};
    const arm_sme_builtins_za_state_targets = &[_]ClangTablegenTarget{.{ .output_basename = "arm_sme_builtins_za_state.inc", .flags = &.{"-gen-arm-sme-builtin-za-state"} }};
    const arm_cde_builtins_targets = &[_]ClangTablegenTarget{.{ .output_basename = "arm_cde_builtins.inc", .flags = &.{"-gen-arm-cde-builtin-def"} }};
    const arm_cde_builtin_cg_targets = &[_]ClangTablegenTarget{.{ .output_basename = "arm_cde_builtin_cg.inc", .flags = &.{"-gen-arm-cde-builtin-codegen"} }};
    const arm_cde_builtin_sema_targets = &[_]ClangTablegenTarget{.{ .output_basename = "arm_cde_builtin_sema.inc", .flags = &.{"-gen-arm-cde-builtin-sema"} }};
    const arm_cde_builtin_aliases_targets = &[_]ClangTablegenTarget{.{ .output_basename = "arm_cde_builtin_aliases.inc", .flags = &.{"-gen-arm-cde-builtin-aliases"} }};
    const riscv_vector_builtins_targets = &[_]ClangTablegenTarget{.{ .output_basename = "riscv_vector_builtins.inc", .flags = &.{"-gen-riscv-vector-builtins"} }};
    const riscv_vector_builtin_cg_targets = &[_]ClangTablegenTarget{.{ .output_basename = "riscv_vector_builtin_cg.inc", .flags = &.{"-gen-riscv-vector-builtin-codegen"} }};
    const riscv_vector_builtin_sema_targets = &[_]ClangTablegenTarget{.{ .output_basename = "riscv_vector_builtin_sema.inc", .flags = &.{"-gen-riscv-vector-builtin-sema"} }};
    const riscv_sifive_vector_builtins_targets = &[_]ClangTablegenTarget{.{ .output_basename = "riscv_sifive_vector_builtins.inc", .flags = &.{"-gen-riscv-sifive-vector-builtins"} }};
    const riscv_sifive_vector_builtin_cg_targets = &[_]ClangTablegenTarget{.{ .output_basename = "riscv_sifive_vector_builtin_cg.inc", .flags = &.{"-gen-riscv-sifive-vector-builtin-codegen"} }};
    const riscv_sifive_vector_builtin_sema_targets = &[_]ClangTablegenTarget{.{ .output_basename = "riscv_sifive_vector_builtin_sema.inc", .flags = &.{"-gen-riscv-sifive-vector-builtin-sema"} }};

    const type_nodes_targets = &[_]ClangTablegenTarget{.{ .output_basename = "TypeNodes.inc", .flags = &.{"-gen-clang-type-nodes"}, .folder = .ast }};
    const abstract_basic_reader_targets = &[_]ClangTablegenTarget{.{ .output_basename = "AbstractBasicReader.inc", .flags = &.{"-gen-clang-basic-reader"}, .folder = .ast }};
    const abstract_basic_writer_targets = &[_]ClangTablegenTarget{.{ .output_basename = "AbstractBasicWriter.inc", .flags = &.{"-gen-clang-basic-writer"}, .folder = .ast }};
    const abstract_type_reader_targets = &[_]ClangTablegenTarget{.{ .output_basename = "AbstractTypeReader.inc", .flags = &.{"-gen-clang-type-reader"}, .folder = .ast }};
    const abstract_type_writer_targets = &[_]ClangTablegenTarget{.{ .output_basename = "AbstractTypeWriter.inc", .flags = &.{"-gen-clang-type-writer"}, .folder = .ast }};
    const comment_nodes_targets = &[_]ClangTablegenTarget{.{ .output_basename = "CommentNodes.inc", .flags = &.{"-gen-clang-comment-nodes"}, .folder = .ast }};
    const comment_html_tags_targets = &[_]ClangTablegenTarget{.{ .output_basename = "CommentHTMLTags.inc", .flags = &.{"-gen-clang-comment-html-tags"}, .folder = .ast }};
    const comment_html_tags_properties_targets = &[_]ClangTablegenTarget{.{ .output_basename = "CommentHTMLTagsProperties.inc", .flags = &.{"-gen-clang-comment-html-tags-properties"}, .folder = .ast }};
    const comment_html_named_character_references_targets = &[_]ClangTablegenTarget{.{ .output_basename = "CommentHTMLNamedCharacterReferences.inc", .flags = &.{"-gen-clang-comment-html-named-character-references"}, .folder = .ast }};
    const comment_command_info_targets = &[_]ClangTablegenTarget{.{ .output_basename = "CommentCommandInfo.inc", .flags = &.{"-gen-clang-comment-command-info"}, .folder = .ast }};
    const comment_command_list_targets = &[_]ClangTablegenTarget{.{ .output_basename = "CommentCommandList.inc", .flags = &.{"-gen-clang-comment-command-list"}, .folder = .ast }};
    const stmt_data_collectors_targets = &[_]ClangTablegenTarget{.{ .output_basename = "StmtDataCollectors.inc", .flags = &.{"-gen-clang-data-collectors"}, .folder = .ast }};

    const checkers_targets = &[_]ClangTablegenTarget{.{ .output_basename = "Checkers.inc", .flags = &.{"-gen-clang-sa-checkers"}, .folder = .checkers }};
    const syntax_nodes_targets = &[_]ClangTablegenTarget{
        .{ .output_basename = "Nodes.inc", .flags = &.{"-gen-clang-syntax-node-list"}, .folder = .syntax },
        .{ .output_basename = "NodeClasses.inc", .flags = &.{"-gen-clang-syntax-node-classes"}, .folder = .syntax },
    };

    const opcodes_targets = &[_]ClangTablegenTarget{.{ .output_basename = "Opcodes.inc", .flags = &.{"-gen-clang-opcodes"}, .folder = .none }};

    const descs = [_]ClangTablegenDescription{
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/Attr.td"),
            .targets = attr_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/Diagnostic.td"),
            .targets = diag_target_list.toOwnedSlice() catch @panic("OOM"),
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/DeclNodes.td"),
            .targets = declnode_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/Builtins.td"),
            .targets = builtins_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/BuiltinsBPF.td"),
            .targets = builtins_bpf_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/BuiltinsHexagon.td"),
            .targets = builtins_hexagon_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/BuiltinsNVPTX.td"),
            .targets = builtins_nvptx_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/BuiltinsRISCV.td"),
            .targets = builtins_riscv_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/BuiltinsSPIRV.td"),
            .targets = builtins_spirv_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/BuiltinsX86.td"),
            .targets = builtins_x86_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/BuiltinsX86_64.td"),
            .targets = builtins_x86_64_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/StmtNodes.td"),
            .targets = stmt_nodes_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/arm_neon.td"),
            .targets = arm_neon_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/arm_fp16.td"),
            .targets = arm_fp16_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/arm_sve.td"),
            .targets = arm_immcheck_types_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/arm_mve.td"),
            .targets = arm_mve_builtins_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/arm_mve.td"),
            .targets = arm_mve_builtin_cg_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/arm_mve.td"),
            .targets = arm_mve_builtin_sema_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/arm_mve.td"),
            .targets = arm_mve_builtin_aliases_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/arm_sve.td"),
            .targets = arm_sve_builtins_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/arm_sve.td"),
            .targets = arm_sve_builtin_cg_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/arm_sve.td"),
            .targets = arm_sve_typeflags_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/arm_sve.td"),
            .targets = arm_sve_sema_rangechecks_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/arm_sve.td"),
            .targets = arm_sve_streaming_attrs_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/arm_sme.td"),
            .targets = arm_sme_builtins_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/arm_sme.td"),
            .targets = arm_sme_builtin_cg_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/arm_sme.td"),
            .targets = arm_sme_sema_rangechecks_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/arm_sme.td"),
            .targets = arm_sme_streaming_attrs_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/arm_sme.td"),
            .targets = arm_sme_builtins_za_state_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/arm_cde.td"),
            .targets = arm_cde_builtins_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/arm_cde.td"),
            .targets = arm_cde_builtin_cg_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/arm_cde.td"),
            .targets = arm_cde_builtin_sema_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/arm_cde.td"),
            .targets = arm_cde_builtin_aliases_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/riscv_vector.td"),
            .targets = riscv_vector_builtins_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/riscv_vector.td"),
            .targets = riscv_vector_builtin_cg_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/riscv_vector.td"),
            .targets = riscv_vector_builtin_sema_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/riscv_sifive_vector.td"),
            .targets = riscv_sifive_vector_builtins_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/riscv_sifive_vector.td"),
            .targets = riscv_sifive_vector_builtin_cg_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/riscv_sifive_vector.td"),
            .targets = riscv_sifive_vector_builtin_sema_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/TypeNodes.td"),
            .targets = type_nodes_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/AST/PropertiesBase.td"),
            .targets = abstract_basic_reader_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/AST/PropertiesBase.td"),
            .targets = abstract_basic_writer_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/AST/TypeProperties.td"),
            .targets = abstract_type_reader_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/AST/TypeProperties.td"),
            .targets = abstract_type_writer_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Basic/CommentNodes.td"),
            .targets = comment_nodes_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/AST/CommentHTMLTags.td"),
            .targets = comment_html_tags_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/AST/CommentHTMLTags.td"),
            .targets = comment_html_tags_properties_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/AST/CommentHTMLNamedCharacterReferences.td"),
            .targets = comment_html_named_character_references_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/AST/CommentCommands.td"),
            .targets = comment_command_info_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/AST/CommentCommands.td"),
            .targets = comment_command_list_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/AST/StmtDataCollectors.td"),
            .targets = stmt_data_collectors_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/StaticAnalyzer/Checkers/Checkers.td"),
            .targets = checkers_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Tooling/Syntax/Nodes.td"),
            .targets = syntax_nodes_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/lib/AST/ByteCode/Opcodes.td"),
            .targets = opcodes_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/lib/Sema/OpenCLBuiltins.td"),
            .targets = opencl_builtins_targets,
            .td_includes = includes,
        },
    };

    const allocated = b.allocator.create(@TypeOf(descs)) catch @panic("OOM");
    allocated.* = descs;
    return &allocated.*;
}

pub fn getLLVMTablegenDescriptions(b: *std.Build, root: std.Build.LazyPath) []const ClangTablegenDescription {
    const includes = b.allocator.create([4]LazyPath) catch @panic("OOM");
    includes.* = [_]LazyPath{
        root.path(b, "llvm/include"),
        root.path(b, "llvm/lib/Target/ARM"),
        root.path(b, "llvm/lib/Target/AArch64"),
        root.path(b, "llvm/lib/Target/RISCV"),
    };

    const options_targets = &[_]ClangTablegenTarget{.{ .output_basename = "Options.inc", .flags = &.{"-gen-opt-parser-defs"}, .folder = .driver }};
    const arm_targetparser_targets = &[_]ClangTablegenTarget{.{ .output_basename = "ARMTargetParserDef.inc", .flags = &.{"-gen-arm-target-def"}, .folder = .target_parser }};
    const aarch64_targetparser_targets = &[_]ClangTablegenTarget{.{ .output_basename = "AArch64TargetParserDef.inc", .flags = &.{"-gen-arm-target-def"}, .folder = .target_parser }};
    const riscv_targetparser_targets = &[_]ClangTablegenTarget{.{ .output_basename = "RISCVTargetParserDef.inc", .flags = &.{"-gen-riscv-target-def"}, .folder = .target_parser }};
    const openmp_targets = &[_]ClangTablegenTarget{
        .{ .output_basename = "OMP.h.inc", .flags = &.{"--gen-directive-decl"}, .folder = .openmp },
        .{ .output_basename = "OMP.inc", .flags = &.{"--gen-directive-impl"}, .folder = .openmp },
    };

    const descs = [_]ClangTablegenDescription{
        .{
            .td_file = root.path(b, "llvm/include/llvm/Frontend/OpenMP/OMP.td"),
            .targets = openmp_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "clang/include/clang/Driver/Options.td"),
            .targets = options_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "llvm/lib/Target/ARM/ARM.td"),
            .targets = arm_targetparser_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "llvm/lib/Target/AArch64/AArch64.td"),
            .targets = aarch64_targetparser_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "llvm/lib/Target/RISCV/RISCV.td"),
            .targets = riscv_targetparser_targets,
            .td_includes = includes,
        },
    };
    const allocated = b.allocator.create(@TypeOf(descs)) catch @panic("OOM");
    allocated.* = descs;
    return &allocated.*;
}

/// Tablegen tasks that can be done with llvm-min-tblgen
pub fn getLLVMMinTablegenDescriptions(b: *std.Build, root: std.Build.LazyPath) []const ClangTablegenDescription {
    const includes = b.allocator.create([1]LazyPath) catch @panic("OOM");
    includes.* = [_]LazyPath{root.path(b, "llvm/include")};

    const codegen_targets = &[_]ClangTablegenTarget{
        .{ .output_basename = "GenVT.inc", .flags = &.{"-gen-vt"}, .folder = .codegen },
    };

    const attributes_targets = &[_]ClangTablegenTarget{
        .{ .output_basename = "Attributes.inc", .flags = &.{"-gen-attrs"}, .folder = .ir },
    };

    const intrinsics_targets = &[_]ClangTablegenTarget{
        .{ .output_basename = "IntrinsicImpl.inc", .flags = &.{"-gen-intrinsic-impl"}, .folder = .ir },
        .{ .output_basename = "IntrinsicEnums.inc", .flags = &.{"-gen-intrinsic-enums"}, .folder = .ir },
        .{ .output_basename = "IntrinsicsAArch64.h", .flags = &.{ "-gen-intrinsic-enums", "-intrinsic-prefix=aarch64" }, .folder = .ir },
        .{ .output_basename = "IntrinsicsAMDGPU.h", .flags = &.{ "-gen-intrinsic-enums", "-intrinsic-prefix=amdgcn" }, .folder = .ir },
        .{ .output_basename = "IntrinsicsARM.h", .flags = &.{ "-gen-intrinsic-enums", "-intrinsic-prefix=arm" }, .folder = .ir },
        .{ .output_basename = "IntrinsicsBPF.h", .flags = &.{ "-gen-intrinsic-enums", "-intrinsic-prefix=bpf" }, .folder = .ir },
        .{ .output_basename = "IntrinsicsDirectX.h", .flags = &.{ "-gen-intrinsic-enums", "-intrinsic-prefix=dx" }, .folder = .ir },
        .{ .output_basename = "IntrinsicsHexagon.h", .flags = &.{ "-gen-intrinsic-enums", "-intrinsic-prefix=hexagon" }, .folder = .ir },
        .{ .output_basename = "IntrinsicsLoongArch.h", .flags = &.{ "-gen-intrinsic-enums", "-intrinsic-prefix=loongarch" }, .folder = .ir },
        .{ .output_basename = "IntrinsicsMips.h", .flags = &.{ "-gen-intrinsic-enums", "-intrinsic-prefix=mips" }, .folder = .ir },
        .{ .output_basename = "IntrinsicsNVPTX.h", .flags = &.{ "-gen-intrinsic-enums", "-intrinsic-prefix=nvvm" }, .folder = .ir },
        .{ .output_basename = "IntrinsicsPowerPC.h", .flags = &.{ "-gen-intrinsic-enums", "-intrinsic-prefix=ppc" }, .folder = .ir },
        .{ .output_basename = "IntrinsicsR600.h", .flags = &.{ "-gen-intrinsic-enums", "-intrinsic-prefix=r600" }, .folder = .ir },
        .{ .output_basename = "IntrinsicsRISCV.h", .flags = &.{ "-gen-intrinsic-enums", "-intrinsic-prefix=riscv" }, .folder = .ir },
        .{ .output_basename = "IntrinsicsSPIRV.h", .flags = &.{ "-gen-intrinsic-enums", "-intrinsic-prefix=spv" }, .folder = .ir },
        .{ .output_basename = "IntrinsicsS390.h", .flags = &.{ "-gen-intrinsic-enums", "-intrinsic-prefix=s390" }, .folder = .ir },
        .{ .output_basename = "IntrinsicsWebAssembly.h", .flags = &.{ "-gen-intrinsic-enums", "-intrinsic-prefix=wasm" }, .folder = .ir },
        .{ .output_basename = "IntrinsicsX86.h", .flags = &.{ "-gen-intrinsic-enums", "-intrinsic-prefix=x86" }, .folder = .ir },
        .{ .output_basename = "IntrinsicsXCore.h", .flags = &.{ "-gen-intrinsic-enums", "-intrinsic-prefix=xcore" }, .folder = .ir },
        .{ .output_basename = "IntrinsicsVE.h", .flags = &.{ "-gen-intrinsic-enums", "-intrinsic-prefix=ve" }, .folder = .ir },
    };

    const descs = [_]ClangTablegenDescription{
        .{
            .td_file = root.path(b, "llvm/include/llvm/CodeGen/ValueTypes.td"),
            .targets = codegen_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "llvm/include/llvm/IR/Attributes.td"),
            .targets = attributes_targets,
            .td_includes = includes,
        },
        .{
            .td_file = root.path(b, "llvm/include/llvm/IR/Intrinsics.td"),
            .targets = intrinsics_targets,
            .td_includes = includes,
        },
    };
    const allocated = b.allocator.create(@TypeOf(descs)) catch @panic("OOM");
    allocated.* = descs;
    return &allocated.*;
}
