"""Starlark rules for generating Wayland client and server C/C++ protocol sources."""

load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("@rules_cc//cc/common:cc_shared_library_hint_info.bzl", "CcSharedLibraryHintInfo")

def _qt_wayland_protocol_impl(ctx):
    wayland_scanner = ctx.executable.wayland_scanner_tool
    qtwaylandscanner = ctx.executable.qtwaylandscanner_tool
    mode = ctx.attr.mode
    include_dir = ctx.attr.include_dir
    build_macro = ctx.attr.build_macro
    is_for_module = ctx.attr.is_for_module

    hdrs = []
    srcs = []
    out_dir = None

    code_mode = "public-code" if is_for_module else "private-code"

    for proto in ctx.files.protocols:
        stem = proto.basename[:-4] if proto.basename.endswith(".xml") else proto.basename
        c_code_cmd = (
            'printf "/* Core wayland.xml C interfaces provided by @wayland */\\n" > "{c_src}"' if stem == "wayland" else '"{ws}" --include-core-only {cm} < "{proto}" > "{c_src}"'
        ).format(
            ws = wayland_scanner.path,
            cm = code_mode,
            proto = proto.path,
            c_src = "{c_src}",
        )
        if mode == "client":
            c_hdr = ctx.actions.declare_file(ctx.label.name + "_out/wayland-" + stem + "-client-protocol.h")
            c_src = ctx.actions.declare_file(ctx.label.name + "_out/wayland-" + stem + "-protocol.c")
            qt_hdr = ctx.actions.declare_file(ctx.label.name + "_out/qwayland-" + stem + ".h")
            qt_src = ctx.actions.declare_file(ctx.label.name + "_out/qwayland-" + stem + ".cpp")
            out_dir = c_hdr.dirname

            add_inc = "<QtWaylandClient/private/wayland-wayland-client-protocol.h>" if is_for_module else ""
            cmd = """set -e
"{ws}" --include-core-only client-header < "{proto}" > "{c_hdr}"
{c_code}
"{qws}" client-header "{proto}" --build-macro="{bm}" --header-path="{inc}" > "{qt_hdr}"
"{qws}" client-code "{proto}" --build-macro="{bm}" --header-path="{inc}" --add-include='{add_inc}' > "{qt_src}"
""".format(
                ws = wayland_scanner.path,
                qws = qtwaylandscanner.path,
                proto = proto.path,
                c_hdr = c_hdr.path,
                c_code = c_code_cmd.format(c_src = c_src.path),
                qt_hdr = qt_hdr.path,
                qt_src = qt_src.path,
                bm = build_macro,
                inc = include_dir,
                add_inc = add_inc,
            )
        else:
            c_hdr = ctx.actions.declare_file(ctx.label.name + "_out/wayland-" + stem + "-server-protocol.h")
            c_src = ctx.actions.declare_file(ctx.label.name + "_out/wayland-" + stem + "-protocol.c")
            qt_hdr = ctx.actions.declare_file(ctx.label.name + "_out/qwayland-server-" + stem + ".h")
            qt_src = ctx.actions.declare_file(ctx.label.name + "_out/qwayland-server-" + stem + ".cpp")
            out_dir = c_hdr.dirname

            cmd = """set -e
"{ws}" --include-core-only server-header < "{proto}" > "{c_hdr}"
{c_code}
"{qws}" server-header "{proto}" --build-macro="{bm}" --header-path="{inc}" > "{qt_hdr}"
"{qws}" server-code "{proto}" --build-macro="{bm}" --header-path="{inc}" > "{qt_src}"
""".format(
                ws = wayland_scanner.path,
                qws = qtwaylandscanner.path,
                proto = proto.path,
                c_hdr = c_hdr.path,
                c_code = c_code_cmd.format(c_src = c_src.path),
                qt_hdr = qt_hdr.path,
                qt_src = qt_src.path,
                bm = build_macro,
                inc = include_dir,
            )

        ctx.actions.run_shell(
            tools = [wayland_scanner, qtwaylandscanner],
            inputs = [proto],
            outputs = [c_hdr, c_src, qt_hdr, qt_src],
            command = cmd,
            mnemonic = "QtWaylandScanner",
            progress_message = "Generating Wayland %s protocol %s" % (mode, proto.short_path),
        )
        hdrs.extend([c_hdr, qt_hdr])
        srcs.extend([c_src, qt_src])

    inc_dirs = [out_dir] if out_dir else []
    return [
        DefaultInfo(files = depset(srcs + hdrs)),
        CcInfo(
            compilation_context = cc_common.create_compilation_context(
                headers = depset(hdrs),
                includes = depset(inc_dirs),
                system_includes = depset(inc_dirs),
            ),
        ),
        CcSharedLibraryHintInfo(attributes = []),
        OutputGroupInfo(
            hdrs = depset(hdrs),
            srcs = depset(srcs),
        ),
    ]

