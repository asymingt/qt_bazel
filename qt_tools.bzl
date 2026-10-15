"""Low-level Starlark rules for Qt code generation (syncqt, moc, export headers, qrc)."""

load("@rules_cc//cc:find_cc_toolchain.bzl", "find_cc_toolchain", "use_cc_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_helper.bzl", "cc_helper")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("@rules_cc//cc/common:feature_names.bzl", "feature_names")
load("@rules_cc//cc/common:semantics.bzl", cc_semantics = "semantics")

def _collect_cc_contexts(deps):
    contexts = []
    for dep in deps:
        if CcInfo in dep:
            contexts.append(dep[CcInfo].compilation_context)
    return contexts

def moc_out_copts(moc_target):
    """Returns copts that add a moc_gen target's output dir as a *local* include path.

    Unlike `cc_library(includes = ...)`, an `-I` in `copts` does not propagate to
    dependents. That matters because several Qt libraries generate identically named
    moc files (e.g. `moc_qeventdispatcher_glib_p.cpp` exists in both QtCore and QtGui),
    and a leaked include path would make a library pick up another library's moc output.

    Args:
      moc_target: Name of the `moc_gen` target in the calling package.

    Returns:
      A list with a single `-I<dir>` flag (`-I` rather than `-iquote` because Qt
      sources use both `#include "moc_x.cpp"` and `#include <moc_x.cpp>`).
    """
    repo = native.repo_name()
    pkg = native.package_name()
    parts = ["$(GENDIR)"]
    if repo:
        parts.append("external/" + repo)
    if pkg:
        parts.append(pkg)
    parts.append(moc_target + "_out")
    return ["-I" + "/".join(parts)]

QtMetaTypesInfo = provider(
    doc = "Carries a Qt module's collected metatypes JSON and its transitive foreign metatypes.",
    fields = {
        "direct_json": "File or None: this target's collected metatypes.json.",
        "transitive_jsons": "depset of File: metatypes.json files from transitive dependencies.",
    },
)

def _moc_gen_impl(ctx):
    moc = ctx.executable.moc_tool
    out_files = []
    json_files = []

    cc_contexts = _collect_cc_contexts(ctx.attr.deps)
    merged_context = cc_common.merge_compilation_contexts(compilation_contexts = cc_contexts)

    include_dirs = ["."]
    seen_inc = {".": True}
    for inc in ctx.attr.includes:
        if ctx.label.workspace_root:
            full_inc = ctx.label.workspace_root + "/" + inc if inc != "." else ctx.label.workspace_root
        else:
            full_inc = inc
        if full_inc not in seen_inc:
            seen_inc[full_inc] = True
            include_dirs.append(full_inc)

    ext_includes = getattr(merged_context, "external_includes", depset()).to_list()
    for inc in (
        merged_context.includes.to_list() +
        merged_context.system_includes.to_list() +
        merged_context.quote_includes.to_list() +
        ext_includes
    ):
        if inc and inc not in seen_inc:
            seen_inc[inc] = True
            include_dirs.append(inc)

    defines = []
    seen_def = {}
    for d in ctx.attr.defines + merged_context.defines.to_list() + merged_context.local_defines.to_list():
        if d and d not in seen_def:
            seen_def[d] = True
            defines.append(d)

    all_inputs = depset(
        direct = ctx.files.hdrs + ctx.files.srcs + ctx.files.other_hdrs + ctx.files.target_srcs,
        transitive = [merged_context.headers],
    )

    extra_args = []
    for opt in ctx.attr.copts:
        if opt.startswith("-I") or opt.startswith("-D") or opt.startswith("-F"):
            extra_args.append(opt)
    for opt in ctx.attr.moc_opts:
        extra_args.append(opt)

    target_src_paths = " ".join(['"{}"'.format(f.path) for f in ctx.files.target_srcs])

    for hdr in ctx.files.hdrs:
        stem = hdr.basename[:-len(hdr.extension) - 1] if hdr.extension else hdr.basename
        out_name = "moc_" + stem + ".cpp"
        out_file = ctx.actions.declare_file(ctx.label.name + "_out/" + out_name)
        json_file = ctx.actions.declare_file(ctx.label.name + "_out/" + out_name + ".json")
        out_files.append(out_file)
        json_files.append(json_file)

        args = ctx.actions.args()
        args.add("--no-warnings")
        args.add("--output-json")
        args.add("-I" + hdr.dirname)
        for inc in include_dirs:
            args.add("-I" + inc)
        for d in defines:
            if not d.startswith("-D"):
                args.add("-D" + d)
            else:
                args.add(d)
        for a in extra_args:
            args.add(a)
        rel_hdr = hdr.path
        if hdr.root.path and rel_hdr.startswith(hdr.root.path + "/"):
            rel_hdr = rel_hdr[len(hdr.root.path) + 1:]
        if hdr.owner and hdr.owner.workspace_root and rel_hdr.startswith(hdr.owner.workspace_root + "/"):
            rel_hdr = rel_hdr[len(hdr.owner.workspace_root) + 1:]
        args.add("-f" + rel_hdr)
        args.add(hdr.path)
        args.add("-o", out_file.path + ".tmp")

        if target_src_paths:
            cmd = """set -e
rm -f "{out}.tmp" "{out}.tmp.json"
touch "{out}.tmp"
"{moc}" "$@"
mv "{out}.tmp.json" "{json_out}"
if grep -q 'include *[<\"]{out_name}[\">]' {target_srcs} 2>/dev/null; then
  printf '#if __INCLUDE_LEVEL__ > 0\\n' > "{out}"
  cat "{out}.tmp" >> "{out}"
  printf '\\n#endif\\n' >> "{out}"
else
  mv "{out}.tmp" "{out}"
fi
rm -f "{out}.tmp"
""".format(
                out = out_file.path,
                json_out = json_file.path,
                out_name = out_name,
                moc = moc.path,
                target_srcs = target_src_paths,
            )
        else:
            cmd = """set -e
rm -f "{out}.tmp" "{out}.tmp.json"
touch "{out}.tmp"
"{moc}" "$@"
mv "{out}.tmp.json" "{json_out}"
mv "{out}.tmp" "{out}"
""".format(
                out = out_file.path,
                json_out = json_file.path,
                moc = moc.path,
            )

        ctx.actions.run_shell(
            tools = [moc],
            inputs = all_inputs,
            outputs = [out_file, json_file],
            arguments = [args],
            command = cmd,
            mnemonic = "QtMocHdr",
            progress_message = "Running moc on header %s" % hdr.short_path,
        )

    for src in ctx.files.srcs:
        stem = src.basename[:-len(src.extension) - 1] if src.extension else src.basename
        out_name = stem + ".moc"
        out_file = ctx.actions.declare_file(ctx.label.name + "_out/" + out_name)
        json_file = ctx.actions.declare_file(ctx.label.name + "_out/" + out_name + ".json")
        out_files.append(out_file)
        json_files.append(json_file)

        args = ctx.actions.args()
        args.add("--no-warnings")
        args.add("--output-json")
        args.add("-i")
        args.add("-I" + src.dirname)
        for inc in include_dirs:
            args.add("-I" + inc)
        for d in defines:
            if not d.startswith("-D"):
                args.add("-D" + d)
            else:
                args.add(d)
        for a in extra_args:
            args.add(a)
        args.add(src.path)
        args.add("-o", out_file.path)

        ctx.actions.run_shell(
            tools = [moc],
            inputs = all_inputs,
            outputs = [out_file, json_file],
            arguments = [args],
            command = 'touch "{out}" && "{moc}" "$@"'.format(
                out = out_file.path,
                moc = moc.path,
            ),
            mnemonic = "QtMocSrc",
            progress_message = "Running moc on source %s" % src.short_path,
        )

    collected_json = ctx.actions.declare_file(ctx.label.name + "_metatypes.json")
    if json_files:
        collect_args = ctx.actions.args()
        collect_args.add("--collect-json")
        collect_args.add("-o", collected_json.path)
        collect_args.add_all(json_files)
        ctx.actions.run(
            executable = moc,
            inputs = json_files,
            outputs = [collected_json],
            arguments = [collect_args],
            mnemonic = "QtMocCollectJson",
            progress_message = "Collecting metatypes JSON for %s" % ctx.label.name,
        )
    else:
        ctx.actions.write(
            output = collected_json,
            content = "[]\n",
        )

    transitive_jsons = [
        dep[QtMetaTypesInfo].transitive_jsons
        for dep in ctx.attr.deps
        if QtMetaTypesInfo in dep
    ]

    # AUTOMOC-style unity TU: compile every moc_<stem>.cpp through a single
    # mocs_compilation.cpp so that types forward-declared in one header are
    # already complete (via an earlier moc_*.cpp include) when a later moc
    # output needs them. moc outputs that are `#include`d by a target source
    # (wrapped in `#if __INCLUDE_LEVEL__ > 0`) are skipped to avoid duplicates.
    hdr_moc_files = out_files[:len(ctx.files.hdrs)]
    compile_srcs = out_files
    if ctx.attr.unity and hdr_moc_files:
        unity_file = ctx.actions.declare_file(ctx.label.name + "_out/" + ctx.label.name + "_mocs_compilation.cpp")
        unity_cmd = """set -e
out="$1"; shift
: > "$out"
for f in "$@"; do
  if head -n 1 "$f" | grep -q '__INCLUDE_LEVEL__'; then
    continue
  fi
  printf '#include "%s"\\n' "$(basename "$f")" >> "$out"
done
"""
        unity_args = ctx.actions.args()
        unity_args.add(unity_file.path)
        unity_args.add_all(hdr_moc_files)
        ctx.actions.run_shell(
            inputs = hdr_moc_files,
            outputs = [unity_file],
            arguments = [unity_args],
            command = unity_cmd,
            mnemonic = "QtMocUnity",
            progress_message = "Generating mocs_compilation.cpp for %s" % ctx.label.name,
        )
        out_files = out_files + [unity_file]
        compile_srcs = [unity_file] + out_files[len(hdr_moc_files):-1]

    return [
        DefaultInfo(files = depset(out_files)),
        OutputGroupInfo(
            metatypes_json = depset([collected_json]),
            compile_srcs = depset(compile_srcs),
        ),
        QtMetaTypesInfo(
            direct_json = collected_json,
            transitive_jsons = depset([collected_json], transitive = transitive_jsons),
        ),
    ]

