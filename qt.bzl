"""Public Bazel rules for building Qt C++ libraries, binaries, tests, UI headers, and resources."""

load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_cc//cc:cc_shared_library.bzl", "cc_shared_library")
load("@rules_cc//cc:cc_test.bzl", "cc_test")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("@rules_cc//cc/common:cc_shared_library_hint_info.bzl", "CcSharedLibraryHintInfo")
load("@rules_cc//cc/common:cc_shared_library_info.bzl", "CcSharedLibraryInfo")
load(
    ":qt_internal_library.bzl",
    "QT_PLATFORM_COPTS",
    "QT_PLATFORM_DEFINES",
    "QtSharedLibraryInfo",
    _QT_SHARED_PLATFORM_LINKOPTS = "QT_SHARED_PLATFORM_LINKOPTS",
    _qt_internal_library = "qt_internal_library",
    _qt_static_plugin = "qt_static_plugin",
)
load(
    ":qt_tools.bzl",
    "moc_gen",
    "moc_out_copts",
    "qt_depends_header",
    "qt_generate_qmldir_content",
    "qt_qml_plugin_gen",
    "qt_rcc_internal",
    "qt_write_file",
    _qt_cc_library_rule = "qt_cc_library",
    _qt_dbus_interface = "qt_dbus_interface",
    _qt_export_header_rule = "qt_export_header",
    _qt_generate_qrc_rule = "qt_generate_qrc",
    _qt_lalr = "qt_lalr",
    _qt_qml_plugin_cpp = "qt_qml_plugin_cpp",
    _qt_qsb = "qt_qsb",
    _qt_rep = "qt_rep",
    _qt_scxml = "qt_scxml",
    _qt_sync_headers = "qt_sync_headers",
)

QT_VERSION = "6.10.2"

QT_SHARED_PLATFORM_LINKOPTS = _QT_SHARED_PLATFORM_LINKOPTS
qt_internal_library = _qt_internal_library
qt_static_plugin = _qt_static_plugin
qt_dbus_interface = _qt_dbus_interface
qt_lalr = _qt_lalr
qt_qml_plugin_cpp = _qt_qml_plugin_cpp
qt_qsb = _qt_qsb
qt_rep = _qt_rep
qt_scxml = _qt_scxml
qt_sync_headers = _qt_sync_headers

QtSharedLibraryAspectInfo = provider(
    doc = "Aggregated QtSharedLibraryInfo across transitive dependencies.",
    fields = {
        "dynamic_deps": "depset of dynamic_dep_entry structs in topological order.",
        "runfiles_files": "depset of runtime File artifacts.",
        "qt_lib_labels": "depset of Label of internal *_qt_lib targets.",
    },
)

def _qt_shared_library_aspect_impl(target, ctx):
    direct_dyn = []
    trans_dyn = []
    direct_rf = []
    trans_rf = []
    direct_qt_libs = []
    trans_qt_libs = []

    if QtSharedLibraryInfo in target:
        info = target[QtSharedLibraryInfo]
        trans_dyn.append(info.dynamic_deps)
        trans_rf.append(info.runfiles_files)
        trans_qt_libs.append(info.qt_lib_labels)

    for attr_name in ("deps", "lib", "implementation_deps"):
        val = getattr(ctx.rule.attr, attr_name, None)
        if not val:
            continue
        dep_list = val if type(val) == type([]) else [val]
        for dep in dep_list:
            if QtSharedLibraryAspectInfo in dep:
                ainfo = dep[QtSharedLibraryAspectInfo]
                trans_dyn.append(ainfo.dynamic_deps)
                trans_rf.append(ainfo.runfiles_files)
                trans_qt_libs.append(ainfo.qt_lib_labels)

    return [
        QtSharedLibraryAspectInfo(
            dynamic_deps = depset(direct = direct_dyn, transitive = trans_dyn, order = "topological"),
            runfiles_files = depset(direct = direct_rf, transitive = trans_rf),
            qt_lib_labels = depset(direct = direct_qt_libs, transitive = trans_qt_libs, order = "topological"),
        ),
    ]

_qt_shared_library_aspect = aspect(
    implementation = _qt_shared_library_aspect_impl,
    attr_aspects = ["deps", "lib", "implementation_deps"],
)

def _qt_dynamic_deps_collector_impl(ctx):
    dyn_depsets = []
    rf_depsets = []
    qt_lib_depsets = []
    runfiles = ctx.runfiles()

    for dep in ctx.attr.dynamic_deps:
        info = dep[CcSharedLibraryInfo]
        entry = struct(
            exports = info.exports,
            linker_input = info.linker_input,
            link_once_static_libs = info.link_once_static_libs,
        )
        dyn_depsets.append(depset(direct = [entry], transitive = [info.dynamic_deps], order = "topological"))
        if dep[DefaultInfo].default_runfiles != None:
            runfiles = runfiles.merge(dep[DefaultInfo].default_runfiles)
        if dep[DefaultInfo].data_runfiles != None:
            runfiles = runfiles.merge(dep[DefaultInfo].data_runfiles)

    for dep in ctx.attr.deps + ctx.attr.qt_deps:
        if QtSharedLibraryAspectInfo in dep:
            ainfo = dep[QtSharedLibraryAspectInfo]
            dyn_depsets.append(ainfo.dynamic_deps)
            rf_depsets.append(ainfo.runfiles_files)
            qt_lib_depsets.append(ainfo.qt_lib_labels)

    raw_dyn_entries = depset(transitive = dyn_depsets, order = "topological").to_list()
    seen_dyn_owners = {}
    deduped_dyn_entries = []
    transitive_exports = {}
    for entry in raw_dyn_entries:
        owner_key = str(entry.linker_input.owner)
        if owner_key in seen_dyn_owners:
            continue
        seen_dyn_owners[owner_key] = True
        deduped_dyn_entries.append(entry)
        for exp in entry.exports:
            transitive_exports[exp] = True

    linker_input_owners = {}
    for dep in ctx.attr.deps:
        if CcInfo in dep:
            for li in dep[CcInfo].linking_context.linker_inputs.to_list():
                linker_input_owners[str(li.owner)] = li.owner

    active_exports = []
    seen_active = {}
    for lbl in depset(transitive = qt_lib_depsets, order = "topological").to_list():
        s = str(lbl)
        if s in transitive_exports and s in linker_input_owners and s not in seen_active:
            seen_active[s] = True
            active_exports.append(lbl)

    runfiles = runfiles.merge(ctx.runfiles(transitive_files = depset(transitive = rf_depsets)))

    return [
        DefaultInfo(runfiles = runfiles),
        CcInfo(),
        CcSharedLibraryInfo(
            dynamic_deps = depset(direct = deduped_dyn_entries, order = "topological"),
            exports = [],
            link_once_static_libs = [],
            linker_input = cc_common.create_linker_input(owner = ctx.label),
        ),
        CcSharedLibraryHintInfo(
            owners = active_exports if active_exports else [ctx.label],
            attributes = [],
        ),
    ]

_qt_dynamic_deps_collector = rule(
    implementation = _qt_dynamic_deps_collector_impl,
    attrs = {
        "deps": attr.label_list(aspects = [_qt_shared_library_aspect]),
        "qt_deps": attr.label_list(aspects = [_qt_shared_library_aspect]),
        "dynamic_deps": attr.label_list(providers = [CcSharedLibraryInfo]),
    },
    provides = [CcInfo, CcSharedLibraryInfo, CcSharedLibraryHintInfo],
)

