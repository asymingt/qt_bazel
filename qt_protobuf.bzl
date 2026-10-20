"""Starlark rules for Qt Protobuf (qtprotobufgen) and Qt gRPC (qtgrpcgen) code generation."""

load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("@rules_cc//cc/common:cc_shared_library_hint_info.bzl", "CcSharedLibraryHintInfo")

def _compute_proto_inc_dirs(all_protos, strip, pkg_dir):
    inc_dirs = {}
    for p in all_protos:
        if strip and ("/" + strip + "/") in p.path:
            idx = p.path.find("/" + strip + "/")
            root_dir = p.path[:idx + len("/" + strip)]
            inc_dirs[root_dir] = True
        elif pkg_dir and p.path.endswith("/" + pkg_dir + "/" + p.basename):
            root_dir = p.path[:-len("/" + pkg_dir + "/" + p.basename)]
            inc_dirs[root_dir] = True
        else:
            inc_dirs[p.dirname] = True
    return inc_dirs.keys()

def _qt_protobuf_gen_impl(ctx):
    protoc = ctx.executable.protoc_tool
    plugin = ctx.executable.plugin_tool
    pkg_dir = ctx.attr.package_dir
    export_macro = ctx.attr.export_macro
    export_macro_filename = ctx.attr.export_macro_filename

    hdrs = []
    srcs = []
    out_base = ctx.label.name + "_out"
    out_base_path = None

    exp_hdr = None
    if export_macro and export_macro_filename:
        exp_hdr = ctx.actions.declare_file(out_base + "/" + export_macro_filename)
        hdrs.append(exp_hdr)
        out_base_path = exp_hdr.dirname

    proto_files = ctx.files.protos
    dep_proto_files = ctx.files.dep_protos
    inc_dirs = _compute_proto_inc_dirs(proto_files + dep_proto_files, ctx.attr.proto_strip_prefix, pkg_dir)

    for idx, proto in enumerate(proto_files):
        stem = proto.basename[:-6] if proto.basename.endswith(".proto") else proto.basename
        rel_prefix = (pkg_dir + "/") if pkg_dir else ""
        qpb_h = ctx.actions.declare_file(out_base + "/" + rel_prefix + stem + ".qpb.h")
        qpb_cpp = ctx.actions.declare_file(out_base + "/" + rel_prefix + stem + ".qpb.cpp")
        reg_cpp = ctx.actions.declare_file(out_base + "/" + rel_prefix + stem + "_qtprotoreg.cpp")
        hdrs.append(qpb_h)
        srcs.extend([qpb_cpp, reg_cpp])
        if out_base_path == None:
            if pkg_dir:
                out_base_path = qpb_h.dirname[:-len(pkg_dir) - 1]
            else:
                out_base_path = qpb_h.dirname

        opts = []
        if pkg_dir:
            opts.append("GENERATE_PACKAGE_SUBFOLDERS")
        if export_macro:
            if export_macro_filename:
                emit_exp = "true" if idx == 0 else "false"
                opts.append("EXPORT_MACRO={}:{}:{}".format(export_macro, export_macro_filename, emit_exp))
            else:
                opts.append("EXPORT_MACRO={}".format(export_macro))
        for extra_opt in ctx.attr.extra_opts:
            opts.append(extra_opt)

        step_outs = [qpb_h, qpb_cpp, reg_cpp]
        if idx == 0 and exp_hdr != None:
            step_outs.append(exp_hdr)

        args = ctx.actions.args()
        args.add("--plugin=protoc-gen-qtprotobuf=" + plugin.path)
        args.add("--qtprotobuf_out=" + out_base_path)
        if opts:
            args.add("--qtprotobuf_opt=" + ";".join(opts))
        for d in inc_dirs:
            args.add("-I" + d)
        args.add(proto.path)

        ctx.actions.run(
            executable = protoc,
            tools = [plugin],
            inputs = proto_files + dep_proto_files,
            outputs = step_outs,
            arguments = [args],
            mnemonic = "QtProtobufGen",
            progress_message = "Generating Qt Protobuf sources for %s" % proto.short_path,
        )

    cc_inc_dirs = [out_base_path] if out_base_path else []
    if out_base_path and pkg_dir:
        cc_inc_dirs.append(out_base_path + "/" + pkg_dir)

    return [
        DefaultInfo(files = depset(srcs + hdrs)),
        CcInfo(
            compilation_context = cc_common.create_compilation_context(
                headers = depset(hdrs),
                includes = depset(cc_inc_dirs),
                system_includes = depset(cc_inc_dirs),
            ),
        ),
        CcSharedLibraryHintInfo(attributes = []),
        OutputGroupInfo(
            hdrs = depset(hdrs),
            srcs = depset(srcs),
        ),
    ]