_moc_gen_rule = rule(
    implementation = _moc_gen_impl,
    attrs = {
        "hdrs": attr.label_list(allow_files = [".h", ".hpp", ".hxx"]),
        "srcs": attr.label_list(allow_files = [".cpp", ".cc", ".cxx", ".mm"]),
        "target_srcs": attr.label_list(allow_files = True),
        "other_hdrs": attr.label_list(allow_files = True),
        "includes": attr.string_list(),
        "defines": attr.string_list(),
        "copts": attr.string_list(),
        "moc_opts": attr.string_list(),
        "deps": attr.label_list(),
        "unity": attr.bool(default = False),
        "moc_tool": attr.label(
            mandatory = True,
            executable = True,
            cfg = "exec",
        ),
    },
)

# Compiler-predefined macros that moc does not know about. Qt's generated config
# headers (qtcore-config_p.h etc.) select feature values with `#ifdef __linux__`
# / `__APPLE__`, so without these moc evaluates QT_CONFIG(...) differently from
# the compiler and silently drops guarded Q_OBJECT classes. This is the Bazel
# equivalent of the `moc_predefs.h` that Qt's CMake build feeds to moc.
_MOC_PLATFORM_DEFINES = select({
    Label("@platforms//os:linux"): [
        "__linux__",
        "__gnu_linux__",
        "__unix__",
        "__unix",
        "__ELF__",
        "__GNUC__=10",
        "__GNUC_MINOR__=0",
    ],
    Label("@platforms//os:macos"): [
        "__APPLE__",
        "__MACH__",
        "__unix__",
        "__unix",
        "__GNUC__=10",
        "__GNUC_MINOR__=0",
        "TARGET_OS_MAC=1",
        "TARGET_OS_OSX=1",
        "TARGET_OS_IPHONE=0",
    ],
    Label("@platforms//os:windows"): [
        "_WIN32",
        "_WIN64",
        "WIN32",
        "WIN64",
        "__MINGW32__",
        "__MINGW64__",
        "UNICODE",
        "_UNICODE",
        "NOMINMAX",
        "_WIN32_WINNT=0x0A00",
        "WINVER=0x0A00",
        "__GNUC__=10",
        "__GNUC_MINOR__=0",
    ],
    "//conditions:default": [],
}) + select({
    Label("@platforms//cpu:x86_64"): [
        "__x86_64__",
        "__x86_64",
        "__amd64__",
        "__amd64",
        "__LP64__",
    ],
    Label("@platforms//cpu:aarch64"): [
        "__aarch64__",
        "__ARM_NEON",
        "__LITTLE_ENDIAN__",
        "__LP64__",
    ],
    "//conditions:default": [],
})

def moc_gen(moc_tool = None, defines = [], **kwargs):
    if moc_tool == None:
        moc_tool = native.package_relative_label("@qtbase//:moc")
    _moc_gen_rule(moc_tool = moc_tool, defines = defines + _MOC_PLATFORM_DEFINES, **kwargs)

def _qt_sync_headers_impl(ctx):
    syncqt = ctx.executable.syncqt_tool
    mod = ctx.attr.module_name
    ver = ctx.attr.version
    inc_dir = ctx.actions.declare_directory(ctx.label.name + "_include")

    if ctx.label.workspace_root:
        src_dir = ctx.label.workspace_root + "/" + ctx.attr.source_dir if ctx.attr.source_dir else ctx.label.workspace_root
    else:
        src_dir = ctx.attr.source_dir if ctx.attr.source_dir else "."

    pub_out = inc_dir.path + "/" + mod
    priv_out = inc_dir.path + "/" + mod + "/" + ver + "/" + mod + "/private"
    qpa_out = inc_dir.path + "/" + mod + "/" + ver + "/" + mod + "/qpa"
    rhi_out = inc_dir.path + "/" + mod + "/" + mod_rhi_subpath(ver, mod)
    ssg_out = inc_dir.path + "/" + mod + "/" + ver + "/" + mod + "/ssg"

    cmds = [
        "set -e",
        'mkdir -p "{pub}" "{priv}" "{qpa}" "{rhi}" "{ssg}"'.format(
            pub = pub_out,
            priv = priv_out,
            qpa = qpa_out,
            rhi = rhi_out,
            ssg = ssg_out,
        ),
    ]

    for f in ctx.files.generated_public_hdrs:
        cmds.append('cp -f "{src}" "{dst}/"'.format(src = f.path, dst = pub_out))
        if "_out/" in f.path:
            rel_out = f.path.split("_out/", 1)[1]
            if "/" in rel_out:
                sub_dir = pub_out + "/" + rel_out.rsplit("/", 1)[0]
                cmds.append('mkdir -p "{sub}" && cp -f "{src}" "{sub}/"'.format(src = f.path, sub = sub_dir))
        if f.basename == "qconfig.h":
            cmds.append('printf \'#include "qconfig.h" // IWYU pragma: export\\n\' > "{dst}/QtConfig"'.format(dst = pub_out))

    for f in ctx.files.generated_private_hdrs:
        cmds.append('cp -f "{src}" "{dst}/"'.format(src = f.path, dst = priv_out))
        if "_out/" in f.path:
            rel_out = f.path.split("_out/", 1)[1]
            if "/" in rel_out:
                sub_dir = priv_out + "/" + rel_out.rsplit("/", 1)[0]
                cmds.append('mkdir -p "{sub}" && cp -f "{src}" "{sub}/"'.format(src = f.path, sub = sub_dir))

    if ctx.files.hdrs:
        first_hdr = ctx.files.hdrs[0]
        rel_hdr = first_hdr.path[len(src_dir) + 1:] if first_hdr.path.startswith(src_dir + "/") else first_hdr.basename
        cmds.append('REAL_FIRST=$(realpath "{first_hdr}")'.format(first_hdr = first_hdr.path))
        cmds.append('REAL_SRC_DIR="${{REAL_FIRST%/{rel_hdr}}}"'.format(rel_hdr = rel_hdr))

        syncqt_cmd = [
            '"{syncqt}"'.format(syncqt = syncqt.path),
            "-all",
            "-copy",
            '-sourceDir "$REAL_SRC_DIR"',
            '-binaryDir "{bin_dir}"'.format(bin_dir = inc_dir.path),
            '-module "{mod}"'.format(mod = mod),
            '-includeDir "{pub}"'.format(pub = pub_out),
            '-privateIncludeDir "{priv}"'.format(priv = priv_out),
            '-qpaIncludeDir "{qpa}"'.format(qpa = qpa_out),
            '-rhiIncludeDir "{rhi}"'.format(rhi = rhi_out),
            '-ssgIncludeDir "{ssg}"'.format(ssg = ssg_out),
            '-privateHeadersFilter "{pf}"'.format(pf = ctx.attr.private_filter),
        ]
        if ctx.attr.qpa_filter:
            syncqt_cmd.append('-qpaHeadersFilter "{qf}"'.format(qf = ctx.attr.qpa_filter))
        if ctx.attr.rhi_filter:
            syncqt_cmd.append('-rhiHeadersFilter "{rf}"'.format(rf = ctx.attr.rhi_filter))
        if ctx.attr.ssg_filter:
            syncqt_cmd.append('-ssgHeadersFilter "{sf}"'.format(sf = ctx.attr.ssg_filter))
        ns_filter = ctx.attr.public_namespace_filter
        if not ns_filter and mod.startswith("Qt3D"):
            ns_filter = "^::Qt3D.*"
        if ns_filter:
            syncqt_cmd.append('-publicNamespaceFilter "{nf}"'.format(nf = ns_filter))
        if ctx.attr.internal_module:
            syncqt_cmd.append("-internal")
        if ctx.attr.non_qt:
            syncqt_cmd.append("-nonQt")

        cmds.append(" ".join(syncqt_cmd))

    all_inputs = ctx.files.hdrs + ctx.files.generated_public_hdrs + ctx.files.generated_private_hdrs

    ctx.actions.run_shell(
        tools = [syncqt],
        inputs = all_inputs,
        outputs = [inc_dir],
        command = "\n".join(cmds),
        mnemonic = "QtSyncHeaders",
        progress_message = "Running syncqt for %s" % mod,
    )

    inc_paths = [
        inc_dir.path,
        pub_out,
        inc_dir.path + "/" + mod + "/" + ver,
        inc_dir.path + "/" + mod + "/" + ver + "/" + mod,
    ]

    own_cc_context = cc_common.create_compilation_context(
        headers = depset([inc_dir] + all_inputs),
        includes = depset(inc_paths),
        system_includes = depset(inc_paths),
    )

    dep_contexts = _collect_cc_contexts(ctx.attr.deps)
    merged_context = cc_common.merge_compilation_contexts(
        compilation_contexts = [own_cc_context] + dep_contexts,
    )

    return [
        DefaultInfo(files = depset([inc_dir])),
        CcInfo(compilation_context = merged_context),
    ]