# Public, read-only mapping of @qtbase library targets to their cc_shared_library
# targets for consumers writing plain rules_cc targets. Transitive Qt shared
# libraries across all Qt modules are resolved automatically via QtSharedLibraryInfo
# and qt_shared_libs().
QT_SHARED_LIBS = {
    "@qtbase//:core": [Label("@qtbase//:core_shared")],
    "@qtbase//:concurrent": [Label("@qtbase//:concurrent_shared"), Label("@qtbase//:core_shared")],
    "@qtbase//:dbus": [Label("@qtbase//:dbus_shared"), Label("@qtbase//:core_shared")],
    "@qtbase//:gui": [Label("@qtbase//:gui_shared"), Label("@qtbase//:dbus_shared"), Label("@qtbase//:core_shared")],
    "@qtbase//:network": [Label("@qtbase//:network_shared"), Label("@qtbase//:core_shared")],
    "@qtbase//:opengl": [Label("@qtbase//:opengl_shared"), Label("@qtbase//:gui_shared"), Label("@qtbase//:dbus_shared"), Label("@qtbase//:core_shared")],
    "@qtbase//:openglwidgets": [Label("@qtbase//:openglwidgets_shared"), Label("@qtbase//:opengl_shared"), Label("@qtbase//:widgets_shared"), Label("@qtbase//:gui_shared"), Label("@qtbase//:dbus_shared"), Label("@qtbase//:core_shared")],
    "@qtbase//:printsupport": [Label("@qtbase//:printsupport_shared"), Label("@qtbase//:widgets_shared"), Label("@qtbase//:gui_shared"), Label("@qtbase//:dbus_shared"), Label("@qtbase//:core_shared")],
    "@qtbase//:sql": [Label("@qtbase//:sql_shared"), Label("@qtbase//:core_shared")],
    "@qtbase//:test": [Label("@qtbase//:test_shared"), Label("@qtbase//:core_shared")],
    "@qtbase//:widgets": [Label("@qtbase//:widgets_shared"), Label("@qtbase//:gui_shared"), Label("@qtbase//:dbus_shared"), Label("@qtbase//:core_shared")],
    "@qtbase//:xml": [Label("@qtbase//:xml_shared"), Label("@qtbase//:core_shared")],
}

def qt_shared_libs(deps):
    """Returns a dynamic_deps target list that resolves all Qt `cc_shared_library` dependencies of `deps`.

    Use this with plain `cc_binary`/`cc_test`/`cc_shared_library` targets:

        cc_binary(
            name = "app",
            deps = ["@qtbase//:widgets"],
            dynamic_deps = qt_shared_libs(["@qtbase//:widgets"]),
        )

    Args:
      deps: List of Qt library labels (strings or Labels).

    Returns:
      A list containing a collector target providing `CcSharedLibraryInfo` for `deps`.
    """
    helper_name = "_qt_shared_libs_%d" % (hash(repr(deps)) & 0x7fffffff)
    if not native.existing_rule(helper_name):
        _qt_dynamic_deps_collector(
            name = helper_name,
            deps = list(deps),
        )
    return [":" + helper_name]

def _dep_key(dep):
    if type(dep) == type(""):
        if dep.startswith("@") or dep.startswith(":"):
            return dep
    lbl = native.package_relative_label(dep)
    if lbl.repo_name:
        repo = lbl.repo_name[:-1] if lbl.repo_name.endswith("+") else lbl.repo_name
        pkg = ("/" + lbl.package) if lbl.package else ""
        return "@" + repo + "//" + pkg.lstrip("/") + ":" + lbl.name
    if not lbl.package:
        return ":" + lbl.name
    return "//" + lbl.package + ":" + lbl.name

def _has_dep(deps, target_str):
    for d in deps:
        if d == target_str or _dep_key(d) == target_str:
            return True
    return False

# Plugins implied by a Qt library dependency (F-INF-4). This mirrors upstream's
# per-module default plugin sets (`qt_import_plugins` / `QT_DEFAULT_PLUGINS`):
# a binary that depends on the library automatically links the backends it
# needs at runtime. Opt out per binary with `autolink_plugins = False`.
# Note: non-qtbase plugin labels are kept as strings so they are resolved in the
# caller's repository context (which already has a bazel_dep on that module).
_QT_IMPLIED_PLUGINS = {
    "@qtbase//:network": [Label("@qtbase//:tls_plugins")],
    "@qtbase//:sql": [Label("@qtbase//:sqldriver_plugins")],
    "@qtsvg//:svg": ["@qtsvg//:qsvg", "@qtsvg//:qsvgicon"],
    "@qtmultimedia//:multimedia": ["@qtmultimedia//:multimedia_plugins"],
    "@qtspeech//:tts": ["@qtspeech//:tts_plugins"],
    "@qtpositioning//:positioning": ["@qtpositioning//:position_plugins"],
    "@qtsensors//:sensors": ["@qtsensors//:sensors_plugins"],
    "@qtserialbus//:serialbus": ["@qtserialbus//:canbus_plugins"],
    "@qtlocation//:location": ["@qtlocation//:geoservices_plugins"],
    "@qtwebview//:webview": ["@qtwebview//:webview_plugins"],
}

def _add_implied_plugins(lib_deps):
    """Appends the plugins implied by `lib_deps` (see _QT_IMPLIED_PLUGINS) in place."""
    if type(lib_deps) != type([]):
        return lib_deps
    for dep in list(lib_deps):
        for p in _QT_IMPLIED_PLUGINS.get(_dep_key(dep), []):
            p_key = _dep_key(p)
            if not _has_dep(lib_deps, p_key):
                lib_deps.append(p)
    return lib_deps

_GUI_REPOS = {
    "@qt3d": True,
    "@qtcharts": True,
    "@qtdatavis3d": True,
    "@qtgraphs": True,
    "@qtimageformats": True,
    "@qtlocation": True,
    "@qtlottie": True,
    "@qtmultimedia": True,
    "@qtquick3dphysics": True,
    "@qtquicktimeline": True,
    "@qtshadertools": True,
    "@qtspeech": True,
    "@qtsvg": True,
    "@qttools": True,
    "@qtvirtualkeyboard": True,
    "@qtwayland": True,
    "@qtwebview": True,
}

_QTBASE_GUI_TARGETS = {
    "gui": True,
    "widgets": True,
    "printsupport": True,
    "opengl": True,
    "openglwidgets": True,
    "offscreen": True,
    "xcb": True,
    "qxcb_glx_integration": True,
    "qxcb_egl_integration": True,
    "cocoa": True,
    "windows": True,
    "qgif": True,
    "qico": True,
    "qjpeg": True,
    "imageformats": True,
    "qmacstyle": True,
    "qmodernwindowsstyle": True,
    "style_plugins": True,
    "composeplatforminputcontextplugin": True,
    "ibusplatforminputcontextplugin": True,
    "platforminputcontext_plugins": True,
    "qxdgdesktopportal": True,
    "platformtheme_plugins": True,
    "wayland_client": True,
    "wl_shell_integration_private": True,
    "qwayland": True,
    "qwayland_plugin": True,
    "qwayland_bradient_decoration_plugin": True,
    "qwayland_xdg_shell_integration_plugin": True,
    "qwayland_wl_shell_integration_plugin": True,
    "qwayland_fullscreen_shell_v1_plugin": True,
    "qwayland_egl_client_buffer_plugin": True,
    "qwayland_shm_emulation_server_buffer_plugin": True,
    "qwayland_drm_egl_server_buffer_plugin": True,
    "qminimal_plugin": True,
}

