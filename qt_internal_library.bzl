"""Internal rules for building Qt modules (cc_library + cc_shared_library) and plugins."""

load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_cc//cc:cc_shared_library.bzl", "cc_shared_library")
load(":qt_tools.bzl", "moc_gen", "moc_out_copts", "qt_cc_library", "qt_generate_qmldir_content", "qt_qml_cachegen", "qt_qml_type_registration", "qt_qmldir")

QT_PLATFORM_COPTS = select({
    Label("@platforms//os:windows"): [
        "-Wa,-mbig-obj",
        "-Wno-ignored-attributes",
        "-fvisibility=default",
        "-fno-visibility-inlines-hidden",
    ],
    "//conditions:default": [],
})

QT_PLATFORM_DEFINES = select({
    Label("@platforms//os:windows"): [
        "UNICODE",
        "_UNICODE",
        "WIN32",
        "_WIN64",
        "NOMINMAX",
        "_USE_MATH_DEFINES",
        "_WIN32_WINNT=0x0A00",
        "WINVER=0x0A00",
        "MINGW_HAS_SECURE_API=1",
        "QT_NO_VERSION_TAGGING",
    ],
    "//conditions:default": [],
})

QT_SHARED_PLATFORM_LINKOPTS = select({
    Label("@platforms//os:windows"): [
        "-Wl,--export-all-symbols",
        "-Wl,--exclude-symbols,__dynamic_cast",
    ],
    "//conditions:default": [],
})