def mod_rhi_subpath(ver, mod):
    return ver + "/" + mod + "/rhi"

_qt_sync_headers_rule = rule(
    implementation = _qt_sync_headers_impl,
    attrs = {
        "module_name": attr.string(mandatory = True),
        "version": attr.string(default = "6.10.2"),
        "source_dir": attr.string(mandatory = True),
        "hdrs": attr.label_list(allow_files = True),
        "generated_public_hdrs": attr.label_list(allow_files = True),
        "generated_private_hdrs": attr.label_list(allow_files = True),
        "private_filter": attr.string(default = "^.+_p(ch)?\\.h$"),
        "qpa_filter": attr.string(default = ""),
        "rhi_filter": attr.string(default = ""),
        "ssg_filter": attr.string(default = ""),
        "public_namespace_filter": attr.string(default = ""),
        "internal_module": attr.bool(default = False),
        "non_qt": attr.bool(default = False),
        "deps": attr.label_list(),
        "syncqt_tool": attr.label(
            mandatory = True,
            executable = True,
            cfg = "exec",
        ),
    },
    provides = [CcInfo],
)

def _infer_source_dir(hdrs):
    str_hdrs = [h for h in (hdrs or []) if type(h) == type("") and not h.startswith(":")]
    if not str_hdrs:
        return "."
    first_parts = str_hdrs[0].split("/")[:-1]
    for h in str_hdrs[1:]:
        parts = h.split("/")[:-1]
        common = []
        for a, b in zip(first_parts, parts):
            if a == b:
                common.append(a)
            else:
                break
        first_parts = common
    return "/".join(first_parts) if first_parts else "."

def qt_sync_headers(
        name,
        module_name,
        syncqt_tool = None,
        srcs = None,
        hdrs = None,
        source_dir = None,
        generated_public_hdrs = [],
        dep_modules = None,
        non_qt = False,
        **kwargs):
    """Runs syncqt to stage a Qt module's headers (see `_qt_sync_headers_rule`).

    Args:
      name: Target name.
      module_name: Qt module name (e.g. `QtWebSockets`).
      syncqt_tool: Label of the syncqt executable; defaults to `@qtbase//:syncqt`.
      srcs: Alias for `hdrs`.
      hdrs: Headers to run syncqt on.
      source_dir: Source directory; inferred from `hdrs` if omitted.
      generated_public_hdrs: Extra generated public headers to stage. If none of
        them provides the `<Module>Depends` umbrella header, one is generated
        (from `dep_modules`) so that `#include <Module/Module>` works.
      dep_modules: Modules listed in the generated `<Module>Depends` header.
      non_qt: Forwarded to the rule.
      **kwargs: Forwarded to `_qt_sync_headers_rule`.
    """
    if syncqt_tool == None:
        syncqt_tool = native.package_relative_label("@qtbase//:syncqt")
    if hdrs == None and srcs != None:
        hdrs = srcs
    if source_dir == None:
        source_dir = _infer_source_dir(hdrs)
    pub_hdrs = list(generated_public_hdrs)
    has_depends = False
    for h in pub_hdrs:
        if "Depends" in str(h) or "_depends_h" in str(h):
            has_depends = True
    if not has_depends and not non_qt:
        depends_target = name + "_depends_h"
        qt_depends_header(
            name = depends_target,
            out = name + "_gen/" + module_name + "Depends",
            dep_modules = dep_modules or [],
            target_compatible_with = kwargs.get("target_compatible_with"),
        )
        pub_hdrs.append(":" + depends_target)
    _qt_sync_headers_rule(
        name = name,
        module_name = module_name,
        source_dir = source_dir,
        syncqt_tool = syncqt_tool,
        hdrs = hdrs or [],
        generated_public_hdrs = pub_hdrs,
        non_qt = non_qt,
        **kwargs
    )

_EXPORT_HEADER_TEMPLATE = """// Copyright (C) 2022 The Qt Company Ltd.
// SPDX-License-Identifier: LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only

#ifndef {guard}
#define {guard}

#include <QtCore/qcompilerdetection.h>
#include <QtCore/qtconfigmacros.h> // Q_{infix}_EXPORT
#include <QtCore/qtdeprecationmarkers.h> // QT_DEPRECATED_VERSION_X_{infix}

#ifdef __MINGW32__
#  undef Q_DECL_EXPORT
#  undef Q_DECL_IMPORT
#  define Q_DECL_EXPORT
#  define Q_DECL_IMPORT
#endif

#if (defined(QT_SHARED) || !defined(QT_STATIC)) && !defined(QT_STATIC_{infix}_LIB)
#  if defined(QT_BUILD_{infix}_LIB)
#    define Q_{infix}_EXPORT Q_DECL_EXPORT
#  else
#    define Q_{infix}_EXPORT Q_DECL_IMPORT
#  endif
#else
#  define Q_{infix}_EXPORT
#endif

#define QT_{infix}_INLINE_SINCE(major, minor) inline
#define QT_{infix}_CONSTEXPR_INLINE_SINCE(major, minor) constexpr
#define QT_{infix}_INLINE_IMPL_SINCE(major, minor) 1
#define QT_{infix}_REMOVED_SINCE(major, minor) 0

#endif // {guard}
"""

def _qt_export_header_impl(ctx):
    out = ctx.actions.declare_file(ctx.attr.out)
    infix = ctx.attr.module_infix.upper()
    guard = "QT" + infix + "EXPORTS_H"
    content = _EXPORT_HEADER_TEMPLATE.format(guard = guard, infix = infix)
    ctx.actions.write(out, content)
    return [
        DefaultInfo(files = depset([out])),
        CcInfo(
            compilation_context = cc_common.create_compilation_context(
                headers = depset([out]),
                includes = depset([out.dirname]),
            ),
        ),
    ]

qt_export_header = rule(
    implementation = _qt_export_header_impl,
    attrs = {
        "module_infix": attr.string(mandatory = True),
        "out": attr.string(mandatory = True),
    },
    provides = [CcInfo],
)

def _qt_depends_header_impl(ctx):
    out = ctx.actions.declare_file(ctx.attr.out)
    lines = [
        "/* This file was generated by Bazel. */",
        "#ifdef __cplusplus /* create empty PCH in C mode */",
    ]
    for dep_mod in ctx.attr.dep_modules:
        lines.append("#  include <{m}/{m}>".format(m = dep_mod))
    lines.append("#endif")
    lines.append("")
    ctx.actions.write(out, "\n".join(lines))
    return [DefaultInfo(files = depset([out]))]

qt_depends_header = rule(
    implementation = _qt_depends_header_impl,
    attrs = {
        "out": attr.string(mandatory = True),
        "dep_modules": attr.string_list(),
    },
)

def _repo_rel_path(f):
    p = f.short_path
    if p.startswith("../"):
        parts = p.split("/", 2)
        if len(parts) == 3:
            return parts[2]
    return p

def _qt_generate_qrc_impl(ctx):
    out = ctx.actions.declare_file(ctx.attr.out)
    lines = [
        "<RCC>",
        '    <qresource prefix="{prefix}">'.format(prefix = ctx.attr.prefix),
    ]
    strip_dir = ctx.attr.strip_prefix
    if strip_dir and not strip_dir.endswith("/"):
        strip_dir = strip_dir + "/"

    out_dir_parts = [p for p in out.dirname.split("/") if p]
    up_prefix = "../" * len(out_dir_parts)

    for i, f in enumerate(ctx.files.srcs):
        if ctx.attr.aliases and i < len(ctx.attr.aliases) and ctx.attr.aliases[i]:
            rel_alias = ctx.attr.aliases[i]
        else:
            rel_alias = _repo_rel_path(f)
            if strip_dir and rel_alias.startswith(strip_dir):
                rel_alias = rel_alias[len(strip_dir):]
            else:
                rel_alias = f.basename
        lines.append('        <file alias="{alias}">{path}</file>'.format(
            alias = rel_alias,
            path = up_prefix + f.path,
        ))
    lines.extend([
        "    </qresource>",
        "</RCC>",
        "",
    ])
    ctx.actions.write(out, "\n".join(lines))
    return [DefaultInfo(files = depset([out]))]

qt_generate_qrc = rule(
    implementation = _qt_generate_qrc_impl,
    attrs = {
        "out": attr.string(mandatory = True),
        "prefix": attr.string(mandatory = True),
        "strip_prefix": attr.string(default = ""),
        "srcs": attr.label_list(allow_files = True),
        "aliases": attr.string_list(default = []),
    },
)