_QTDECLARATIVE_GUI_TARGETS = {
    "quick": True,
    "qtquick2plugin": True,
    "quickwindow": True,
    "quicklayouts": True,
    "qquicklayoutsplugin": True,
    "quickshapes": True,
    "qmlshapesplugin": True,
    "quickshapesdesignhelpers": True,
    "qtquickshapesdesignhelpersplugin": True,
    "quickshapesdesignhelpersplugin": True,
    "quickparticles": True,
    "particlesplugin": True,
    "quickeffects": True,
    "effectsplugin": True,
    "quickvectorimagegenerator": True,
    "quickvectorimagehelpers": True,
    "qquickvectorimagehelpersplugin": True,
    "quickvectorimagehelpersplugin": True,
    "quickvectorimage": True,
    "qquickvectorimageplugin": True,
    "quickvectorimageplugin": True,
    "quicktemplates2": True,
    "qtquicktemplates2plugin": True,
    "quickcontrols2impl": True,
    "qtquickcontrols2implplugin": True,
    "quickcontrols2": True,
    "qtquickcontrols2plugin": True,
    "quickcontrols2basicstyleimpl": True,
    "qtquickcontrols2basicstyleimplplugin": True,
    "quickcontrols2basic": True,
    "qtquickcontrols2basicstyleplugin": True,
    "quickcontrols2fusionstyleimpl": True,
    "qtquickcontrols2fusionstyleimplplugin": True,
    "quickcontrols2fusion": True,
    "qtquickcontrols2fusionstyleplugin": True,
    "quickcontrols2materialstyleimpl": True,
    "qtquickcontrols2materialstyleimplplugin": True,
    "quickcontrols2material": True,
    "qtquickcontrols2materialstyleplugin": True,
    "quickcontrols2universalstyleimpl": True,
    "qtquickcontrols2universalstyleimplplugin": True,
    "quickcontrols2universal": True,
    "qtquickcontrols2universalstyleplugin": True,
    "quickcontrols2imaginestyleimpl": True,
    "qtquickcontrols2imaginestyleimplplugin": True,
    "quickcontrols2imagine": True,
    "qtquickcontrols2imaginestyleplugin": True,
    "quickcontrols2fluentwinui3styleimpl": True,
    "qtquickcontrols2fluentwinui3styleimplplugin": True,
    "quickcontrols2fluentwinui3": True,
    "qtquickcontrols2fluentwinui3styleplugin": True,
    "quicknativestyle": True,
    "qtquickcontrols2nativestyleplugin": True,
    "quickcontrols2macosstyleimpl": True,
    "qtquickcontrols2macosstyleimplplugin": True,
    "quickcontrols2macos": True,
    "qtquickcontrols2macosstyleplugin": True,
    "quickcontrols2iosstyleimpl": True,
    "qtquickcontrols2iosstyleimplplugin": True,
    "quickcontrols2ios": True,
    "qtquickcontrols2iosstyleplugin": True,
    "quickcontrols2windowsstyleimpl": True,
    "qtquickcontrols2windowsstyleimplplugin": True,
    "quickcontrols2windows": True,
    "qtquickcontrols2windowsstyleplugin": True,
    "quickdialogs2utils": True,
    "quickdialogs2quickimpl": True,
    "qtquickdialogs2quickimplplugin": True,
    "quickdialogs2": True,
    "qtquickdialogsplugin": True,
    "labsanimation": True,
    "labsanimationplugin": True,
    "labsplatform": True,
    "qtlabsplatformplugin": True,
    "labswavefrontmesh": True,
    "qmlwavefrontmeshplugin": True,
    "labssharedimage": True,
    "sharedimageplugin": True,
    "qtlabssharedimageplugin": True,
    "quickwidgets": True,
    "quicktest": True,
    "quicktestplugin": True,
    "qmldbg_inspector": True,
    "qmldbg_preview": True,
    "qmldbg_quickprofiler": True,
}

_OTHER_GUI_KEYS = {
    "@qtgrpc//:protobufqtguitypes": True,
    "@qtpositioning//:positioningquick": True,
    "@qtpositioning//:positioningquickplugin": True,
    "@qtremoteobjects//:remoteobjectsqml": True,
    "@qtremoteobjects//:declarative_remoteobjects": True,
    "@qtscxml//:statemachine": True,
    "@qtscxml//:statemachineqml": True,
    "@qtscxml//:qtqmlstatemachine": True,
    ":designer_app_lib": True,
    ":linguist_app_lib": True,
    ":qdbusviewer_app_lib": True,
    ":pixeltool_app_lib": True,
    ":qdistancefieldgenerator_app_lib": True,
    ":qev_app_lib": True,
}

def _needs_gui_plugin(deps):
    if type(deps) != type([]):
        return False
    for dep in deps:
        key = _dep_key(dep)
        if key in _OTHER_GUI_KEYS:
            return True
        repo = key.split("//", 1)[0] if "//" in key else ""
        target = key.rsplit(":", 1)[-1]
        if repo in _GUI_REPOS:
            return True
        if repo == "@qtquick3d" and target != "glslparser":
            return True
        if repo in ("@qtbase", "") and target in _QTBASE_GUI_TARGETS:
            return True
        if repo in ("@qtdeclarative", "") and target in _QTDECLARATIVE_GUI_TARGETS:
            return True
    return False

# Per-target-OS QPA (windowing system) configuration for GUI binaries, in the
# style of reference/qt6_from_binary/qt.bzl's LINUX_*_ENV_DATA tables.
#
#   plugins: static QPA plugins to link in addition to `offscreen`.
#   env:     default runtime environment for `bazel run`/`bazel test`.
#
# `offscreen` is always linked. Without an explicit `QT_QPA_PLATFORM`, Qt
# on Linux probes `wayland` and `xcb` first whenever it detects a desktop
# session, warning for each plugin that is not linked in. Pinning a
# `;`-separated list keeps desktop runs quiet and headless runs working.
_QPA_PLATFORM_CONFIG = {
    Label("@platforms//os:linux"): {
        "plugins": [
            Label("@qtbase//:xcb"),
            Label("@qtbase//:qxcb_glx_integration"),
            Label("@qtbase//:qxcb_egl_integration"),
            Label("@qtbase//:qwayland"),
            Label("@qtbase//:qwayland_xdg_shell_integration_plugin"),
            Label("@qtbase//:qwayland_wl_shell_integration_plugin"),
            Label("@qtbase//:qwayland_bradient_decoration_plugin"),
            Label("@qtbase//:qwayland_egl_client_buffer_plugin"),
        ],
        "env": {"QT_QPA_PLATFORM": "xcb;wayland;offscreen"},
    },
    Label("@platforms//os:macos"): {
        "plugins": [Label("@qtbase//:cocoa")],
        "env": {"QT_QPA_PLATFORM": "cocoa;offscreen"},
    },
    Label("@platforms//os:windows"): {
        "plugins": [Label("@qtbase//:windows")],
        "env": {"QT_QPA_PLATFORM": "windows;offscreen"},
    },
    "//conditions:default": {
        "plugins": [],
        "env": {},
    },
}

def _update_dict(source, overrides):
    result = {}
    result.update(source)
    result.update(overrides)
    return result

def _platform_plugin_selects(deps, env):
    """Builds `select()`s for the per-OS QPA plugins and runtime environment.

    Plugins already present in `deps` are skipped so that Bazel never sees
    duplicate labels. Keys in `env` take precedence over the per-OS defaults.

    Returns:
      A `(deps_select, env_select)` tuple.
    """
    deps_by_os = {}
    env_by_os = {}
    for condition, cfg in _QPA_PLATFORM_CONFIG.items():
        new_plugins = [p for p in cfg["plugins"] if not _has_dep(deps, _dep_key(p))]
        deps_by_os[condition] = new_plugins
        env_by_os[condition] = _update_dict(cfg["env"], env)
    return select(deps_by_os), select(env_by_os)

def qt_export_header(name, module_name = None, module_Header = None, module_infix = None, macro_prefix = None, out = None, **kwargs):
    """Generates a Qt module export header (qt<module>exports.h)."""
    if module_infix == None and macro_prefix != None:
        module_infix = macro_prefix[2:] if macro_prefix.startswith("Q_") else macro_prefix
    if module_infix == None and module_name != None:
        module_infix = module_name[2:].upper() if module_name.startswith("Qt") else module_name.upper()
    if out == None and module_name != None:
        out = name + "_inc/qt" + module_name.lower() + "exports.h"
    _qt_export_header_rule(
        name = name,
        module_infix = module_infix,
        out = out,
        **kwargs
    )