_qt_wayland_protocol_rule = rule(
    implementation = _qt_wayland_protocol_impl,
    attrs = {
        "protocols": attr.label_list(allow_files = [".xml"], mandatory = True),
        "mode": attr.string(default = "client", values = ["client", "server"]),
        "include_dir": attr.string(default = ""),
        "build_macro": attr.string(default = ""),
        "is_for_module": attr.bool(default = False),
        "wayland_scanner_tool": attr.label(
            mandatory = True,
            executable = True,
            cfg = "exec",
        ),
        "qtwaylandscanner_tool": attr.label(
            mandatory = True,
            executable = True,
            cfg = "exec",
        ),
    },
    provides = [CcInfo],
)

def qt_wayland_client_protocol(
        name,
        protocols,
        include_dir = "",
        build_macro = "",
        is_for_module = False,
        wayland_scanner_tool = None,
        qtwaylandscanner_tool = None,
        target_compatible_with = ["@platforms//os:linux"],
        **kwargs):
    """Generates Wayland client protocol headers and C/C++ sources, plus `<name>_hdrs` and `<name>_srcs` filegroups."""
    if wayland_scanner_tool == None:
        wayland_scanner_tool = native.package_relative_label("@wayland//:wayland_scanner")
    if qtwaylandscanner_tool == None:
        qtwaylandscanner_tool = native.package_relative_label("@qtbase//:qtwaylandscanner")
    _qt_wayland_protocol_rule(
        name = name,
        protocols = protocols,
        mode = "client",
        include_dir = include_dir,
        build_macro = build_macro,
        is_for_module = is_for_module,
        wayland_scanner_tool = wayland_scanner_tool,
        qtwaylandscanner_tool = qtwaylandscanner_tool,
        target_compatible_with = target_compatible_with,
        **kwargs
    )
    native.filegroup(
        name = name + "_hdrs",
        srcs = [":" + name],
        output_group = "hdrs",
        target_compatible_with = target_compatible_with,
    )
    native.filegroup(
        name = name + "_srcs",
        srcs = [":" + name],
        output_group = "srcs",
        target_compatible_with = target_compatible_with,
    )

def qt_wayland_server_protocol(
        name,
        protocols,
        include_dir = "",
        build_macro = "",
        wayland_scanner_tool = None,
        qtwaylandscanner_tool = None,
        target_compatible_with = ["@platforms//os:linux"],
        **kwargs):
    """Generates Wayland server protocol headers and C/C++ sources, plus `<name>_hdrs` and `<name>_srcs` filegroups."""
    if wayland_scanner_tool == None:
        wayland_scanner_tool = native.package_relative_label("@wayland//:wayland_scanner")
    if qtwaylandscanner_tool == None:
        qtwaylandscanner_tool = native.package_relative_label("@qtbase//:qtwaylandscanner")
    _qt_wayland_protocol_rule(
        name = name,
        protocols = protocols,
        mode = "server",
        include_dir = include_dir,
        build_macro = build_macro,
        wayland_scanner_tool = wayland_scanner_tool,
        qtwaylandscanner_tool = qtwaylandscanner_tool,
        target_compatible_with = target_compatible_with,
        **kwargs
    )
    native.filegroup(
        name = name + "_hdrs",
        srcs = [":" + name],
        output_group = "hdrs",
        target_compatible_with = target_compatible_with,
    )
    native.filegroup(
        name = name + "_srcs",
        srcs = [":" + name],
        output_group = "srcs",
        target_compatible_with = target_compatible_with,
    )