def _qt_rcc_internal_impl(ctx):
    rcc = ctx.executable.rcc_tool
    out = ctx.actions.declare_file("qrc_" + ctx.label.name + ".cpp")
    args = ctx.actions.args()
    for opt in ctx.attr.rcc_options:
        args.add(opt)
    args.add("--name", ctx.attr.qrc_name)
    args.add("--output", out.path)
    args.add(ctx.file.qrc.path)
    ctx.actions.run(
        executable = rcc,
        inputs = [ctx.file.qrc] + ctx.files.data,
        outputs = [out],
        arguments = [args],
        env = {"QT_RCC_SOURCE_DATE_OVERRIDE": "1"},
        mnemonic = "QtRcc",
        progress_message = "Running rcc on %s" % ctx.file.qrc.short_path,
    )
    return [DefaultInfo(files = depset([out]))]

_qt_rcc_internal_rule = rule(
    implementation = _qt_rcc_internal_impl,
    attrs = {
        "qrc": attr.label(allow_single_file = [".qrc"], mandatory = True),
        "qrc_name": attr.string(mandatory = True),
        "data": attr.label_list(allow_files = True),
        "rcc_options": attr.string_list(default = []),
        "rcc_tool": attr.label(
            mandatory = True,
            executable = True,
            cfg = "exec",
        ),
    },
)

def qt_rcc_internal(rcc_tool = None, **kwargs):
    if rcc_tool == None:
        rcc_tool = native.package_relative_label("@qtbase//:rcc")
    _qt_rcc_internal_rule(rcc_tool = rcc_tool, **kwargs)

def _qt_lalr_impl(ctx):
    qlalr = ctx.executable.qlalr_tool
    grammar = ctx.file.grammar
    outs = ctx.outputs.outs
    out_dir = outs[0].dirname

    flags = " ".join(['"{}"'.format(f) for f in ctx.attr.flags])
    cmd = """set -e
TOOL=$(realpath "{qlalr}")
GRAMMAR=$(realpath "{grammar}")
cd "{out_dir}"
"$TOOL" {flags} "$GRAMMAR"
""".format(
        qlalr = qlalr.path,
        grammar = grammar.path,
        out_dir = out_dir,
        flags = flags,
    )

    ctx.actions.run_shell(
        tools = [qlalr],
        inputs = [grammar],
        outputs = outs,
        command = cmd,
        mnemonic = "QtLalr",
        progress_message = "Running qlalr on %s" % grammar.short_path,
    )
    return [DefaultInfo(files = depset(outs))]

_qt_lalr_rule = rule(
    implementation = _qt_lalr_impl,
    attrs = {
        "grammar": attr.label(allow_single_file = [".g"], mandatory = True),
        "outs": attr.output_list(mandatory = True),
        "flags": attr.string_list(default = ["--no-debug", "--qt"]),
        "qlalr_tool": attr.label(
            mandatory = True,
            executable = True,
            cfg = "exec",
        ),
    },
)

def qt_lalr(qlalr_tool = None, **kwargs):
    if qlalr_tool == None:
        qlalr_tool = native.package_relative_label("@qtbase//:qlalr")
    _qt_lalr_rule(qlalr_tool = qlalr_tool, **kwargs)

def _qt_qml_type_registration_impl(ctx):
    tool = ctx.executable.qmltyperegistrar_tool
    metatypes_json = ctx.attr.metatypes[QtMetaTypesInfo].direct_json

    out_cpp = ctx.actions.declare_file(ctx.label.name + "_qmltyperegistrations.cpp")
    out_qmltypes = ctx.actions.declare_file(ctx.label.name + "_qmltypes/plugins.qmltypes")

    foreign_jsons = []
    for fTarget in ctx.attr.foreign_types:
        if QtMetaTypesInfo in fTarget:
            foreign_jsons.extend(fTarget[QtMetaTypesInfo].transitive_jsons.to_list())
        else:
            foreign_jsons.extend(fTarget.files.to_list())

    args = ctx.actions.args()
    args.add("--generate-qmltypes=" + out_qmltypes.path)
    args.add("--import-name=" + ctx.attr.import_name)
    args.add("--major-version=" + ctx.attr.major_version)
    args.add("--minor-version=" + ctx.attr.minor_version)
    if ctx.attr.follow_foreign_versioning:
        args.add("--follow-foreign-versioning")
    if ctx.attr.private_includes:
        args.add("--private-includes")
    for pmv in ctx.attr.past_major_versions:
        args.add("--past-major-version")
        args.add(pmv)
    if foreign_jsons:
        args.add("--foreign-types=" + ",".join([f.path for f in foreign_jsons]))
    args.add("-o", out_cpp.path)
    args.add(metatypes_json.path)

    outs = [out_cpp, out_qmltypes]
    if ctx.attr.generate_jsroot:
        jsroot_qmltypes = ctx.actions.declare_file(ctx.label.name + "_qmltypes/jsroot.qmltypes")
        js_args = ctx.actions.args()
        js_args.add("--jsroot")
        js_args.add("--generate-qmltypes", jsroot_qmltypes.path)
        ctx.actions.run(
            executable = tool,
            inputs = [],
            outputs = [jsroot_qmltypes],
            arguments = [js_args],
            mnemonic = "QtQmlJsRootTypes",
            progress_message = "Generating jsroot.qmltypes for %s" % ctx.label.name,
        )
        outs.append(jsroot_qmltypes)

    ctx.actions.run(
        executable = tool,
        inputs = [metatypes_json] + foreign_jsons,
        outputs = [out_cpp, out_qmltypes],
        arguments = [args],
        mnemonic = "QtQmlTypeRegistrar",
        progress_message = "Running qmltyperegistrar for %s (%s)" % (ctx.label.name, ctx.attr.import_name),
    )

    return [
        DefaultInfo(files = depset([out_cpp])),
        OutputGroupInfo(
            qmltypes = depset(outs[1:]),
            all_files = depset(outs),
        ),
    ]

_qt_qml_type_registration_rule = rule(
    implementation = _qt_qml_type_registration_impl,
    attrs = {
        "metatypes": attr.label(mandatory = True, providers = [QtMetaTypesInfo]),
        "import_name": attr.string(mandatory = True),
        "major_version": attr.string(default = "6"),
        "minor_version": attr.string(default = "10"),
        "past_major_versions": attr.string_list(default = []),
        "follow_foreign_versioning": attr.bool(default = True),
        "private_includes": attr.bool(default = True),
        "foreign_types": attr.label_list(default = []),
        "generate_jsroot": attr.bool(default = False),
        "qmltyperegistrar_tool": attr.label(
            mandatory = True,
            executable = True,
            cfg = "exec",
        ),
    },
)

def qt_qml_type_registration(qmltyperegistrar_tool = None, **kwargs):
    if qmltyperegistrar_tool == None:
        qmltyperegistrar_tool = native.package_relative_label("@qtdeclarative//:qmltyperegistrar")
    _qt_qml_type_registration_rule(qmltyperegistrar_tool = qmltyperegistrar_tool, **kwargs)

def _qt_write_file_impl(ctx):
    out = ctx.actions.declare_file(ctx.attr.out)
    ctx.actions.write(
        output = out,
        content = ctx.attr.content,
    )
    inc_dirs = [out.dirname]
    if "/" in ctx.attr.out:
        top_sub = ctx.attr.out.split("/", 1)[0]
        marker = "/" + top_sub + "/"
        if marker in out.path:
            root_inc = out.path.split(marker, 1)[0] + "/" + top_sub
            if root_inc not in inc_dirs:
                inc_dirs.append(root_inc)
    return [
        DefaultInfo(files = depset([out])),
        CcInfo(
            compilation_context = cc_common.create_compilation_context(
                headers = depset([out]),
                includes = depset(inc_dirs),
            ),
        ),
    ]

qt_write_file = rule(
    implementation = _qt_write_file_impl,
    attrs = {
        "out": attr.string(mandatory = True),
        "content": attr.string(mandatory = True),
    },
    provides = [CcInfo],
)

def qt_qmldir(
        name,
        uri,
        content,
        rcc_tool = None,
        tags = []):
    """Writes a qmldir file for `uri` and embeds it via rcc under /qt-project.org/imports/<uri_path>.

    Args:
      name: Target name.
      uri: QML module URI.
      content: Text content of the qmldir file.
      rcc_tool: Optional rcc binary label.
      tags: Optional Bazel tags.
    """
    uri_path = uri.replace(".", "/")
    qrc_name = "qmake_" + uri.replace(".", "_")
    qmldir_target = name + "_qmldir_file"
    qmldir_out = name + "_qmldir/qmldir"
    qt_write_file(
        name = qmldir_target,
        out = qmldir_out,
        content = content,
        tags = tags,
    )
    qrc_target = name + "_qmldir_qrc"
    qt_generate_qrc(
        name = qrc_target,
        out = name + "_qmldir.qrc",
        prefix = "/qt-project.org/imports/" + uri_path,
        srcs = [":" + qmldir_target],
        tags = tags,
    )
    qt_rcc_internal(
        name = name,
        qrc = ":" + qrc_target,
        qrc_name = qrc_name,
        data = [":" + qmldir_target],
        rcc_tool = rcc_tool,
        tags = tags,
    )