def qt_config_header(name, out, content, **kwargs):
    """Writes a Qt module configuration header (e.g., qt*-config.h)."""
    qt_write_file(
        name = name,
        out = name + "_inc/" + out,
        content = content,
        **kwargs
    )

def _common_source_dir(hdrs):
    if type(hdrs) != type([]):
        return "src"
    str_hdrs = [h for h in hdrs if type(h) == type("") and not h.startswith(":")]
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

def qt_module_headers(
        name,
        hdrs,
        module_name,
        extra_deps = [],
        extra_hdrs = [],
        extra_private_hdrs = [],
        source_dir = None,
        version = "6.10.2",
        **kwargs):
    """Runs syncqt to stage camel-case, public, and private headers for a Qt module."""
    full_mod = module_name if module_name.startswith("Qt") else "Qt" + module_name
    if source_dir == None:
        source_dir = _common_source_dir(hdrs)
    depends_target = name + "_depends_h"
    qt_depends_header(
        name = depends_target,
        out = name + "_gen/" + full_mod + "Depends",
        dep_modules = [],
        target_compatible_with = kwargs.get("target_compatible_with"),
        testonly = kwargs.get("testonly"),
    )
    pub_hdrs = list(extra_hdrs) + [":" + depends_target]
    for d in extra_deps:
        if type(d) == type("") and d.endswith("_export"):
            pub_hdrs.append(d)
    qt_sync_headers(
        name = name,
        module_name = full_mod,
        version = version,
        source_dir = source_dir,
        hdrs = hdrs,
        generated_public_hdrs = pub_hdrs,
        generated_private_hdrs = extra_private_hdrs,
        deps = extra_deps,
        **kwargs
    )

def qt_generate_qrc(name, srcs, prefix, strip_prefix = "", rcc_options = [], qrc_name = None, out = None, **kwargs):
    """Generates a .qrc file from `srcs` and compiles it to a C++ source via rcc."""
    if out != None:
        _qt_generate_qrc_rule(
            name = name,
            out = out,
            prefix = prefix,
            strip_prefix = strip_prefix,
            srcs = srcs,
            **kwargs
        )
        return
    qrc_target = name + "_qrc_file"
    _qt_generate_qrc_rule(
        name = qrc_target,
        out = name + ".qrc",
        prefix = prefix,
        strip_prefix = strip_prefix,
        srcs = srcs,
        target_compatible_with = kwargs.get("target_compatible_with"),
        testonly = kwargs.get("testonly"),
    )
    qt_rcc_internal(
        name = name,
        qrc = ":" + qrc_target,
        qrc_name = qrc_name if qrc_name != None else name,
        data = srcs,
        rcc_options = rcc_options,
        **kwargs
    )

# Known .cpp files across Qt submodules that `#include "<stem>.moc"`.
_KNOWN_MODULE_MOC_SRCS = {
    "src/sensors/qsensormanager.cpp": True,
    "src/location/maps/qgeotilerequestmanager.cpp": True,
    "src/scxml/qscxmlcompiler.cpp": True,
    "src/statemachine/qstatemachine.cpp": True,
    "src/statemachine/qhistorystate.cpp": True,
}