_qt_protobuf_gen_rule = rule(
    implementation = _qt_protobuf_gen_impl,
    attrs = {
        "protos": attr.label_list(allow_files = [".proto"], mandatory = True),
        "dep_protos": attr.label_list(allow_files = [".proto"]),
        "package_dir": attr.string(default = ""),
        "proto_strip_prefix": attr.string(default = ""),
        "export_macro": attr.string(default = ""),
        "export_macro_filename": attr.string(default = ""),
        "extra_opts": attr.string_list(),
        "protoc_tool": attr.label(
            mandatory = True,
            executable = True,
            cfg = "exec",
        ),
        "plugin_tool": attr.label(
            mandatory = True,
            executable = True,
            cfg = "exec",
        ),
    },
    provides = [CcInfo],
)

def qt_protobuf_gen(
        name,
        protos,
        dep_protos = [],
        package_dir = "",
        proto_strip_prefix = "",
        export_macro = "",
        export_macro_filename = "",
        extra_opts = [],
        protoc_tool = None,
        plugin_tool = None,
        **kwargs):
    """Generates Qt Protobuf C++ headers and sources using protoc + qtprotobufgen.

    Args:
      name: Target name.
      protos: List of .proto files to compile.
      dep_protos: Additional .proto files imported by `protos`.
      package_dir: Optional package subdirectory for generated files.
      proto_strip_prefix: Optional prefix to strip from proto include paths.
      export_macro: Optional export macro infix.
      export_macro_filename: Optional export macro header filename.
      extra_opts: Extra options passed to qtprotobufgen.
      protoc_tool: Label of the protoc executable.
      plugin_tool: Label of the qtprotobufgen executable.
      **kwargs: Additional rule attributes.
    """
    if protoc_tool == None:
        protoc_tool = "@qtgrpc//:protoc"
    if plugin_tool == None:
        plugin_tool = "@qtgrpc//:qtprotobufgen"
    _qt_protobuf_gen_rule(
        name = name,
        protos = protos,
        dep_protos = dep_protos,
        package_dir = package_dir,
        proto_strip_prefix = proto_strip_prefix,
        export_macro = export_macro,
        export_macro_filename = export_macro_filename,
        extra_opts = extra_opts,
        protoc_tool = protoc_tool,
        plugin_tool = plugin_tool,
        **kwargs
    )
    native.filegroup(
        name = name + "_hdrs",
        srcs = [":" + name],
        output_group = "hdrs",
        target_compatible_with = kwargs.get("target_compatible_with"),
        testonly = kwargs.get("testonly"),
    )
    native.filegroup(
        name = name + "_srcs",
        srcs = [":" + name],
        output_group = "srcs",
        target_compatible_with = kwargs.get("target_compatible_with"),
        testonly = kwargs.get("testonly"),
    )

def _qt_grpc_gen_impl(ctx):
    protoc = ctx.executable.protoc_tool
    plugin = ctx.executable.plugin_tool
    pkg_dir = ctx.attr.package_dir
    export_macro = ctx.attr.export_macro
    export_macro_filename = ctx.attr.export_macro_filename

    hdrs = []
    srcs = []
    out_base = ctx.label.name + "_out"
    out_base_path = None

    exp_hdr = None
    if export_macro and export_macro_filename:
        exp_hdr = ctx.actions.declare_file(out_base + "/" + export_macro_filename)
        hdrs.append(exp_hdr)
        out_base_path = exp_hdr.dirname

    proto_files = ctx.files.protos
    dep_proto_files = ctx.files.dep_protos
    inc_dirs = _compute_proto_inc_dirs(proto_files + dep_proto_files, ctx.attr.proto_strip_prefix, pkg_dir)

    for idx, proto in enumerate(proto_files):
        stem = proto.basename[:-6] if proto.basename.endswith(".proto") else proto.basename
        rel_prefix = (pkg_dir + "/") if pkg_dir else ""
        client_h = ctx.actions.declare_file(out_base + "/" + rel_prefix + stem + "_client.grpc.qpb.h")
        client_cpp = ctx.actions.declare_file(out_base + "/" + rel_prefix + stem + "_client.grpc.qpb.cpp")
        hdrs.append(client_h)
        srcs.append(client_cpp)
        step_outs = [client_h, client_cpp]
        if ctx.attr.qml:
            qml_h = ctx.actions.declare_file(out_base + "/" + rel_prefix + "qml" + stem + "_client.grpc.qpb.h")
            qml_cpp = ctx.actions.declare_file(out_base + "/" + rel_prefix + "qml" + stem + "_client.grpc.qpb.cpp")
            hdrs.append(qml_h)
            srcs.append(qml_cpp)
            step_outs.extend([qml_h, qml_cpp])
        if idx == 0 and exp_hdr != None:
            step_outs.append(exp_hdr)
        if out_base_path == None:
            if pkg_dir:
                out_base_path = client_h.dirname[:-len(pkg_dir) - 1]
            else:
                out_base_path = client_h.dirname

        opts = []
        if pkg_dir:
            opts.append("GENERATE_PACKAGE_SUBFOLDERS")
        if ctx.attr.qml:
            opts.append("QML")
        if export_macro:
            if export_macro_filename:
                emit_exp = "true" if idx == 0 else "false"
                opts.append("EXPORT_MACRO={}:{}:{}".format(export_macro, export_macro_filename, emit_exp))
            else:
                opts.append("EXPORT_MACRO={}".format(export_macro))
        for extra_opt in ctx.attr.extra_opts:
            opts.append(extra_opt)

        args = ctx.actions.args()
        args.add("--plugin=protoc-gen-qtgrpc=" + plugin.path)
        args.add("--qtgrpc_out=" + out_base_path)
        if opts:
            args.add("--qtgrpc_opt=" + ";".join(opts))
        for d in inc_dirs:
            args.add("-I" + d)
        args.add(proto.path)

        ctx.actions.run(
            executable = protoc,
            tools = [plugin],
            inputs = proto_files + dep_proto_files,
            outputs = step_outs,
            arguments = [args],
            mnemonic = "QtGrpcGen",
            progress_message = "Generating Qt gRPC sources for %s" % proto.short_path,
        )

    cc_inc_dirs = [out_base_path] if out_base_path else []
    if out_base_path and pkg_dir:
        cc_inc_dirs.append(out_base_path + "/" + pkg_dir)

    return [
        DefaultInfo(files = depset(srcs + hdrs)),
        CcInfo(
            compilation_context = cc_common.create_compilation_context(
                headers = depset(hdrs),
                includes = depset(cc_inc_dirs),
                system_includes = depset(cc_inc_dirs),
            ),
        ),
        CcSharedLibraryHintInfo(attributes = []),
        OutputGroupInfo(
            hdrs = depset(hdrs),
            srcs = depset(srcs),
        ),
    ]