_QML_PLUGIN_TEMPLATE = """// This file is autogenerated by Bazel. Do not edit.

#include <QtCore/qtsymbolmacros.h>
#include <QtQml/qqmlextensionplugin.h>

QT_DECLARE_EXTERN_RESOURCE({qrc_name})
QT_DECLARE_EXTERN_SYMBOL_VOID(qml_register_types_{escaped_uri})

class {class_name} : public QQmlEngineExtensionPlugin
{{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlEngineExtensionInterface_iid)

public:
    {class_name}(QObject *parent = nullptr) : QQmlEngineExtensionPlugin(parent)
    {{
        QT_KEEP_SYMBOL(qml_register_types_{escaped_uri})
        QT_KEEP_RESOURCE({qrc_name})
    }}
}};

#include "{stem}.moc"
"""

def _qt_qml_plugin_gen_impl(ctx):
    stem = ctx.attr.plugin_name + "_" + ctx.attr.class_name
    out = ctx.actions.declare_file(stem + ".cpp")
    escaped_uri = (
        ctx.attr.uri
            .replace(".", "_")
            .replace("-", "_")
            .replace("/", "_")
    )
    qrc_name = "qmake_" + ctx.attr.uri.replace(".", "_")
    content = _QML_PLUGIN_TEMPLATE.format(
        class_name = ctx.attr.class_name,
        escaped_uri = escaped_uri,
        qrc_name = qrc_name,
        stem = stem,
    )
    ctx.actions.write(out, content)
    return [DefaultInfo(files = depset([out]))]

qt_qml_plugin_gen = rule(
    implementation = _qt_qml_plugin_gen_impl,
    attrs = {
        "plugin_name": attr.string(mandatory = True),
        "class_name": attr.string(mandatory = True),
        "uri": attr.string(mandatory = True),
    },
)

_QML_PLUGIN_CPP_TEMPLATE = """// This file is autogenerated by Bazel. Do not edit.

#include <QtCore/qtsymbolmacros.h>
#include <QtQml/qqmlextensionplugin.h>

class {class_name} : public QQmlEngineExtensionPlugin
{{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlEngineExtensionInterface_iid)

public:
    {class_name}(QObject *parent = nullptr) : QQmlEngineExtensionPlugin(parent)
    {{
    }}
}};

#include "{stem}.moc"
"""

def _qt_qml_plugin_cpp_impl(ctx):
    out = ctx.actions.declare_file(ctx.attr.out)
    stem = out.basename
    if stem.endswith(".cpp"):
        stem = stem[:-4]
    content = _QML_PLUGIN_CPP_TEMPLATE.format(
        class_name = ctx.attr.plugin_class_name,
        stem = stem,
    )
    ctx.actions.write(out, content)
    return [DefaultInfo(files = depset([out]))]

qt_qml_plugin_cpp = rule(
    implementation = _qt_qml_plugin_cpp_impl,
    attrs = {
        "out": attr.string(mandatory = True),
        "plugin_class_name": attr.string(mandatory = True),
        "registration_func": attr.string(default = ""),
        "uri": attr.string(mandatory = True),
    },
)

def _qt_qsb_gen_impl(ctx):
    qsb = ctx.executable.qsb_tool
    srcs = ctx.files.srcs
    outputs = ctx.attr.outputs
    strip_prefix = ctx.attr.strip_prefix
    if strip_prefix and not strip_prefix.endswith("/"):
        strip_prefix = strip_prefix + "/"

    qsb_files = []
    aliases = []

    for i, src in enumerate(srcs):
        if outputs and i < len(outputs):
            rel_out = outputs[i]
        else:
            rel_src = _repo_rel_path(src)
            if strip_prefix and rel_src.startswith(strip_prefix):
                rel_src = rel_src[len(strip_prefix):]
            rel_out = rel_src + ".qsb"

        out_file = ctx.actions.declare_file(ctx.label.name + "_qsb/" + rel_out)
        args = ctx.actions.args()
        args.add("--glsl", ctx.attr.glsl)
        args.add("--hlsl", ctx.attr.hlsl)
        args.add("--msl", ctx.attr.msl)
        if ctx.attr.batchable:
            args.add("-b")
        if ctx.attr.optimized:
            args.add("-O")
        if ctx.attr.silent:
            args.add("-s")
        if ctx.attr.pertargetcompile:
            args.add("-p")
        if ctx.attr.zorder_loc >= 0:
            args.add("--zorder-loc", str(ctx.attr.zorder_loc))
        if ctx.attr.view_count > 0:
            args.add("--view-count", str(ctx.attr.view_count))
        for d in ctx.attr.defines:
            args.add("-D", d)
        args.add("-o", out_file.path)
        args.add(src.path)

        ctx.actions.run(
            executable = qsb,
            inputs = [src] + ctx.files.hdrs,
            outputs = [out_file],
            arguments = [args],
            mnemonic = "QtQsb",
            progress_message = "Compiling shader %s -> %s" % (src.short_path, rel_out),
        )
        qsb_files.append(out_file)
        aliases.append(rel_out)

        if ctx.attr.multiview:
            mv_rel_out = rel_out + ".mv2qsb"
            mv_out_file = ctx.actions.declare_file(ctx.label.name + "_qsb/" + mv_rel_out)
            mv_args = ctx.actions.args()
            mv_args.add("--glsl", "330,300es")
            mv_args.add("--hlsl", "61")
            mv_args.add("--msl", "21")
            mv_args.add("--view-count", "2")
            if ctx.attr.batchable:
                mv_args.add("-b")
            if ctx.attr.optimized:
                mv_args.add("-O")
            if ctx.attr.silent:
                mv_args.add("-s")
            if ctx.attr.pertargetcompile:
                mv_args.add("-p")
            if ctx.attr.zorder_loc >= 0:
                mv_args.add("--zorder-loc", str(ctx.attr.zorder_loc))
            for d in ctx.attr.defines:
                mv_args.add("-D", d)
            mv_args.add("-o", mv_out_file.path)
            mv_args.add(src.path)

            ctx.actions.run(
                executable = qsb,
                inputs = [src] + ctx.files.hdrs,
                outputs = [mv_out_file],
                arguments = [mv_args],
                mnemonic = "QtQsbMultiview",
                progress_message = "Compiling multiview shader %s -> %s" % (src.short_path, mv_rel_out),
            )
            qsb_files.append(mv_out_file)
            aliases.append(mv_rel_out)

    qrc_out = ctx.actions.declare_file(ctx.label.name + ".qrc")
    out_dir_parts = [p for p in qrc_out.dirname.split("/") if p]
    up_prefix = "../" * len(out_dir_parts)

    lines = [
        "<RCC>",
        '    <qresource prefix="{prefix}">'.format(prefix = ctx.attr.prefix),
    ]
    for f, alias in zip(qsb_files, aliases):
        lines.append('        <file alias="{alias}">{path}</file>'.format(
            alias = alias,
            path = up_prefix + f.path,
        ))
    lines.extend([
        "    </qresource>",
        "</RCC>",
        "",
    ])
    ctx.actions.write(qrc_out, "\n".join(lines))

    rcc = ctx.executable.rcc_tool
    cpp_out = ctx.actions.declare_file("qrc_" + ctx.label.name + ".cpp")
    rcc_args = ctx.actions.args()
    rcc_args.add("--name", ctx.attr.qrc_name if ctx.attr.qrc_name else ctx.label.name)
    rcc_args.add("--output", cpp_out.path)
    rcc_args.add(qrc_out.path)
    ctx.actions.run(
        executable = rcc,
        inputs = [qrc_out] + qsb_files,
        outputs = [cpp_out],
        arguments = [rcc_args],
        env = {"QT_RCC_SOURCE_DATE_OVERRIDE": "1"},
        mnemonic = "QtRccShaders",
        progress_message = "Embedding compiled shaders for %s" % ctx.label.name,
    )

    return [
        DefaultInfo(files = depset([cpp_out])),
        OutputGroupInfo(qsb_files = depset(qsb_files)),
    ]

_qt_qsb_rule = rule(
    implementation = _qt_qsb_gen_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True, mandatory = True),
        "hdrs": attr.label_list(allow_files = True, default = []),
        "prefix": attr.string(mandatory = True),
        "strip_prefix": attr.string(default = ""),
        "outputs": attr.string_list(default = []),
        "defines": attr.string_list(default = []),
        "glsl": attr.string(default = "100es,120,150"),
        "hlsl": attr.string(default = "50"),
        "msl": attr.string(default = "12"),
        "batchable": attr.bool(default = False),
        "optimized": attr.bool(default = False),
        "silent": attr.bool(default = True),
        "pertargetcompile": attr.bool(default = False),
        "multiview": attr.bool(default = False),
        "zorder_loc": attr.int(default = -1),
        "view_count": attr.int(default = 0),
        "qrc_name": attr.string(default = ""),
        "qsb_tool": attr.label(
            mandatory = True,
            executable = True,
            cfg = "exec",
        ),
        "rcc_tool": attr.label(
            mandatory = True,
            executable = True,
            cfg = "exec",
        ),
    },
)

def qt_qsb(qsb_tool = None, rcc_tool = None, **kwargs):
    """Compiles GLSL shaders to .qsb (and optional .mv2qsb) via qsb and embeds them via rcc.

    Args:
      qsb_tool: Label of the qsb executable.
      rcc_tool: Label of the rcc executable.
      **kwargs: Additional arguments forwarded to _qt_qsb_rule.
    """
    if qsb_tool == None:
        qsb_tool = native.package_relative_label("@qtshadertools//:qsb")
    if rcc_tool == None:
        rcc_tool = native.package_relative_label("@qtbase//:rcc")
    _qt_qsb_rule(qsb_tool = qsb_tool, rcc_tool = rcc_tool, **kwargs)