def qt_qml_module(
        name,
        import_name,
        import_version = "6.10",
        past_major_versions = [],
        srcs = [],
        hdrs = [],
        qml_files = [],
        qml_singletons = [],
        qml_internal_files = [],
        qml_source_versions = {},
        qml_imports = [],
        qml_optional_imports = [],
        qml_default_imports = [],
        qml_depends = [],
        linktarget = None,
        qmldir_content = None,
        strip_prefix = "",
        plugin_target = None,
        plugin_class_name = None,
        plugin_optional = True,
        plugin_deps = [],
        plugin_srcs = None,
        plugin_moc_srcs = None,
        plugin_rcc_targets = [],
        plugin_aliases = [],
        generate_plugin = True,
        designer_supported = False,
        foreign_types = [],
        included_moc_hdrs = [],
        moc_hdrs = None,
        moc_srcs = None,
        moc_opts = [],
        includes = [],
        copts = [],
        defines = [],
        local_defines = [],
        deps = [],
        create_shared = False,
        **kwargs):
    """Builds a Qt QML module (with qmltyperegistrar, qmldir, qmlcachegen, and optional plugin)."""
    actual_moc_hdrs = hdrs if moc_hdrs == None else moc_hdrs
    if included_moc_hdrs:
        if type(actual_moc_hdrs) == type([]):
            seen_h = {h: True for h in actual_moc_hdrs}
            for h in included_moc_hdrs:
                if h not in seen_h:
                    seen_h[h] = True
                    actual_moc_hdrs = actual_moc_hdrs + [h]
        else:
            actual_moc_hdrs = actual_moc_hdrs + included_moc_hdrs
    if moc_srcs == None:
        if type(srcs) == type([]):
            moc_srcs = [s for s in srcs if type(s) == type("") and s in _KNOWN_MODULE_MOC_SRCS]
        else:
            moc_srcs = []

    ver_parts = import_version.split(".")
    major_ver = ver_parts[0] if len(ver_parts) > 0 else "6"
    minor_ver = ver_parts[1] if len(ver_parts) > 1 else "10"

    if qmldir_content == None:
        qmldir_content = qt_generate_qmldir_content(
            uri = import_name,
            major_version = major_ver,
            minor_version = minor_ver,
            past_major_versions = past_major_versions,
            linktarget = linktarget,
            plugin_target = plugin_target,
            class_name = plugin_class_name,
            plugin_optional = plugin_optional,
            designer_supported = designer_supported,
            default_imports = qml_default_imports,
            imports = qml_imports,
            optional_imports = qml_optional_imports,
            depends = qml_depends,
            qml_files = qml_files,
            strip_prefix = strip_prefix,
            qml_singletons = qml_singletons,
            qml_internal_files = qml_internal_files,
            qml_source_versions = qml_source_versions,
        )

    target_compatible_with = kwargs.get("target_compatible_with", None)
    testonly = kwargs.get("testonly", None)
    helper_kwargs = {}
    if target_compatible_with != None:
        helper_kwargs["target_compatible_with"] = target_compatible_with
    if testonly != None:
        helper_kwargs["testonly"] = testonly

    # When `generate_plugin = False` AND `plugin_class_name` is set AND `plugin_srcs == None`,
    # the hand-written plugin class is compiled directly inside `srcs` (e.g. qtvkbbuiltinstyles).
    has_embedded_plugin_src = (plugin_srcs == None) and type(srcs) == type([]) and any([
        type(s) == type("") and (s.endswith("plugin.cpp") or s.endswith("plugin_main.cpp"))
        for s in srcs
    ])
    embedded_handwritten_plugin = (not generate_plugin) and (plugin_class_name != None) and has_embedded_plugin_src
    mod_srcs = list(srcs) if type(srcs) == type([]) else srcs
    mod_local_defines = _with_building_qt(local_defines)
    mod_moc_opts = list(moc_opts)
    if embedded_handwritten_plugin:
        mod_local_defines = mod_local_defines + ["QT_PLUGIN", "QT_STATICPLUGIN"]
        if ("-Muri=" + import_name) not in mod_moc_opts:
            mod_moc_opts.append("-Muri=" + import_name)
        qrc_name = "qmake_" + import_name.replace(".", "_")
        import_gen_target = name + "_plugin_import_gen"
        qt_write_file(
            name = import_gen_target,
            out = name + "_plugin_import.cpp",
            content = """#include <QtCore/QtPlugin>
#include <QtCore/qtsymbolmacros.h>
Q_IMPORT_PLUGIN({class_name})
QT_DECLARE_EXTERN_RESOURCE({qrc_name})
namespace {{
struct {class_name}_KeepQrc {{
    {class_name}_KeepQrc() {{ QT_KEEP_RESOURCE({qrc_name}); }}
}} g_{class_name}_keep_qrc;
}}
""".format(class_name = plugin_class_name, qrc_name = qrc_name),
            **helper_kwargs
        )
        mod_srcs = mod_srcs + [":" + import_gen_target]
    elif (not generate_plugin) and (plugin_srcs == None) and (type(mod_srcs) == type([])):
        # Pure-QML or external-plugin module (like qtvkbplugins or positioningquick):
        # ensure qmake_<uri> (qmldir) and qmlcache_<name> resources are retained at static init.
        qrc_name = "qmake_" + import_name.replace(".", "_")
        keep_lines = [
            "#include <QtCore/qtsymbolmacros.h>",
            "QT_DECLARE_EXTERN_RESOURCE({qrc_name})".format(qrc_name = qrc_name),
        ]
        keep_calls = ["QT_KEEP_RESOURCE({qrc_name});".format(qrc_name = qrc_name)]
        if qml_files:
            cache_qrc = "qmlcache_" + name
            raw_qrc = name + "_raw_qml_0"
            keep_lines.append("QT_DECLARE_EXTERN_RESOURCE({cache_qrc})".format(cache_qrc = cache_qrc))
            keep_lines.append("QT_DECLARE_EXTERN_RESOURCE({raw_qrc})".format(raw_qrc = raw_qrc))
            keep_calls.append("QT_KEEP_RESOURCE({cache_qrc});".format(cache_qrc = cache_qrc))
            keep_calls.append("QT_KEEP_RESOURCE({raw_qrc});".format(raw_qrc = raw_qrc))
        keep_lines.extend([
            "namespace {",
            "struct KeepQrc_" + name + " {",
            "    KeepQrc_" + name + "() {",
            "        " + "\n        ".join(keep_calls),
            "    }",
            "} g_keep_qrc_" + name + ";",
            "}",
            "",
        ])
        keep_gen_target = name + "_keep_qrc_gen"
        qt_write_file(
            name = keep_gen_target,
            out = name + "_keep_qrc.cpp",
            content = "\n".join(keep_lines),
            **helper_kwargs
        )
        mod_srcs = mod_srcs + [":" + keep_gen_target]

    qt_internal_library(
        name = name,
        srcs = mod_srcs,
        hdrs = hdrs,
        moc_hdrs = actual_moc_hdrs,
        moc_srcs = moc_srcs,
        moc_opts = mod_moc_opts,
        qml_args = {
            "uri": import_name,
            "major_version": major_ver,
            "minor_version": minor_ver,
            "past_major_versions": past_major_versions,
            "foreign_types": foreign_types,
            "qmldir_content": qmldir_content,
            "qml_files": qml_files,
            "qml_strip_prefix": strip_prefix,
        },
        includes = includes,
        copts = ["-w"] + copts,
        defines = defines,
        local_defines = mod_local_defines,
        deps = deps,
        create_shared = create_shared,
        moc_unity = kwargs.pop("moc_unity", True),
        **kwargs
    )

    if embedded_handwritten_plugin and plugin_target and plugin_target != name:
        native.alias(
            name = plugin_target,
            actual = ":" + name,
            **helper_kwargs
        )

    if plugin_target and plugin_class_name and (generate_plugin or plugin_srcs != None):
        if plugin_srcs != None:
            actual_plugin_srcs = plugin_srcs
            actual_plugin_moc_srcs = plugin_moc_srcs if plugin_moc_srcs != None else plugin_srcs
        else:
            gen_target = plugin_target + "_gen"
            qt_qml_plugin_gen(
                name = gen_target,
                plugin_name = plugin_target,
                class_name = plugin_class_name,
                uri = import_name,
                **helper_kwargs
            )
            actual_plugin_srcs = [":" + gen_target]
            actual_plugin_moc_srcs = [":" + gen_target]
        qt_static_plugin(
            name = plugin_target,
            plugin_class_name = plugin_class_name,
            srcs = actual_plugin_srcs,
            moc_srcs = actual_plugin_moc_srcs,
            moc_opts = ["-Muri=" + import_name],
            rcc_targets = plugin_rcc_targets,
            includes = includes,
            copts = ["-w"] + copts,
            local_defines = _with_building_qt(local_defines),
            deps = [":" + name] + deps + plugin_deps,
            **helper_kwargs
        )
        for alias_name in plugin_aliases:
            native.alias(
                name = alias_name,
                actual = ":" + plugin_target,
                **helper_kwargs
            )

common_copts = [
    "-w",
    "-fPIC",
    "-DQT_NO_CAST_TO_ASCII",
    "-DQT_BUILDING_QT",
    "-Wno-expansion-to-defined",
] + select({
    Label("@qt//:debug_build"): [],
    "//conditions:default": [
        "-O2",
        "-DNDEBUG",
    ],
})

common_defines = select({
    Label("@qt//:debug_build"): [],
    "//conditions:default": ["QT_NO_DEBUG"],
})

def _with_building_qt(local_defines):
    """Returns `local_defines` with `QT_BUILDING_QT` added if missing.

    Qt headers switch logging-category and other internal macros on it, so
    module code must always be built with it.
    """
    if type(local_defines) != type([]):
        return local_defines + ["QT_BUILDING_QT"]
    for d in local_defines:
        if d == "QT_BUILDING_QT" or d.startswith("QT_BUILDING_QT="):
            return local_defines
    return ["QT_BUILDING_QT"] + local_defines

def qt_plugin(
        name,
        plugin_class_name,
        srcs = [],
        hdrs = [],
        textual_hdrs = [],
        included_moc_hdrs = [],
        moc_hdrs = None,
        moc_srcs = None,
        moc_opts = [],
        includes = [],
        copts = [],
        defines = [],
        local_defines = [],
        deps = [],
        linkopts = [],
        moc_unity = True,
        target_compatible_with = None,
        **kwargs):
    """Builds a Qt static plugin library (wrapping qt_static_plugin)."""
    testonly = kwargs.get("testonly", None)
    actual_moc_hdrs = hdrs if moc_hdrs == None else moc_hdrs
    if included_moc_hdrs:
        if type(actual_moc_hdrs) == type([]):
            seen_h = {h: True for h in actual_moc_hdrs}
            for h in included_moc_hdrs:
                if h not in seen_h:
                    seen_h[h] = True
                    actual_moc_hdrs = actual_moc_hdrs + [h]
        else:
            actual_moc_hdrs = actual_moc_hdrs + included_moc_hdrs
    if moc_srcs == None:
        if type(srcs) == type([]):
            moc_srcs = [
                s
                for s in srcs
                if type(s) == type("") and s.endswith(".cpp") and not s.startswith(":")
            ]
        else:
            moc_srcs = []
    qt_static_plugin(
        name = name,
        plugin_class_name = plugin_class_name,
        srcs = srcs,
        hdrs = hdrs,
        textual_hdrs = textual_hdrs,
        moc_hdrs = actual_moc_hdrs,
        moc_srcs = moc_srcs,
        moc_opts = moc_opts,
        includes = includes,
        copts = ["-w"] + copts,
        defines = defines,
        local_defines = _with_building_qt(local_defines),
        deps = deps,
        linkopts = linkopts,
        moc_unity = moc_unity,
        target_compatible_with = target_compatible_with,
        testonly = testonly,
    )

# Backwards-compatible alias while module overlays migrate to qt_plugin.
qt_plugin_FixMe = qt_plugin