_qt_grpc_gen_rule = rule(
    implementation = _qt_grpc_gen_impl,
    attrs = {
        "protos": attr.label_list(allow_files = [".proto"], mandatory = True),
        "dep_protos": attr.label_list(allow_files = [".proto"]),
        "package_dir": attr.string(default = ""),
        "proto_strip_prefix": attr.string(default = ""),
        "export_macro": attr.string(default = ""),
        "export_macro_filename": attr.string(default = ""),
        "qml": attr.bool(default = False),
        "extra_opts": attr.string_list(),
        "protoc_tool": attr.label(
            mandatory = True,
            executable = True,
            cfg = "exec",
        ),
        "plugin_tool": attr.label(
            mandatory = True,
            executable = True,
            cfg = "exec",
        ),
    },
    provides = [CcInfo],
)

def qt_grpc_gen(
        name,
        protos,
        dep_protos = [],
        package_dir = "",
        proto_strip_prefix = "",
        export_macro = "",
        export_macro_filename = "",
        qml = False,
        extra_opts = [],
        protoc_tool = None,
        plugin_tool = None,
        **kwargs):
    """Generates Qt gRPC client C++ headers and sources using protoc + qtgrpcgen.

    Args:
      name: Target name.
      protos: List of .proto files to compile.
      dep_protos: Additional .proto files imported by `protos`.
      package_dir: Optional package subdirectory for generated files.
      proto_strip_prefix: Optional prefix to strip from proto include paths.
      export_macro: Optional export macro infix.
      export_macro_filename: Optional export macro header filename.
      qml: Whether to generate QML gRPC client classes.
      extra_opts: Extra options passed to qtgrpcgen.
      protoc_tool: Label of the protoc executable.
      plugin_tool: Label of the qtgrpcgen executable.
      **kwargs: Additional rule attributes.
    """
    if protoc_tool == None:
        protoc_tool = "@qtgrpc//:protoc"
    if plugin_tool == None:
        plugin_tool = "@qtgrpc//:qtgrpcgen"
    _qt_grpc_gen_rule(
        name = name,
        protos = protos,
        dep_protos = dep_protos,
        package_dir = package_dir,
        proto_strip_prefix = proto_strip_prefix,
        export_macro = export_macro,
        export_macro_filename = export_macro_filename,
        qml = qml,
        extra_opts = extra_opts,
        protoc_tool = protoc_tool,
        plugin_tool = plugin_tool,
        **kwargs
    )
    native.filegroup(
        name = name + "_hdrs",
        srcs = [":" + name],
        output_group = "hdrs",
        target_compatible_with = kwargs.get("target_compatible_with"),
        testonly = kwargs.get("testonly"),
    )
    native.filegroup(
        name = name + "_srcs",
        srcs = [":" + name],
        output_group = "srcs",
        target_compatible_with = kwargs.get("target_compatible_with"),
        testonly = kwargs.get("testonly"),
    )