def _qt_qml_cachegen_impl(ctx):
    qmlcachegen = ctx.executable.qmlcachegen_tool
    rcc = ctx.executable.rcc_tool
    uri_path = ctx.attr.uri.replace(".", "/")
    prefix = "/qt-project.org/imports/" + uri_path
    strip_prefix = ctx.attr.strip_prefix
    if strip_prefix and not strip_prefix.endswith("/"):
        strip_prefix = strip_prefix + "/"

    qmldir_file = ctx.actions.declare_file(ctx.label.name + "_qmldir/" + uri_path + "/qmldir")
    ctx.actions.write(qmldir_file, ctx.attr.qmldir_content)

    cpp_outs = []
    resource_paths = []
    rel_paths = []

    for src in ctx.files.qml_files:
        rel = _repo_rel_path(src)
        if strip_prefix and rel.startswith(strip_prefix):
            rel = rel[len(strip_prefix):]
        rel_paths.append(rel)
        res_path = prefix + "/" + rel
        resource_paths.append(res_path)

        safe_name = (
            rel.replace("/", "_")
                .replace(".qml", "_qml")
                .replace(".js", "_js")
                .replace(".mjs", "_mjs")
                .replace("+", "_")
        )
        out_cpp = ctx.actions.declare_file(
            ctx.label.name + "_qmlcache/" + ctx.attr.target_name + "_" + safe_name + ".cpp",
        )

        args = ctx.actions.args()
        args.add("--bare")
        args.add("--resource-path", res_path)
        args.add("-i", qmldir_file.path)
        args.add("-o", out_cpp.path)
        args.add(src.path)

        ctx.actions.run(
            executable = qmlcachegen,
            inputs = [src, qmldir_file] + ctx.files.qmltypes,
            outputs = [out_cpp],
            arguments = [args],
            mnemonic = "QtQmlCacheGen",
            progress_message = "Compiling QML %s" % src.short_path,
        )
        cpp_outs.append(out_cpp)

    # Generate loader C++ file
    rsp_file = ctx.actions.declare_file(ctx.label.name + "_loader.rsp")
    ctx.actions.write(rsp_file, "\n".join(resource_paths) + "\n")
    loader_cpp = ctx.actions.declare_file(
        ctx.label.name + "_qmlcache/" + ctx.attr.target_name + "_qmlcache_loader.cpp",
    )
    loader_args = ctx.actions.args()
    loader_args.add("--resource-name", "qmlcache_" + ctx.attr.target_name)
    loader_args.add("-o", loader_cpp.path)
    loader_args.add("@" + rsp_file.path)
    ctx.actions.run(
        executable = qmlcachegen,
        inputs = [rsp_file],
        outputs = [loader_cpp],
        arguments = [loader_args],
        mnemonic = "QtQmlCacheLoader",
        progress_message = "Generating QML cache loader for %s" % ctx.attr.target_name,
    )
    cpp_outs.append(loader_cpp)

    # Embed raw .qml files via rcc
    qrc_out = ctx.actions.declare_file(ctx.label.name + "_raw_qml.qrc")
    out_dir_parts = [p for p in qrc_out.dirname.split("/") if p]
    up_prefix = "../" * len(out_dir_parts)
    lines = [
        "<RCC>",
        '    <qresource prefix="{prefix}">'.format(prefix = prefix),
    ]
    for src, rel in zip(ctx.files.qml_files, rel_paths):
        lines.append('        <file alias="{alias}">{path}</file>'.format(
            alias = rel,
            path = up_prefix + src.path,
        ))
    lines.extend([
        "    </qresource>",
        "</RCC>",
        "",
    ])
    ctx.actions.write(qrc_out, "\n".join(lines))

    raw_qrc_cpp = ctx.actions.declare_file("qrc_" + ctx.attr.target_name + "_raw_qml_0.cpp")
    rcc_args = ctx.actions.args()
    rcc_args.add("--name", ctx.attr.target_name + "_raw_qml_0")
    rcc_args.add("--output", raw_qrc_cpp.path)
    rcc_args.add(qrc_out.path)
    ctx.actions.run(
        executable = rcc,
        inputs = [qrc_out] + ctx.files.qml_files,
        outputs = [raw_qrc_cpp],
        arguments = [rcc_args],
        env = {"QT_RCC_SOURCE_DATE_OVERRIDE": "1"},
        mnemonic = "QtRccRawQml",
        progress_message = "Embedding raw QML files for %s" % ctx.attr.target_name,
    )
    cpp_outs.append(raw_qrc_cpp)

    return [DefaultInfo(files = depset(cpp_outs))]

_qt_qml_cachegen_rule = rule(
    implementation = _qt_qml_cachegen_impl,
    attrs = {
        "target_name": attr.string(mandatory = True),
        "uri": attr.string(mandatory = True),
        "strip_prefix": attr.string(default = ""),
        "qml_files": attr.label_list(allow_files = True, mandatory = True),
        "qmldir_content": attr.string(mandatory = True),
        "qmltypes": attr.label_list(allow_files = True, default = []),
        "qmlcachegen_tool": attr.label(
            mandatory = True,
            executable = True,
            cfg = "exec",
        ),
        "rcc_tool": attr.label(
            mandatory = True,
            executable = True,
            cfg = "exec",
        ),
    },
)

def qt_qml_cachegen(qmlcachegen_tool = None, rcc_tool = None, **kwargs):
    """Compiles QML/JS files via qmlcachegen and embeds raw QML files via rcc.

    Args:
      qmlcachegen_tool: Label of the qmlcachegen executable.
      rcc_tool: Label of the rcc executable.
      **kwargs: Additional arguments forwarded to _qt_qml_cachegen_rule.
    """
    if qmlcachegen_tool == None:
        qmlcachegen_tool = native.package_relative_label("@qtdeclarative//:qmlcachegen")
    if rcc_tool == None:
        rcc_tool = native.package_relative_label("@qtbase//:rcc")
    _qt_qml_cachegen_rule(qmlcachegen_tool = qmlcachegen_tool, rcc_tool = rcc_tool, **kwargs)

def _qt_dbus_interface_impl(ctx):
    tool = ctx.executable.qdbusxml2cpp_tool
    option = "-a" if ctx.attr.adaptor else "-p"
    suffix = "adaptor" if ctx.attr.adaptor else "interface"
    outs = []

    for src in ctx.files.srcs:
        stem = src.basename[:-4] if src.basename.endswith(".xml") else src.basename
        if "." in stem:
            stem = stem.rsplit(".", 1)[1]
        base = stem.lower() + "_" + suffix
        out_h = ctx.actions.declare_file(ctx.label.name + "_dbus/" + base + ".h")
        out_cpp = ctx.actions.declare_file(ctx.label.name + "_dbus/" + base + ".cpp")
        out_dir = out_h.dirname

        flags_str = " ".join(['"{}"'.format(f) for f in ctx.attr.flags])
        cmd = """set -e
TOOL=$(realpath "{tool}")
SRC=$(realpath "{src}")
cd "{out_dir}"
"$TOOL" {flags} "{option}" "{base_h}:{base_cpp}" "$SRC"
""".format(
            tool = tool.path,
            src = src.path,
            out_dir = out_dir,
            flags = flags_str,
            option = option,
            base_h = base + ".h",
            base_cpp = base + ".cpp",
        )
        ctx.actions.run_shell(
            tools = [tool],
            inputs = [src],
            outputs = [out_h, out_cpp],
            command = cmd,
            mnemonic = "QtDbusXml2Cpp",
            progress_message = "Running qdbusxml2cpp on %s" % src.short_path,
        )
        outs.extend([out_h, out_cpp])

    inc_dir = outs[0].dirname if outs else "."
    return [
        DefaultInfo(files = depset(outs)),
        CcInfo(
            compilation_context = cc_common.create_compilation_context(
                headers = depset([f for f in outs if f.path.endswith(".h")]),
                includes = depset([inc_dir]),
            ),
        ),
        OutputGroupInfo(
            headers = depset([f for f in outs if f.path.endswith(".h")]),
            sources = depset([f for f in outs if f.path.endswith(".cpp")]),
        ),
    ]

_qt_dbus_interface_rule = rule(
    implementation = _qt_dbus_interface_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = [".xml"], mandatory = True),
        "flags": attr.string_list(default = []),
        "adaptor": attr.bool(default = False),
        "qdbusxml2cpp_tool": attr.label(
            mandatory = True,
            executable = True,
            cfg = "exec",
        ),
    },
    provides = [CcInfo],
)

def qt_dbus_interface(qdbusxml2cpp_tool = None, **kwargs):
    """Generates D-Bus interface or adaptor C++ headers and sources via qdbusxml2cpp.

    Args:
      qdbusxml2cpp_tool: Label of the qdbusxml2cpp executable.
      **kwargs: Additional arguments forwarded to _qt_dbus_interface_rule.
    """
    if qdbusxml2cpp_tool == None:
        qdbusxml2cpp_tool = native.package_relative_label("@qtbase//:qdbusxml2cpp")
    _qt_dbus_interface_rule(qdbusxml2cpp_tool = qdbusxml2cpp_tool, **kwargs)