def qt_internal_library(
        name,
        srcs = [],
        hdrs = [],
        textual_hdrs = [],
        moc_hdrs = [],
        moc_srcs = [],
        moc_opts = [],
        rcc_targets = [],
        qml_args = None,
        includes = [],
        copts = [],
        cxxopts = [],
        conlyopts = [],
        defines = [],
        local_defines = [],
        deps = [],
        dynamic_deps = [],
        linkopts = [],
        alwayslink = False,
        create_shared = True,
        exports_filter = [],
        moc_unity = False,
        applicable_licenses = None,
        target_compatible_with = None,
        testonly = None,
        visibility = None,
        tags = []):
    """Builds a Qt module cc_library and its corresponding LGPL cc_shared_library.

    Args:
      name: Library name; the shared variant is `<name>_shared`.
      srcs: C++ sources.
      hdrs: Public headers.
      textual_hdrs: Headers/sources that are only ever `#include`d.
      moc_hdrs: Headers with Q_OBJECT to run moc on (yields `moc_<stem>.cpp`).
      moc_srcs: Sources that `#include "<stem>.moc"`.
      moc_opts: Extra moc flags.
      rcc_targets: Generated `qrc_*.cpp` sources from `qt_rcc_internal`.
      qml_args: Optional dict configuring QML type registration and qmldir embedding.
      includes: Forwarded to `cc_library` and moc.
      copts: Forwarded to `cc_library`; `-D`/`-I` flags are also passed to moc.
      cxxopts: Forwarded to `cc_library`.
      conlyopts: Forwarded to `cc_library`.
      defines: Public defines (propagated; also passed to moc).
      local_defines: Private defines (also passed to moc).
      deps: Dependencies.
      dynamic_deps: `cc_shared_library` deps of the shared variant.
      linkopts: Forwarded to both targets.
      alwayslink: Forwarded to `cc_library`.
      create_shared: Whether to emit the `<name>_shared` cc_shared_library.
      exports_filter: Forwarded to `cc_shared_library` (libraries whose symbols
        this .so exports, e.g. statically bundled third-party libs).
      moc_unity: Compile all `moc_*.cpp` through one `mocs_compilation.cpp`
        (CMake AUTOMOC behaviour) so forward-declared types across headers
        resolve. Recommended for new modules.
      applicable_licenses: Optional license labels forwarded to `cc_library`.
      target_compatible_with: Optional platform compatibility constraints.
      testonly: Optional testonly flag forwarded to generated targets.
      visibility: Forwarded to both targets.
      tags: Forwarded to all generated targets.
    """
    common_kwargs = {}
    if target_compatible_with != None:
        common_kwargs["target_compatible_with"] = target_compatible_with
    if testonly != None:
        common_kwargs["testonly"] = testonly

    if not create_shared and type(local_defines) == type([]):
        static_lib_defines = []
        for d in local_defines:
            if type(d) == type("") and d.startswith("QT_BUILD_") and d.endswith("_LIB"):
                static_lib_defines.append("QT_STATIC_" + d[len("QT_BUILD_"):])
        if static_lib_defines:
            defines = defines + static_lib_defines

    extra_srcs = list(rcc_targets)
    extra_deps = []
    extra_copts = []
    if type(hdrs) == type([]):
        for h in hdrs:
            if type(h) == type("") and (h.endswith("_sync_headers") or h.endswith("_headers")):
                if type(deps) != type([]) or h not in deps:
                    extra_deps.append(h)

    if moc_hdrs or moc_srcs or qml_args != None:
        moc_hdr_target = name + "_moc_hdrs"
        foreign_types = list(qml_args.get("foreign_types", [])) if qml_args else []
        if qml_args != None and type(deps) == type([]):
            auto_ft_map = {
                "@qtbase//:core": "@qtbase//:core_moc_hdrs",
                ":core": ":core_moc_hdrs",
                "@qtbase//:gui": "@qtbase//:gui_moc_hdrs",
                ":gui": ":gui_moc_hdrs",
                "@qtbase//:network": "@qtbase//:network_moc_hdrs",
                ":network": ":network_moc_hdrs",
                "@qtdeclarative//:qml": "@qtdeclarative//:qml_moc_hdrs",
                ":qml": ":qml_moc_hdrs",
                "@qtdeclarative//:qmlmodels": "@qtdeclarative//:qmlmodels_moc_hdrs",
                ":qmlmodels": ":qmlmodels_moc_hdrs",
                "@qtdeclarative//:quick": "@qtdeclarative//:quick_moc_hdrs",
                ":quick": ":quick_moc_hdrs",
                "@qtdeclarative//:quickshapes": "@qtdeclarative//:quickshapes_moc_hdrs",
                ":quickshapes": ":quickshapes_moc_hdrs",
                "@qtdeclarative//:quicktemplates2": "@qtdeclarative//:quicktemplates2_moc_hdrs",
                ":quicktemplates2": ":quicktemplates2_moc_hdrs",
                "@qtdeclarative//:quickcontrols2": "@qtdeclarative//:quickcontrols2_moc_hdrs",
                ":quickcontrols2": ":quickcontrols2_moc_hdrs",
                "@qtdeclarative//:quickcontrols2impl": "@qtdeclarative//:quickcontrols2impl_moc_hdrs",
                ":quickcontrols2impl": ":quickcontrols2impl_moc_hdrs",
                "@qtdeclarative//:quickcontrols2basic": "@qtdeclarative//:quickcontrols2basic_moc_hdrs",
                ":quickcontrols2basic": ":quickcontrols2basic_moc_hdrs",
                "@qtdeclarative//:quickcontrols2basicstyleimpl": "@qtdeclarative//:quickcontrols2basicstyleimpl_moc_hdrs",
                ":quickcontrols2basicstyleimpl": ":quickcontrols2basicstyleimpl_moc_hdrs",
                "@qtdeclarative//:quickcontrols2fusionstyleimpl": "@qtdeclarative//:quickcontrols2fusionstyleimpl_moc_hdrs",
                ":quickcontrols2fusionstyleimpl": ":quickcontrols2fusionstyleimpl_moc_hdrs",
                "@qtdeclarative//:quickcontrols2materialstyleimpl": "@qtdeclarative//:quickcontrols2materialstyleimpl_moc_hdrs",
                ":quickcontrols2materialstyleimpl": ":quickcontrols2materialstyleimpl_moc_hdrs",
                "@qtdeclarative//:quickcontrols2universalstyleimpl": "@qtdeclarative//:quickcontrols2universalstyleimpl_moc_hdrs",
                ":quickcontrols2universalstyleimpl": ":quickcontrols2universalstyleimpl_moc_hdrs",
                "@qtdeclarative//:quickcontrols2fluentwinui3styleimpl": "@qtdeclarative//:quickcontrols2fluentwinui3styleimpl_moc_hdrs",
                ":quickcontrols2fluentwinui3styleimpl": ":quickcontrols2fluentwinui3styleimpl_moc_hdrs",
                "@qtdeclarative//:quickdialogs2utils": "@qtdeclarative//:quickdialogs2utils_moc_hdrs",
                ":quickdialogs2utils": ":quickdialogs2utils_moc_hdrs",
                "@qtdeclarative//:quickdialogs2quickimpl": "@qtdeclarative//:quickdialogs2quickimpl_moc_hdrs",
                ":quickdialogs2quickimpl": ":quickdialogs2quickimpl_moc_hdrs",
                "@qtdeclarative//:labsfoldermodel": "@qtdeclarative//:labsfoldermodel_moc_hdrs",
                ":labsfoldermodel": ":labsfoldermodel_moc_hdrs",
                "@qtquick3d//:quick3d": "@qtquick3d//:quick3d_moc_hdrs",
                ":quick3d": ":quick3d_moc_hdrs",
                "@qtquick3d//:quick3druntimerender": "@qtquick3d//:quick3druntimerender_moc_hdrs",
                ":quick3druntimerender": ":quick3druntimerender_moc_hdrs",
                "@qtpositioning//:positioning": "@qtpositioning//:positioning_moc_hdrs",
                ":positioning": ":positioning_moc_hdrs",
                "@qtpositioning//:positioningquick": "@qtpositioning//:positioningquick_moc_hdrs",
                ":positioningquick": ":positioningquick_moc_hdrs",
                ":virtualkeyboard": ":virtualkeyboard_moc_hdrs",
                ":virtualkeyboardsettings": ":virtualkeyboardsettings_moc_hdrs",
            }
            for d in deps:
                if type(d) == type("") and d in auto_ft_map:
                    ft_lbl = auto_ft_map[d]
                    if ft_lbl not in foreign_types:
                        foreign_types.append(ft_lbl)
        if type(deps) == type([]):
            moc_deps = list(deps) + extra_deps
            for ft in foreign_types:
                if ft not in moc_deps:
                    moc_deps.append(ft)
        else:
            moc_deps = deps + foreign_types
        moc_gen(
            name = moc_hdr_target,
            hdrs = moc_hdrs,
            srcs = moc_srcs,
            target_srcs = srcs,
            other_hdrs = hdrs + textual_hdrs,
            includes = includes,
            defines = defines + local_defines,
            copts = copts,
            moc_opts = moc_opts,
            deps = moc_deps,
            unity = moc_unity,
            visibility = visibility,
            tags = tags,
            **common_kwargs
        )

        # Expose the moc outputs to this library only (see moc_out_copts).
        moc_hdr_lib = name + "_moc_hdrs_lib"
        cc_library(
            name = moc_hdr_lib,
            textual_hdrs = [":" + moc_hdr_target],
            tags = tags,
            **common_kwargs
        )
        extra_deps.append(":" + moc_hdr_lib)
        extra_copts = moc_out_copts(moc_hdr_target)
        if moc_hdrs:
            if moc_unity:
                # Only compile mocs_compilation.cpp (which #includes the
                # individual moc_*.cpp files), mirroring CMake AUTOMOC.
                moc_compile_srcs = name + "_moc_compile_srcs"
                native.filegroup(
                    name = moc_compile_srcs,
                    srcs = [":" + moc_hdr_target],
                    output_group = "compile_srcs",
                    tags = tags,
                    **common_kwargs
                )
                extra_srcs.append(":" + moc_compile_srcs)
            else:
                extra_srcs.append(":" + moc_hdr_target)

        if qml_args != None:
            uri = qml_args.get("uri") or qml_args.get("import_name")
            qmldir_content = qml_args.get("qmldir_content") or qml_args.get("qmldir")
            if qmldir_content == None and not qml_args.get("no_qmldir", False):
                qmldir_content = qt_generate_qmldir_content(
                    uri = uri,
                    major_version = qml_args.get("major_version", "6"),
                    minor_version = qml_args.get("minor_version", "10"),
                    past_major_versions = qml_args.get("past_major_versions", []),
                    linktarget = qml_args.get("linktarget", None),
                    plugin_target = qml_args.get("plugin_target", None),
                    class_name = qml_args.get("class_name", qml_args.get("plugin_class_name", None)),
                    plugin_optional = qml_args.get("plugin_optional", True),
                    typeinfo = qml_args.get("typeinfo", "plugins.qmltypes"),
                    designer_supported = qml_args.get("designer_supported", False),
                    default_imports = qml_args.get("default_imports", []),
                    imports = qml_args.get("imports", qml_args.get("qml_imports", [])),
                    optional_imports = qml_args.get("optional_imports", []),
                    depends = qml_args.get("depends", qml_args.get("qml_depends", [])),
                    prefer = qml_args.get("prefer", None),
                    qml_files = qml_args.get("qmldir_qml_files", qml_args.get("qml_files", [])),
                    strip_prefix = qml_args.get("qml_strip_prefix", ""),
                    qml_singletons = qml_args.get("qml_singletons", []),
                    qml_internal_files = qml_args.get("qml_internal_files", []),
                    qml_source_versions = qml_args.get("qml_source_versions", {}),
                )

            # qmltyperegistrar emits `#if __has_include(<private/x_p.h>)` for
            # private headers when --private-includes is given; that only
            # resolves when a syncqt-staged `private/` dir is on the include
            # path. Without one, fall back to plain `<x_p.h>` includes so the
            # headers are found via this target's `includes`.
            has_staged_hdrs = False
            for lbl in list(deps if type(deps) == type([]) else []) + extra_deps:
                if type(lbl) == type("") and (lbl.endswith("_sync_headers") or lbl.endswith("_headers")):
                    has_staged_hdrs = True
            private_includes = qml_args.get("private_includes", has_staged_hdrs)

            typereg_target = name + "_qmltyperegistrations"
            qt_qml_type_registration(
                name = typereg_target,
                metatypes = ":" + moc_hdr_target,
                import_name = uri,
                major_version = qml_args.get("major_version", "6"),
                minor_version = qml_args.get("minor_version", "10"),
                past_major_versions = qml_args.get("past_major_versions", []),
                follow_foreign_versioning = qml_args.get("follow_foreign_versioning", True),
                private_includes = private_includes,
                foreign_types = foreign_types,
                generate_jsroot = qml_args.get("generate_jsroot", False),
                tags = tags,
                **common_kwargs
            )
            extra_srcs.append(":" + typereg_target)

            import_tree_srcs = [":" + typereg_target + "_qmltypes_group"]
            native.filegroup(
                name = typereg_target + "_qmltypes_group",
                srcs = [":" + typereg_target],
                output_group = "qmltypes",
                tags = tags,
                **common_kwargs
            )

            if qmldir_content != None:
                qmldir_rcc_target = name + "_qmldir_rcc"
                qt_qmldir(
                    name = qmldir_rcc_target,
                    uri = uri,
                    content = qmldir_content,
                    tags = tags,
                    **common_kwargs
                )
                extra_srcs_qmldir_lib = name + "_qmldir_rcc_lib"
                cc_library(
                    name = extra_srcs_qmldir_lib,
                    srcs = [":" + qmldir_rcc_target],
                    copts = ["-fvisibility=default"],
                    alwayslink = True,
                    tags = tags,
                    **common_kwargs
                )
                extra_deps.append(":" + extra_srcs_qmldir_lib)
                import_tree_srcs.append(":" + qmldir_rcc_target + "_qmldir_file")

            native.filegroup(
                name = name + "_qml_import_tree",
                srcs = import_tree_srcs,
                visibility = visibility,
                tags = tags,
                **common_kwargs
            )

            if "qml_files" in qml_args and qml_args["qml_files"]:
                qmlcache_target = name + "_qmlcache"
                qt_qml_cachegen(
                    name = qmlcache_target,
                    target_name = qml_args.get("qmlcache_target_name", name),
                    uri = uri,
                    strip_prefix = qml_args.get("qml_strip_prefix", ""),
                    qml_files = qml_args["qml_files"],
                    qmldir_content = qmldir_content or "",
                    qmltypes = [":" + typereg_target + "_qmltypes_group"],
                    tags = tags,
                    **common_kwargs
                )
                extra_srcs.append(":" + qmlcache_target)

    cc_lib_kwargs = dict(common_kwargs)
    if applicable_licenses != None:
        cc_lib_kwargs["applicable_licenses"] = applicable_licenses
    qt_cc_library(
        name = name,
        srcs = srcs + extra_srcs,
        hdrs = hdrs,
        textual_hdrs = textual_hdrs,
        includes = ["."] + includes,
        copts = copts + extra_copts + QT_PLATFORM_COPTS,
        cxxopts = cxxopts,
        conlyopts = conlyopts,
        defines = defines,
        local_defines = local_defines + QT_PLATFORM_DEFINES,
        deps = deps + extra_deps + select({
            Label("@platforms//os:windows"): [Label("//:win_cxxabi_shim")],
            "//conditions:default": [],
        }),
        linkopts = linkopts,
        alwayslink = alwayslink or (qml_args != None),
        visibility = visibility,
        tags = tags,
        **cc_lib_kwargs
    )

    if create_shared:
        shared_dyn_deps = list(dynamic_deps) if type(dynamic_deps) == type([]) else dynamic_deps
        if type(shared_dyn_deps) == type([]):
            if (":quick_shared" in shared_dyn_deps or "@qtdeclarative//:quick_shared" in shared_dyn_deps or Label("@qtdeclarative//:quick_shared") in shared_dyn_deps) and "@qtbase//:opengl_shared" not in shared_dyn_deps and Label("@qtbase//:opengl_shared") not in shared_dyn_deps and ":opengl_shared" not in shared_dyn_deps:
                shared_dyn_deps.append(Label("@qtbase//:opengl_shared"))
            if "@qtbase//:dbus_shared" in shared_dyn_deps or Label("@qtbase//:dbus_shared") in shared_dyn_deps or "@qtbase//:gui_shared" in shared_dyn_deps or Label("@qtbase//:gui_shared") in shared_dyn_deps:
                shared_dyn_deps = [d for d in shared_dyn_deps if d != "@qtbase//:dbus_shared" and d != Label("@qtbase//:dbus_shared")] + select({
                    Label("@platforms//os:windows"): [],
                    "//conditions:default": [Label("@qtbase//:dbus_shared")],
                })
        shared_roots = [":" + name]
        if type(exports_filter) == type([]) and ("@glib//glib:glib" in exports_filter):
            shared_roots = shared_roots + select({
                Label("@platforms//os:linux"): ["@glib//glib:glib"],
                "//conditions:default": [],
            })
        version_script = Label("//:qt6_version_script")
        cc_shared_library(
            name = name + "_shared",
            shared_lib_name = select({
                Label("@platforms//os:windows"): "lib" + name + "_shared.dll",
                "//conditions:default": "",
            }),
            deps = shared_roots,
            dynamic_deps = shared_dyn_deps,
            exports_filter = exports_filter,
            additional_linker_inputs = select({
                Label("@platforms//os:linux"): [version_script],
                "//conditions:default": [],
            }),
            user_link_flags = linkopts + QT_SHARED_PLATFORM_LINKOPTS + select({
                # F-ABI-3 / F-ABI-4: upstream links Qt libraries with
                # -Bsymbolic-functions and tags every exported symbol Qt_6.
                Label("@platforms//os:linux"): [
                    "-Wl,-Bsymbolic-functions",
                    "-Wl,--version-script=$(execpath %s)" % str(version_script),
                ],
                "//conditions:default": [],
            }),
            visibility = visibility,
            tags = tags,
            **common_kwargs
        )