def qt_ui_library(name, src = None, uis = None, deps = None, **kwargs):
    """Compiles one or more Qt Designer .ui files to C++ headers and wraps them in a cc_library.

    Args:
      name: Target name.
      src: Single `.ui` file. The generated header follows uic's convention,
        `ui_<basename>.h` (e.g. `foo.ui` -> `ui_foo.h`).
      uis: Optional list of `.ui` files (alternative to `src`).
      deps: Extra deps; defaults to `@qtbase//:widgets`.
      **kwargs: Forwarded to `cc_library`.
    """
    if deps == None:
        deps = [Label("@qtbase//:widgets")]
    testonly = kwargs.get("testonly", None)
    target_compatible_with = kwargs.get("target_compatible_with", None)
    gen_kwargs = {}
    if testonly != None:
        gen_kwargs["testonly"] = testonly
    if target_compatible_with != None:
        gen_kwargs["target_compatible_with"] = target_compatible_with
    uic_tool = Label("@qtbase//:uic")
    ui_list = list(uis) if uis != None else ([src] if src != None else [])
    out_dir = ("%s_ui_out" % name) if uis != None else ""
    uic_hdrs = []
    for i, u in enumerate(ui_list):
        base = u.split("/")[-1]
        if base.endswith(".ui"):
            base = base[:-3]
        out_hdr = ("%s/ui_%s.h" % (out_dir, base)) if out_dir else ("ui_%s.h" % base)
        gen_name = "%s_uic" % name if len(ui_list) == 1 else "%s_%d_%s_uic" % (name, i, base)
        native.genrule(
            name = gen_name,
            srcs = [u],
            outs = [out_hdr],
            cmd = select({
                Label("@platforms//os:linux"): "LC_ALL=C.UTF-8 $(execpath %s) $(location %s) -o $@" % (uic_tool, u),
                "//conditions:default": "$(execpath %s) $(location %s) -o $@" % (uic_tool, u),
            }),
            tools = [uic_tool],
            **gen_kwargs
        )
        uic_hdrs.append(":" + gen_name)
    cc_library(
        name = name,
        hdrs = uic_hdrs,
        includes = [out_dir if out_dir else "."],
        deps = deps,
        **kwargs
    )

def qt_resource(name, files = None, qrc_file = None, resources = None, prefix = "/", deps = None, **kwargs):
    """Generates a .qrc file from `files` (or uses `qrc_file` + `resources`), compiles it with rcc."""
    if resources != None and qrc_file != None and files == None:
        qt_rcc_internal(
            name = name,
            qrc = qrc_file,
            qrc_name = name,
            data = resources,
            **kwargs
        )
        return
    if deps == None:
        deps = [Label("@qtbase//:core")]
    if not qrc_file:
        qrc_file = "qrc_%s.qrc" % name

    helper_kwargs = {}
    if kwargs.get("testonly") != None:
        helper_kwargs["testonly"] = kwargs.get("testonly")
    if kwargs.get("target_compatible_with") != None:
        helper_kwargs["target_compatible_with"] = kwargs.get("target_compatible_with")

    _qt_generate_qrc_rule(
        name = "%s_qrc" % name,
        out = qrc_file,
        prefix = prefix,
        strip_prefix = native.package_name(),
        srcs = files,
        **helper_kwargs
    )

    qt_rcc_internal(
        name = "%s_rcc" % name,
        qrc = ":%s_qrc" % name,
        qrc_name = name,
        data = files,
        **helper_kwargs
    )

    cc_library(
        name = name,
        srcs = [":%s_rcc" % name],
        deps = deps,
        alwayslink = True,
        **kwargs
    )

def qt_resource_via_qrc(name, qrc_file, files = [], deps = None, **kwargs):
    """Compiles an existing .qrc file with rcc and wraps the generated C++ source in a cc_library.

    Args:
      name: Target name.
      qrc_file: The hand-written `.qrc` file.
      files: The files referenced by `qrc_file` (must be listed so Bazel provides them).
      deps: Extra deps; defaults to `@qtbase//:core`.
      **kwargs: Forwarded to `cc_library`.
    """
    if deps == None:
        deps = [Label("@qtbase//:core")]
    helper_kwargs = {}
    if kwargs.get("testonly") != None:
        helper_kwargs["testonly"] = kwargs.get("testonly")
    if kwargs.get("target_compatible_with") != None:
        helper_kwargs["target_compatible_with"] = kwargs.get("target_compatible_with")
    qt_rcc_internal(
        name = "%s_rcc" % name,
        qrc = qrc_file,
        qrc_name = name,
        data = files,
        **helper_kwargs
    )
    cc_library(
        name = name,
        srcs = [":%s_rcc" % name],
        deps = deps,
        alwayslink = True,
        **kwargs
    )

def qt_cc_library(
        name,
        srcs = [],
        hdrs = [],
        included_moc_hdrs = [],
        moc_hdrs = None,
        moc_srcs = None,
        includes = [],
        copts = [],
        defines = [],
        local_defines = [],
        deps = [],
        moc_unity = True,
        create_shared = False,
        dynamic_deps = [],
        exports_filter = [],
        **kwargs):
    """A cc_library wrapper that runs Qt's moc on headers and sources.

    Args:
      name: Target name.
      srcs: C++ sources.
      hdrs: Headers; all of them are moc'ed unless `moc_hdrs` is given.
      included_moc_hdrs: Extra headers to moc in addition to `hdrs`/`moc_hdrs`.
      moc_hdrs: Explicit list of headers to run moc on.
      moc_srcs: Sources that `#include "<stem>.moc"`; auto-detected for known files.
      includes: Forwarded to `cc_library` and moc.
      copts: Forwarded to `cc_library` and moc.
      defines: Public defines.
      local_defines: Private defines.
      deps: Dependencies.
      moc_unity: Compile moc outputs through a single `mocs_compilation.cpp`
        (CMake AUTOMOC behaviour).
      create_shared: Whether to also create `<name>_shared` and provide `QtSharedLibraryInfo`.
      dynamic_deps: Shared library dependencies when `create_shared` is True.
      exports_filter: Forwarded to `cc_shared_library` when `create_shared` is True.
      **kwargs: Forwarded to `cc_library`.
    """
    actual_moc_hdrs = hdrs if moc_hdrs == None else moc_hdrs
    if included_moc_hdrs:
        if type(actual_moc_hdrs) == type([]):
            seen_h = {h: True for h in actual_moc_hdrs}
            for h in included_moc_hdrs:
                if h not in seen_h:
                    seen_h[h] = True
                    actual_moc_hdrs = actual_moc_hdrs + [h]
        else:
            actual_moc_hdrs = actual_moc_hdrs + included_moc_hdrs
    if moc_srcs == None:
        if type(srcs) == type([]):
            moc_srcs = [s for s in srcs if type(s) == type("") and s in _KNOWN_MODULE_MOC_SRCS]
        else:
            moc_srcs = []

    if create_shared or bool(dynamic_deps):
        qt_internal_library(
            name = name,
            srcs = srcs,
            hdrs = hdrs,
            moc_hdrs = actual_moc_hdrs,
            moc_srcs = moc_srcs,
            includes = includes,
            copts = copts,
            defines = defines,
            local_defines = local_defines,
            deps = deps + (select({
                Label("@platforms//os:linux"): [Label("@qtbase//:glvnd_stubs")],
                "//conditions:default": [],
            }) if _needs_gui_plugin(deps) else []),
            moc_unity = moc_unity,
            create_shared = create_shared,
            dynamic_deps = dynamic_deps,
            exports_filter = exports_filter,
            **kwargs
        )
        return

    target_compatible_with = kwargs.get("target_compatible_with", None)
    testonly = kwargs.get("testonly", None)
    tags = kwargs.get("tags", None)
    common_kwargs = {}
    if target_compatible_with != None:
        common_kwargs["target_compatible_with"] = target_compatible_with
    if testonly != None:
        common_kwargs["testonly"] = testonly
    if tags != None:
        common_kwargs["tags"] = tags

    extra_srcs = []
    extra_deps = []

    if actual_moc_hdrs or moc_srcs:
        moc_target = "%s_moc" % name
        moc_gen(
            name = moc_target,
            hdrs = actual_moc_hdrs,
            srcs = moc_srcs,
            target_srcs = srcs,
            other_hdrs = hdrs,
            includes = includes,
            defines = defines + local_defines,
            copts = copts,
            deps = deps,
            unity = moc_unity,
            **common_kwargs
        )
        native.alias(
            name = "%s_moc_hdrs" % name,
            actual = ":" + moc_target,
            **common_kwargs
        )
        moc_lib = "%s_moc_lib" % name
        cc_library(
            name = moc_lib,
            textual_hdrs = [":" + moc_target],
            **common_kwargs
        )
        extra_deps.append(":" + moc_lib)
        copts = copts + moc_out_copts(moc_target)

        # .moc outputs from moc_srcs are reached via textual_hdrs; only header
        # moc produces compilable moc_*.cpp files.
        if actual_moc_hdrs:
            if moc_unity:
                native.filegroup(
                    name = moc_target + "_compile_srcs",
                    srcs = [":" + moc_target],
                    output_group = "compile_srcs",
                    **common_kwargs
                )
                extra_srcs.append(":" + moc_target + "_compile_srcs")
            else:
                extra_srcs.append(":" + moc_target)

    _qt_cc_library_rule(
        name = name,
        srcs = srcs + extra_srcs,
        hdrs = hdrs,
        includes = ["."] + includes,
        copts = copts + QT_PLATFORM_COPTS,
        defines = defines,
        local_defines = local_defines + QT_PLATFORM_DEFINES,
        deps = deps + extra_deps + select({
            Label("@platforms//os:windows"): [Label("@qt//:win_cxxabi_shim")],
            "//conditions:default": [],
        }) + (select({
            Label("@platforms//os:linux"): [Label("@qtbase//:glvnd_stubs")],
            "//conditions:default": [],
        }) if _needs_gui_plugin(deps) else []),
        **kwargs
    )