def _qt_rep_impl(ctx):
    repc = ctx.executable.repc_tool
    mode = ctx.attr.mode
    outs = []
    for src in ctx.files.srcs:
        stem = src.basename[:-4] if src.basename.endswith(".rep") else src.basename
        out_h = ctx.actions.declare_file(ctx.label.name + "_rep/rep_" + stem + "_" + mode + ".h")
        args = ctx.actions.args()
        args.add("-o", mode)
        for flag in ctx.attr.flags:
            args.add(flag)
        args.add(src.path)
        args.add(out_h.path)
        ctx.actions.run(
            executable = repc,
            arguments = [args],
            inputs = [src],
            outputs = [out_h],
            mnemonic = "QtRepc",
            progress_message = "Running repc (%s) on %s" % (mode, src.short_path),
        )
        outs.append(out_h)

    inc_dir = outs[0].dirname if outs else "."
    return [
        DefaultInfo(files = depset(outs)),
        CcInfo(
            compilation_context = cc_common.create_compilation_context(
                headers = depset(outs),
                includes = depset([inc_dir]),
            ),
        ),
    ]

_qt_rep_rule = rule(
    implementation = _qt_rep_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = [".rep"], mandatory = True),
        "mode": attr.string(default = "replica", values = ["replica", "source", "merged"]),
        "flags": attr.string_list(default = []),
        "repc_tool": attr.label(
            mandatory = True,
            executable = True,
            cfg = "exec",
        ),
    },
    provides = [CcInfo],
)

def qt_rep(repc_tool = None, **kwargs):
    """Generates Qt Remote Objects header files from .rep definitions via repc.

    Args:
      repc_tool: Label of the repc executable.
      **kwargs: Additional arguments forwarded to _qt_rep_rule.
    """
    if repc_tool == None:
        repc_tool = native.package_relative_label("@qtremoteobjects//:repc")
    _qt_rep_rule(repc_tool = repc_tool, **kwargs)

def _qt_scxml_impl(ctx):
    qscxmlc = ctx.executable.qscxmlc_tool
    outs = []
    for src in ctx.files.srcs:
        stem = src.basename[:-6] if src.basename.endswith(".scxml") else src.basename
        out_h = ctx.actions.declare_file(ctx.label.name + "_scxml/" + stem + ".h")
        out_cpp = ctx.actions.declare_file(ctx.label.name + "_scxml/" + stem + ".cpp")
        out_base = out_h.path[:-2]
        args = ctx.actions.args()
        if ctx.attr.namespace:
            args.add("--namespace", ctx.attr.namespace)
        for flag in ctx.attr.flags:
            args.add(flag)
        args.add("--output", out_base)
        args.add(src.path)
        ctx.actions.run(
            executable = qscxmlc,
            arguments = [args],
            inputs = [src],
            outputs = [out_h, out_cpp],
            mnemonic = "QtScxmlc",
            progress_message = "Running qscxmlc on %s" % src.short_path,
        )
        outs.extend([out_h, out_cpp])

    inc_dir = outs[0].dirname if outs else "."
    return [
        DefaultInfo(files = depset(outs)),
        CcInfo(
            compilation_context = cc_common.create_compilation_context(
                headers = depset([f for f in outs if f.path.endswith(".h")]),
                includes = depset([inc_dir]),
            ),
        ),
        OutputGroupInfo(
            headers = depset([f for f in outs if f.path.endswith(".h")]),
            sources = depset([f for f in outs if f.path.endswith(".cpp")]),
        ),
    ]

_qt_scxml_rule = rule(
    implementation = _qt_scxml_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = [".scxml"], mandatory = True),
        "namespace": attr.string(default = ""),
        "flags": attr.string_list(default = []),
        "qscxmlc_tool": attr.label(
            mandatory = True,
            executable = True,
            cfg = "exec",
        ),
    },
    provides = [CcInfo],
)

def qt_scxml(qscxmlc_tool = None, **kwargs):
    """Compiles SCXML statechart (.scxml) files to C++ header and source via qscxmlc.

    Args:
      qscxmlc_tool: Label of the qscxmlc executable.
      **kwargs: Additional arguments forwarded to _qt_scxml_rule.
    """
    if qscxmlc_tool == None:
        qscxmlc_tool = native.package_relative_label("@qtscxml//:qscxmlc")
    _qt_scxml_rule(qscxmlc_tool = qscxmlc_tool, **kwargs)

def _qt_translation_impl(ctx):
    lrelease = ctx.executable.lrelease_tool
    outs = []
    for src in ctx.files.srcs:
        stem = src.basename[:-3] if src.basename.endswith(".ts") else src.basename
        out_qm = ctx.actions.declare_file(ctx.label.name + "_qm/" + stem + ".qm")
        args = ctx.actions.args()
        args.add("-silent")
        args.add(src.path)
        args.add("-qm", out_qm.path)
        ctx.actions.run(
            executable = lrelease,
            arguments = [args],
            inputs = [src],
            outputs = [out_qm],
            mnemonic = "QtLrelease",
            progress_message = "Running lrelease on %s" % src.short_path,
        )
        outs.append(out_qm)
    return [DefaultInfo(files = depset(outs))]

_qt_translation_rule = rule(
    implementation = _qt_translation_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = [".ts"], mandatory = True),
        "lrelease_tool": attr.label(
            mandatory = True,
            executable = True,
            cfg = "exec",
        ),
    },
)

def qt_translation(lrelease_tool = None, srcs = None, ts_files = None, **kwargs):
    """Compiles Qt translation source (.ts) files into binary (.qm) catalogs via lrelease.

    Args:
      lrelease_tool: Label of the lrelease executable.
      srcs: List of .ts files.
      ts_files: Alias for srcs.
      **kwargs: Additional arguments forwarded to _qt_translation_rule.
    """
    if lrelease_tool == None:
        lrelease_tool = native.package_relative_label("@qttools//:lrelease")
    _qt_translation_rule(
        lrelease_tool = lrelease_tool,
        srcs = srcs if srcs != None else ts_files,
        **kwargs
    )