def qt_static_plugin(
        name,
        plugin_class_name,
        srcs = [],
        hdrs = [],
        textual_hdrs = [],
        moc_hdrs = [],
        moc_srcs = [],
        moc_opts = [],
        rcc_targets = [],
        includes = [],
        copts = [],
        cxxopts = [],
        conlyopts = [],
        defines = [],
        local_defines = [],
        deps = [],
        dynamic_deps = [],
        linkopts = [],
        moc_unity = False,
        applicable_licenses = None,
        target_compatible_with = None,
        testonly = None,
        visibility = None,
        tags = []):
    """Builds a Qt plugin as a statically linked Q_IMPORT_PLUGIN library.

    Args:
      name: Target name; the implementation library is `<name>_impl`.
      plugin_class_name: The Q_PLUGIN_METADATA class, passed to Q_IMPORT_PLUGIN.
      srcs: C++ sources.
      hdrs: Public headers.
      textual_hdrs: Headers/sources that are only ever `#include`d. Any
        `*.json` plugin metadata files that live next to `srcs`/`hdrs` are
        added automatically so moc can resolve `Q_PLUGIN_METADATA(FILE ...)`.
      moc_hdrs: Headers with Q_OBJECT to run moc on.
      moc_srcs: Sources that `#include "<stem>.moc"`.
      moc_opts: Extra moc flags.
      rcc_targets: Generated `qrc_*.cpp` sources.
      includes: Forwarded to `cc_library` and moc.
      copts: Forwarded to `cc_library` and moc.
      cxxopts: Forwarded to `cc_library`.
      conlyopts: Forwarded to `cc_library`.
      defines: Public defines.
      local_defines: Private defines; `QT_PLUGIN` and `QT_STATICPLUGIN` are added.
      deps: Dependencies.
      dynamic_deps: Currently unused (kept for API symmetry with qt_internal_library).
      linkopts: Forwarded to `cc_library`.
      moc_unity: See `qt_internal_library`.
      applicable_licenses: Optional license labels forwarded to `cc_library`.
      target_compatible_with: Optional platform compatibility constraints.
      testonly: Optional testonly flag forwarded to generated targets.
      visibility: Forwarded to generated targets.
      tags: Forwarded to generated targets.

    The implementation is compiled with QT_STATICPLUGIN so that moc emits the
    `qt_static_plugin_<Class>()` entry point used by Q_IMPORT_PLUGIN. Because that
    differs from the `qt_plugin_instance()` entry point of a runtime-loadable plugin,
    no `cc_shared_library` is produced here; loadable `.so` plugins (for
    QT_PLUGIN_PATH discovery) are a separate build of the same sources.
    """
    common_kwargs = {}
    if target_compatible_with != None:
        common_kwargs["target_compatible_with"] = target_compatible_with
    if testonly != None:
        common_kwargs["testonly"] = testonly

    json_globs = []
    seen_dirs = {}
    iter_files = []
    for seq in (srcs, hdrs, moc_hdrs):
        if type(seq) == type([]):
            iter_files.extend(seq)
    for f in iter_files:
        if type(f) != type("") or f.startswith(":") or f.startswith("@") or f.startswith("//"):
            continue
        d = f.rsplit("/", 1)[0] if "/" in f else ""
        if d not in seen_dirs:
            seen_dirs[d] = True
            json_globs.append((d + "/" if d else "") + "*.json")
    plugin_json = native.glob(json_globs, allow_empty = True) if json_globs else []
    existing_textual = textual_hdrs if type(textual_hdrs) == type([]) else []
    extra_textual = [j for j in plugin_json if j not in existing_textual]

    qt_internal_library(
        name = name + "_impl",
        srcs = srcs,
        hdrs = hdrs,
        textual_hdrs = textual_hdrs + extra_textual,
        moc_hdrs = moc_hdrs,
        moc_srcs = moc_srcs,
        moc_opts = moc_opts,
        rcc_targets = rcc_targets,
        includes = includes,
        copts = copts,
        cxxopts = cxxopts,
        conlyopts = conlyopts,
        defines = defines,
        local_defines = local_defines + ["QT_PLUGIN", "QT_STATICPLUGIN"],
        deps = deps,
        dynamic_deps = dynamic_deps,
        linkopts = linkopts,
        alwayslink = True,
        create_shared = False,
        moc_unity = moc_unity,
        applicable_licenses = applicable_licenses,
        target_compatible_with = target_compatible_with,
        testonly = testonly,
        visibility = visibility,
        tags = tags,
    )

    native.genrule(
        name = name + "_import_gen",
        outs = [name + "_import.cpp"],
        cmd = "printf '#include <QtCore/QtPlugin>\\nQ_IMPORT_PLUGIN(%s)\\n' > $@" % plugin_class_name,
        tags = tags,
        **common_kwargs
    )

    cc_lib_kwargs = dict(common_kwargs)
    if applicable_licenses != None:
        cc_lib_kwargs["applicable_licenses"] = applicable_licenses
    cc_library(
        name = name,
        srcs = [":" + name + "_import_gen"],
        hdrs = hdrs,
        local_defines = ["QT_STATICPLUGIN"],
        deps = [":" + name + "_impl"],
        alwayslink = True,
        visibility = visibility,
        tags = tags,
        **cc_lib_kwargs
    )