def qt_cc_binary(
        name,
        srcs = [],
        hdrs = [],
        moc_hdrs = None,
        moc_srcs = None,
        includes = [],
        copts = [],
        defines = [],
        deps = [],
        dynamic_deps = [],
        autolink_plugins = True,
        win32_gui = False,
        **kwargs):
    """Builds a Qt C++ binary linked dynamically against Qt's LGPL cc_shared_library targets.

    Qt library deps (`@qtbase//:core`, `:gui`, `:widgets`, ...) are mapped automatically to
    the matching `*_shared` targets via `QtSharedLibraryInfo`. GUI binaries get the `offscreen`
    and per-OS QPA plugins linked in statically.

    Args:
      name: Target name.
      srcs: C++ sources. Sources are moc'd by default (see `moc_srcs`).
      hdrs: Headers; moc'd unless `moc_hdrs` is given.
      moc_hdrs: Headers containing Q_OBJECT to run moc on; defaults to `hdrs`.
      moc_srcs: Sources that `#include "<stem>.moc"`; defaults to all C++ `srcs`.
      includes: Forwarded to the generated libraries and moc.
      copts: Forwarded to `cc_binary`; `-D`/`-I` flags are also passed to moc.
      defines: Forwarded to `cc_binary` and moc.
      deps: Dependencies.
      dynamic_deps: Extra `cc_shared_library` deps beyond the auto-resolved Qt ones.
      autolink_plugins: Link the plugins implied by Qt library deps (image formats,
        TLS, SQL, multimedia/TTS/positioning/sensors/CAN backends, ...).
      win32_gui: On Windows, link as a GUI-subsystem application (`-mwindows`, no
        console window) with Qt's `WinMain` entry point (`@qtbase//:entrypoint`),
        like CMake's `WIN32_EXECUTABLE`. No effect on other platforms.
      **kwargs: Forwarded to `cc_binary`.
    """
    actual_moc_hdrs = hdrs if moc_hdrs == None else moc_hdrs
    if moc_srcs == None:
        if type(srcs) == type([]):
            moc_srcs = [s for s in srcs if s.endswith((".cpp", ".cc", ".cxx", ".mm"))]
        else:
            moc_srcs = []

    target_compatible_with = kwargs.get("target_compatible_with", None)
    testonly = kwargs.get("testonly", None)
    tags = kwargs.get("tags", None)
    common_kwargs = {}
    if target_compatible_with != None:
        common_kwargs["target_compatible_with"] = target_compatible_with
    if testonly != None:
        common_kwargs["testonly"] = testonly
    if tags != None:
        common_kwargs["tags"] = tags

    lib_deps = list(deps)
    is_gui = _needs_gui_plugin(lib_deps)
    if is_gui:
        for p in ("@qtbase//:offscreen", "@qtbase//:qgif", "@qtbase//:qico", "@qtbase//:qjpeg"):
            if not _has_dep(lib_deps, p):
                lib_deps.append(Label(p))
    if autolink_plugins:
        _add_implied_plugins(lib_deps)

    extra_srcs = []
    extra_deps = []
    if actual_moc_hdrs or moc_srcs:
        moc_target = "%s_moc" % name
        moc_gen(
            name = moc_target,
            hdrs = actual_moc_hdrs,
            srcs = moc_srcs,
            target_srcs = srcs,
            other_hdrs = hdrs,
            includes = includes,
            defines = defines,
            copts = copts,
            deps = lib_deps,
            **common_kwargs
        )
        moc_lib = "%s_moc_lib" % name
        cc_library(
            name = moc_lib,
            textual_hdrs = [":" + moc_target],
            **common_kwargs
        )
        extra_deps.append(":" + moc_lib)
        copts = copts + moc_out_copts(moc_target)

        # .moc outputs from moc_srcs are reached via textual_hdrs; only header
        # moc produces compilable moc_*.cpp files.
        if actual_moc_hdrs:
            extra_srcs.append(":" + moc_target)

    hdr_lib = "%s_hdrs_lib" % name
    if hdrs:
        cc_library(
            name = hdr_lib,
            hdrs = hdrs,
            includes = ["."] + includes,
            deps = lib_deps,
            **common_kwargs
        )
        extra_deps.append(":" + hdr_lib)

    cc_binary_kwargs = dict(kwargs)
    cc_binary_kwargs["features"] = list(cc_binary_kwargs.get("features", [])) + ["compiler_param_file"]
    binary_deps = lib_deps + extra_deps
    if is_gui:
        deps_sel, env_sel = _platform_plugin_selects(
            lib_deps,
            cc_binary_kwargs.pop("env", {}),
        )
        binary_deps = binary_deps + deps_sel + select({
            Label("@platforms//os:linux"): [Label("@qtbase//:glvnd_stubs")],
            "//conditions:default": [],
        })
        cc_binary_kwargs["env"] = env_sel

    if win32_gui:
        binary_deps = binary_deps + select({
            Label("@platforms//os:windows"): [Label("@qtbase//:entrypoint")],
            "//conditions:default": [],
        })
        cc_binary_kwargs["linkopts"] = cc_binary_kwargs.get("linkopts", []) + select({
            Label("@platforms//os:windows"): ["-mwindows"],
            "//conditions:default": [],
        })

    dyn_helper = name + "_qt_dynamic_deps"
    _qt_dynamic_deps_collector(
        name = dyn_helper,
        deps = binary_deps,
        dynamic_deps = dynamic_deps,
        **common_kwargs
    )

    cc_binary(
        name = name,
        srcs = srcs + extra_srcs,
        copts = copts + QT_PLATFORM_COPTS,
        defines = defines + QT_PLATFORM_DEFINES,
        deps = [":" + dyn_helper] + binary_deps,
        dynamic_deps = [":" + dyn_helper],
        **cc_binary_kwargs
    )