def _qt_cc_library_impl(ctx):
    cc_toolchain = find_cc_toolchain(ctx)
    cc_helper.report_invalid_options(cc_toolchain, ctx.fragments.cpp)

    has_objc = False
    for f in ctx.files.srcs:
        if f.extension in ("m", "mm"):
            has_objc = True
            break

    features = ctx.features
    disabled_features = list(ctx.disabled_features)
    if has_objc and feature_names.MODULE_MAPS not in disabled_features:
        disabled_features.append(feature_names.MODULE_MAPS)

    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        language = "objc" if has_objc else "c++",
        requested_features = features,
        unsupported_features = disabled_features,
    )

    precompiled_files = cc_helper.build_precompiled_files(ctx = ctx)
    interface_deps = ctx.attr.deps + cc_helper.get_cc_runtimes(ctx, True)
    runtimes_copts = cc_helper.get_cc_runtimes_copts(ctx)
    compilation_contexts = cc_helper.get_compilation_contexts_from_deps(interface_deps)
    implementation_compilation_contexts = cc_helper.get_compilation_contexts_from_deps(ctx.attr.implementation_deps)

    additional_make_variable_substitutions = cc_helper.get_toolchain_global_make_variables(cc_toolchain, feature_configuration)
    additional_make_variable_substitutions.update(cc_helper.get_cc_flags_make_variable(ctx, feature_configuration, cc_toolchain))
    disallowed_copts_infos = getattr(cc_toolchain, "disallowed_copts_infos", [])

    is_windows_enabled = cc_common.is_enabled(
        feature_configuration = feature_configuration,
        feature_name = feature_names.TARGETS_WINDOWS,
    )
    win_visibility_flags = ["-fvisibility=default", "-fno-visibility-inlines-hidden"] if is_windows_enabled else []

    (compilation_context, srcs_compilation_outputs) = cc_common.compile(
        actions = ctx.actions,
        name = ctx.label.name,
        cc_toolchain = cc_toolchain,
        feature_configuration = feature_configuration,
        user_compile_flags = runtimes_copts + cc_helper.get_copts(ctx, feature_configuration, additional_make_variable_substitutions, attr = "copts", requested_features = features, disallowed_copts_infos = disallowed_copts_infos) + win_visibility_flags,
        conly_flags = cc_helper.get_copts(ctx, feature_configuration, additional_make_variable_substitutions, attr = "conlyopts", requested_features = features, disallowed_copts_infos = disallowed_copts_infos),
        cxx_flags = cc_helper.get_copts(ctx, feature_configuration, additional_make_variable_substitutions, attr = "cxxopts", requested_features = features, disallowed_copts_infos = disallowed_copts_infos),
        defines = cc_helper.defines(ctx, additional_make_variable_substitutions),
        local_defines = cc_helper.local_defines(ctx, additional_make_variable_substitutions) + cc_helper.get_local_defines_for_runfiles_lookup(ctx, ctx.attr.deps + ctx.attr.implementation_deps),
        includes = cc_helper.include_dirs(ctx, additional_make_variable_substitutions),
        local_includes = cc_helper.include_dirs(ctx, additional_make_variable_substitutions, attr = "local_includes"),
        srcs = [f for f, _ in cc_helper.get_srcs(ctx)],
        private_hdrs = [f for f, _ in cc_helper.get_private_hdrs(ctx)],
        public_hdrs = [f for f, _ in cc_helper.get_public_hdrs(ctx)],
        compilation_contexts = compilation_contexts + implementation_compilation_contexts,
        textual_hdrs = ctx.files.textual_hdrs,
        include_prefix = ctx.attr.include_prefix,
        strip_include_prefix = ctx.attr.strip_include_prefix,
        additional_inputs = ctx.files.additional_compiler_inputs,
        language = "objc" if has_objc else None,
    )

    precompiled_objects = cc_common.create_compilation_outputs(
        objects = depset(precompiled_files[0]),
        pic_objects = depset(precompiled_files[1]),
    )
    compilation_outputs = cc_common.merge_compilation_outputs(
        compilation_outputs = [precompiled_objects, srcs_compilation_outputs],
    )

    supports_dynamic_linker = cc_common.is_enabled(
        feature_configuration = feature_configuration,
        feature_name = feature_names.SUPPORTS_DYNAMIC_LINKER,
    )
    is_windows_enabled = cc_common.is_enabled(
        feature_configuration = feature_configuration,
        feature_name = feature_names.TARGETS_WINDOWS,
    )
    create_dynamic_library = (
        not ctx.attr.linkstatic and
        supports_dynamic_linker and
        not cc_helper.is_compilation_outputs_empty(compilation_outputs)
    )

    output_group_builder = {}
    has_compilation_outputs = not cc_helper.is_compilation_outputs_empty(compilation_outputs)
    linking_context = CcInfo().linking_context
    empty_archive_linking_context = CcInfo().linking_context

    linking_contexts = cc_helper.get_linking_contexts_from_deps(ctx.attr.deps)
    linking_contexts.extend(
        cc_helper.get_linking_contexts_from_deps(
            ctx.attr.implementation_deps + cc_helper.get_cc_runtimes(ctx, True),
        ),
    )

    if has_compilation_outputs:
        dll_name_suffix = ""
        additional_inputs = list(ctx.files.additional_linker_inputs)
        link_variables = {}
        if is_windows_enabled:
            dll_name_suffix = cc_helper.dll_hash_suffix(ctx, feature_configuration, ctx.fragments.cpp)
            generated_def_file = cc_helper.generate_def_file(
                ctx,
                ctx.file._def_parser,
                compilation_outputs.objects,
                ctx.label.name + dll_name_suffix,
                cc_toolchain,
                feature_configuration,
            )
            if generated_def_file != None:
                output_group_builder["def_file"] = depset([generated_def_file])
            win_def_file = cc_helper.get_windows_def_file_for_linking(ctx, ctx.file.win_def_file, generated_def_file, feature_configuration)
            link_variables["def_file_path"] = win_def_file.path
            additional_inputs.append(win_def_file)

        (linking_context, linking_outputs) = cc_common.create_linking_context_from_compilation_outputs(
            actions = ctx.actions,
            name = ctx.label.name,
            compilation_outputs = compilation_outputs,
            cc_toolchain = cc_toolchain,
            feature_configuration = feature_configuration,
            additional_inputs = additional_inputs,
            linking_contexts = linking_contexts,
            user_link_flags = cc_helper.linkopts(ctx, additional_make_variable_substitutions, cc_toolchain),
            alwayslink = ctx.attr.alwayslink,
            disallow_dynamic_library = not create_dynamic_library,
            variables_extension = link_variables,
        )
    else:
        linking_outputs = struct(library_to_link = None)

    contexts_to_merge = [empty_archive_linking_context]
    if has_compilation_outputs:
        contexts_to_merge.append(linking_context)
    else:
        user_link_flags = cc_helper.linkopts(ctx, additional_make_variable_substitutions, cc_toolchain)
        linker_input = cc_common.create_linker_input(
            owner = ctx.label,
            user_link_flags = user_link_flags,
            additional_inputs = depset(ctx.files.additional_linker_inputs),
        )
        contexts_to_merge.append(cc_common.create_linking_context(linker_inputs = depset([linker_input])))
        contexts_to_merge.extend(linking_contexts)

    linking_context = cc_common.merge_linking_contexts(linking_contexts = contexts_to_merge)
    libraries_to_link = [linking_outputs.library_to_link] if linking_outputs.library_to_link != None else []
    linking_context_for_runfiles = cc_helper.build_linking_context_from_libraries(ctx, libraries_to_link)
    cc_native_library_info = cc_helper.collect_native_cc_libraries(
        deps = ctx.attr.deps,
        libraries = libraries_to_link,
    )

    files_builder = []
    if linking_outputs.library_to_link != None:
        artifacts_to_build = linking_outputs.library_to_link
        if artifacts_to_build.static_library != None:
            files_builder.append(artifacts_to_build.static_library)
        if artifacts_to_build.pic_static_library != None:
            files_builder.append(artifacts_to_build.pic_static_library)
        if not is_windows_enabled:
            if artifacts_to_build.resolved_symlink_dynamic_library != None:
                files_builder.append(artifacts_to_build.resolved_symlink_dynamic_library)
            elif artifacts_to_build.dynamic_library != None:
                files_builder.append(artifacts_to_build.dynamic_library)
            if artifacts_to_build.resolved_symlink_interface_library != None:
                files_builder.append(artifacts_to_build.resolved_symlink_interface_library)
            elif artifacts_to_build.interface_library != None:
                files_builder.append(artifacts_to_build.interface_library)

    runfiles_list = []
    for data_dep in ctx.attr.data:
        if data_dep[DefaultInfo].data_runfiles.files:
            runfiles_list.append(data_dep[DefaultInfo].data_runfiles)
        else:
            runfiles_list.append(ctx.runfiles(transitive_files = data_dep[DefaultInfo].files))
            runfiles_list.append(data_dep[DefaultInfo].default_runfiles)
    for src in ctx.attr.srcs:
        runfiles_list.append(src[DefaultInfo].default_runfiles)
    for dep in ctx.attr.deps:
        runfiles_list.append(dep[DefaultInfo].default_runfiles)
    for dep in ctx.attr.implementation_deps:
        runfiles_list.append(dep[DefaultInfo].default_runfiles)
    runfiles = ctx.runfiles().merge_all(runfiles_list)
    default_runfiles = runfiles.merge(ctx.runfiles(files = cc_helper.get_dynamic_libraries_for_runtime(linking_context_for_runfiles, True)))
    data_runfiles = runfiles.merge(ctx.runfiles(files = cc_helper.get_dynamic_libraries_for_runtime(linking_context_for_runfiles, False)))

    current_output_groups = cc_helper.build_output_groups_for_emitting_compile_providers(
        compilation_outputs,
        compilation_context,
        ctx.fragments.cpp,
        cc_toolchain,
        feature_configuration,
        ctx,
        generate_hidden_top_level_group = True,
    )
    cc_info = CcInfo(
        compilation_context = compilation_context,
        linking_context = linking_context,
        cc_native_library_info = cc_native_library_info,
    )
    merged_output_groups = cc_helper.merge_output_groups([current_output_groups, output_group_builder])
    return [
        DefaultInfo(
            files = depset(files_builder),
            default_runfiles = default_runfiles,
            data_runfiles = data_runfiles,
        ),
        cc_info,
        OutputGroupInfo(**merged_output_groups),
    ]

qt_cc_library = rule(
    implementation = _qt_cc_library_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True, flags = ["DIRECT_COMPILE_TIME_INPUT"]),
        "hdrs": attr.label_list(allow_files = True, flags = ["ORDER_INDEPENDENT", "DIRECT_COMPILE_TIME_INPUT"]),
        "textual_hdrs": attr.label_list(allow_files = True, flags = ["ORDER_INDEPENDENT", "DIRECT_COMPILE_TIME_INPUT"]),
        "includes": attr.string_list(),
        "local_includes": attr.string_list(),
        "include_prefix": attr.string(),
        "strip_include_prefix": attr.string(),
        "copts": attr.string_list(),
        "cxxopts": attr.string_list(),
        "conlyopts": attr.string_list(),
        "defines": attr.string_list(),
        "local_defines": attr.string_list(),
        "deps": attr.label_list(providers = [CcInfo], flags = ["SKIP_ANALYSIS_TIME_FILETYPE_CHECK"]),
        "implementation_deps": attr.label_list(providers = [CcInfo], allow_files = False),
        "data": attr.label_list(allow_files = True, flags = ["SKIP_CONSTRAINTS_OVERRIDE"]),
        "linkopts": attr.string_list(),
        "linkstatic": attr.bool(default = False),
        "alwayslink": attr.bool(default = False),
        "win_def_file": attr.label(allow_single_file = [".def"]),
        "additional_compiler_inputs": attr.label_list(allow_files = True, flags = ["ORDER_INDEPENDENT", "DIRECT_COMPILE_TIME_INPUT"]),
        "additional_linker_inputs": attr.label_list(allow_files = True, flags = ["ORDER_INDEPENDENT"]),
        "_stl": cc_semantics.get_stl(),
        "_def_parser": cc_semantics.get_def_parser(),
    },
    toolchains = use_cc_toolchain() + cc_semantics.get_runtimes_toolchain(),
    fragments = ["cpp", "objc"] + cc_semantics.additional_fragments(),
    provides = [CcInfo],
)