def qt_cc_test(
        name,
        srcs = [],
        hdrs = [],
        moc_hdrs = None,
        moc_srcs = None,
        includes = [],
        copts = [],
        defines = [],
        deps = [],
        dynamic_deps = [],
        env = {},
        autolink_plugins = True,
        **kwargs):
    """Builds a Qt C++ test linked dynamically against Qt's LGPL cc_shared_library targets.

    Same behaviour as `qt_cc_binary` (including the per-OS QPA plugins), but GUI tests
    default to `QT_QPA_PLATFORM=offscreen` so they stay headless under `bazel test`.
    Override via `env` or `--test_env=QT_QPA_PLATFORM=xcb` to run them on a display.

    Args:
      name: Target name.
      srcs: C++ sources. Sources are moc'd by default (see `moc_srcs`).
      hdrs: Headers; moc'd unless `moc_hdrs` is given.
      moc_hdrs: Headers containing Q_OBJECT to run moc on; defaults to `hdrs`.
      moc_srcs: Sources that `#include "<stem>.moc"`; defaults to all C++ `srcs`.
      includes: Forwarded to the generated libraries and moc.
      copts: Forwarded to `cc_test`; `-D`/`-I` flags are also passed to moc.
      defines: Forwarded to `cc_test` and moc.
      deps: Dependencies.
      dynamic_deps: Extra `cc_shared_library` deps beyond the auto-resolved Qt ones.
      env: Test environment; `QT_QPA_PLATFORM` defaults to `offscreen` for GUI tests.
      autolink_plugins: Link the plugins implied by Qt library deps (see `qt_cc_binary`).
      **kwargs: Forwarded to `cc_test`.
    """
    actual_moc_hdrs = hdrs if moc_hdrs == None else moc_hdrs
    if moc_srcs == None:
        if type(srcs) == type([]):
            moc_srcs = [s for s in srcs if s.endswith((".cpp", ".cc", ".cxx", ".mm"))]
        else:
            moc_srcs = []

    target_compatible_with = kwargs.get("target_compatible_with", None)
    testonly = kwargs.get("testonly", True)
    tags = kwargs.get("tags", None)
    common_kwargs = {"testonly": testonly}
    if target_compatible_with != None:
        common_kwargs["target_compatible_with"] = target_compatible_with
    if tags != None:
        common_kwargs["tags"] = tags

    lib_deps = list(deps)
    is_gui = _needs_gui_plugin(lib_deps)
    if is_gui:
        for p in ("@qtbase//:offscreen", "@qtbase//:qgif", "@qtbase//:qico", "@qtbase//:qjpeg"):
            if not _has_dep(lib_deps, p):
                lib_deps.append(Label(p))
    if autolink_plugins:
        _add_implied_plugins(lib_deps)

    extra_srcs = []
    extra_deps = []
    if actual_moc_hdrs or moc_srcs:
        moc_target = "%s_moc" % name
        moc_gen(
            name = moc_target,
            hdrs = actual_moc_hdrs,
            srcs = moc_srcs,
            target_srcs = srcs,
            other_hdrs = hdrs,
            includes = includes,
            defines = defines,
            copts = copts,
            deps = lib_deps,
            **common_kwargs
        )
        moc_lib = "%s_moc_lib" % name
        cc_library(
            name = moc_lib,
            textual_hdrs = [":" + moc_target],
            **common_kwargs
        )
        extra_deps.append(":" + moc_lib)
        copts = copts + moc_out_copts(moc_target)

        # .moc outputs from moc_srcs are reached via textual_hdrs; only header
        # moc produces compilable moc_*.cpp files.
        if actual_moc_hdrs:
            extra_srcs.append(":" + moc_target)

    hdr_lib = "%s_hdrs_lib" % name
    if hdrs:
        cc_library(
            name = hdr_lib,
            hdrs = hdrs,
            includes = ["."] + includes,
            deps = lib_deps,
            **common_kwargs
        )
        extra_deps.append(":" + hdr_lib)

    test_deps = lib_deps + extra_deps
    test_env = env
    if is_gui:
        # GUI tests link the same per-OS QPA plugins as binaries so they can be
        # run interactively (e.g. --test_env=QT_QPA_PLATFORM=xcb), but default
        # to offscreen so sandboxed `bazel test` stays headless. Precedence:
        # caller `env` > offscreen > per-OS default.
        deps_sel, test_env = _platform_plugin_selects(
            lib_deps,
            _update_dict({"QT_QPA_PLATFORM": "offscreen"}, env),
        )
        test_deps = test_deps + deps_sel + select({
            Label("@platforms//os:linux"): [Label("@qtbase//:glvnd_stubs")],
            "//conditions:default": [],
        })

    cc_test_kwargs = dict(kwargs)
    cc_test_kwargs["features"] = list(cc_test_kwargs.get("features", [])) + ["compiler_param_file"]

    dyn_helper = name + "_qt_dynamic_deps"
    _qt_dynamic_deps_collector(
        name = dyn_helper,
        deps = test_deps,
        dynamic_deps = dynamic_deps,
        **common_kwargs
    )

    cc_test(
        name = name,
        srcs = srcs + extra_srcs,
        copts = copts + QT_PLATFORM_COPTS,
        defines = defines + QT_PLATFORM_DEFINES,
        deps = [":" + dyn_helper] + test_deps,
        dynamic_deps = [":" + dyn_helper],
        env = test_env,
        **cc_test_kwargs
    )

def qt_cc_shared_library(
        name,
        deps,
        qt_deps = None,
        dynamic_deps = [],
        exports_filter = [],
        **kwargs):
    """A `cc_shared_library` that links Qt dynamically (F-INF-9).

    The Qt libraries used by `deps` (and any listed in `qt_deps`) are resolved
    to their `*_shared` counterparts via `QtSharedLibraryInfo` and added to
    `dynamic_deps`, so the resulting `.so`/`.dll` does not embed a private
    copy of QtCore/QtGui/... (which would break `QCoreApplication`,
    metatype and plugin singletons shared across libraries).

    Args:
      name: Target name.
      deps: Root `cc_library` targets of the shared library.
      qt_deps: Optional extra Qt library labels used by `deps`,
        e.g. `["@qtbase//:widgets"]`. Defaults to `[Label("@qtbase//:core")]`.
      dynamic_deps: Extra `cc_shared_library` deps.
      exports_filter: Forwarded to `cc_shared_library`.
      **kwargs: Forwarded to `cc_shared_library`.
    """
    if qt_deps == None:
        qt_deps = [Label("@qtbase//:core")]
    user_link_flags = kwargs.pop("user_link_flags", [])
    if "shared_lib_name" not in kwargs:
        # MinGW links dynamic deps with -l<name>, which only resolves a DLL
        # named lib<name>.dll (same convention as Qt's own *_shared targets).
        kwargs["shared_lib_name"] = select({
            Label("@platforms//os:windows"): "lib" + name + ".dll",
            "//conditions:default": "",
        })
    common_kwargs = {}
    if kwargs.get("target_compatible_with") != None:
        common_kwargs["target_compatible_with"] = kwargs.get("target_compatible_with")
    if kwargs.get("testonly") != None:
        common_kwargs["testonly"] = kwargs.get("testonly")
    if kwargs.get("tags") != None:
        common_kwargs["tags"] = kwargs.get("tags")

    dyn_helper = name + "_qt_dynamic_deps"
    _qt_dynamic_deps_collector(
        name = dyn_helper,
        deps = deps,
        qt_deps = list(qt_deps),
        dynamic_deps = dynamic_deps,
        **common_kwargs
    )

    cc_shared_library(
        name = name,
        deps = [":" + dyn_helper] + list(deps),
        dynamic_deps = [":" + dyn_helper],
        exports_filter = exports_filter,
        user_link_flags = user_link_flags + QT_SHARED_PLATFORM_LINKOPTS,
        **kwargs
    )
