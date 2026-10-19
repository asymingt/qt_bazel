"""Public Bazel rules for building Qt C++ libraries, binaries, tests, UI headers, and resources."""

load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_cc//cc:cc_shared_library.bzl", "cc_shared_library")
load("@rules_cc//cc:cc_test.bzl", "cc_test")
load(
    ":qt_internal_library.bzl",
    "QT_PLATFORM_COPTS",
    "QT_PLATFORM_DEFINES",
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

_QTQML_BASE_SHARED = [
    "@qtdeclarative//:qml_shared",
    "@qtbase//:network_shared",
    "@qtbase//:core_shared",
]

_QTQUICK_BASE_SHARED = [
    "@qtdeclarative//:quick_shared",
    "@qtdeclarative//:qmlmeta_shared",
    "@qtdeclarative//:qmlmodels_shared",
    "@qtdeclarative//:qmlworkerscript_shared",
    "@qtdeclarative//:qml_shared",
    "@qtbase//:opengl_shared",
    "@qtbase//:gui_shared",
    "@qtbase//:dbus_shared",
    "@qtbase//:network_shared",
    "@qtbase//:core_shared",
]

_QTQUICKCONTROLS2_BASE_SHARED = [
    "@qtdeclarative//:quickcontrols2_shared",
    "@qtdeclarative//:quickcontrols2impl_shared",
    "@qtdeclarative//:quicktemplates2_shared",
] + _QTQUICK_BASE_SHARED

# Map known @qtbase cc_library targets to their transitive cc_shared_library targets
_QTBASE_SHARED_MAP = {
    "@qtbase//:core": ["@qtbase//:core_shared"],
    ":core": ["@qtbase//:core_shared"],
    "@qtbase//:concurrent": ["@qtbase//:concurrent_shared", "@qtbase//:core_shared"],
    ":concurrent": ["@qtbase//:concurrent_shared", "@qtbase//:core_shared"],
    "@qtbase//:dbus": ["@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    ":dbus": ["@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtbase//:gui": ["@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    ":gui": ["@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtbase//:widgets": [
        "@qtbase//:widgets_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:core_shared",
    ],
    ":widgets": [
        "@qtbase//:widgets_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:core_shared",
    ],
    "@qtbase//:printsupport": [
        "@qtbase//:printsupport_shared",
        "@qtbase//:widgets_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:core_shared",
    ],
    ":printsupport": [
        "@qtbase//:printsupport_shared",
        "@qtbase//:widgets_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:core_shared",
    ],
    "@qtbase//:opengl": [
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:core_shared",
    ],
    ":opengl": [
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:core_shared",
    ],
    "@qtbase//:openglwidgets": [
        "@qtbase//:openglwidgets_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:widgets_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:core_shared",
    ],
    ":openglwidgets": [
        "@qtbase//:openglwidgets_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:widgets_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:core_shared",
    ],
    "@qtbase//:test": ["@qtbase//:test_shared", "@qtbase//:core_shared"],
    ":test": ["@qtbase//:test_shared", "@qtbase//:core_shared"],
    "@qtbase//:offscreen": ["@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    ":offscreen": ["@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtbase//:xcb": ["@qtbase//:xcb_qpa_shared", "@qtbase//:x11_shared", "@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    ":xcb": ["@qtbase//:xcb_qpa_shared", "@qtbase//:x11_shared", "@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtbase//:qxcb_glx_integration": ["@qtbase//:xcb_qpa_shared", "@qtbase//:x11_shared", "@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    ":qxcb_glx_integration": ["@qtbase//:xcb_qpa_shared", "@qtbase//:x11_shared", "@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtbase//:qxcb_egl_integration": ["@qtbase//:xcb_qpa_shared", "@qtbase//:x11_shared", "@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    ":qxcb_egl_integration": ["@qtbase//:xcb_qpa_shared", "@qtbase//:x11_shared", "@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtbase//:cocoa": ["@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    ":cocoa": ["@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtbase//:windows": ["@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    ":windows": ["@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtbase//:xml": ["@qtbase//:xml_shared", "@qtbase//:core_shared"],
    ":xml": ["@qtbase//:xml_shared", "@qtbase//:core_shared"],
    "@qtbase//:sql": ["@qtbase//:sql_shared", "@qtbase//:core_shared"],
    ":sql": ["@qtbase//:sql_shared", "@qtbase//:core_shared"],
    "@qtbase//:qsqlite": ["@qtbase//:sql_shared", "@qtbase//:core_shared"],
    ":qsqlite": ["@qtbase//:sql_shared", "@qtbase//:core_shared"],
    "@qtbase//:qsqlodbc": ["@qtbase//:sql_shared", "@qtbase//:core_shared"],
    ":qsqlodbc": ["@qtbase//:sql_shared", "@qtbase//:core_shared"],
    "@qtbase//:sqldriver_plugins": ["@qtbase//:sql_shared", "@qtbase//:core_shared"],
    ":sqldriver_plugins": ["@qtbase//:sql_shared", "@qtbase//:core_shared"],
    "@qtbase//:network": ["@qtbase//:network_shared", "@qtbase//:core_shared"],
    ":network": ["@qtbase//:network_shared", "@qtbase//:core_shared"],
    "@qtbase//:qopensslbackend": ["@qtbase//:network_shared", "@qtbase//:core_shared"],
    ":qopensslbackend": ["@qtbase//:network_shared", "@qtbase//:core_shared"],
    "@qtbase//:qcertonlybackend": ["@qtbase//:network_shared", "@qtbase//:core_shared"],
    ":qcertonlybackend": ["@qtbase//:network_shared", "@qtbase//:core_shared"],
    "@qtbase//:qsecuretransportbackend": ["@qtbase//:network_shared", "@qtbase//:core_shared"],
    ":qsecuretransportbackend": ["@qtbase//:network_shared", "@qtbase//:core_shared"],
    "@qtbase//:qschannelbackend": ["@qtbase//:network_shared", "@qtbase//:core_shared"],
    ":qschannelbackend": ["@qtbase//:network_shared", "@qtbase//:core_shared"],
    "@qtbase//:tls_plugins": ["@qtbase//:network_shared", "@qtbase//:core_shared"],
    ":tls_plugins": ["@qtbase//:network_shared", "@qtbase//:core_shared"],
    "@qtbase//:qglib": ["@qtbase//:network_shared", "@qtbase//:core_shared"],
    ":qglib": ["@qtbase//:network_shared", "@qtbase//:core_shared"],
    "@qtbase//:qnetworkmanager": ["@qtbase//:network_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    ":qnetworkmanager": ["@qtbase//:network_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtbase//:qapplenetworkinformation": ["@qtbase//:network_shared", "@qtbase//:core_shared"],
    ":qapplenetworkinformation": ["@qtbase//:network_shared", "@qtbase//:core_shared"],
    "@qtbase//:qnetworklistmanager": ["@qtbase//:network_shared", "@qtbase//:core_shared"],
    ":qnetworklistmanager": ["@qtbase//:network_shared", "@qtbase//:core_shared"],
    "@qtbase//:networkinformation_plugins": ["@qtbase//:network_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    ":networkinformation_plugins": ["@qtbase//:network_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtbase//:qgif": ["@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    ":qgif": ["@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtbase//:qico": ["@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    ":qico": ["@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtbase//:qjpeg": ["@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    ":qjpeg": ["@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtbase//:imageformats": ["@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    ":imageformats": ["@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtbase//:qmacstyle": ["@qtbase//:widgets_shared", "@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    ":qmacstyle": ["@qtbase//:widgets_shared", "@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtbase//:qmodernwindowsstyle": ["@qtbase//:widgets_shared", "@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    ":qmodernwindowsstyle": ["@qtbase//:widgets_shared", "@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtbase//:style_plugins": ["@qtbase//:widgets_shared", "@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    ":style_plugins": ["@qtbase//:widgets_shared", "@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtbase//:composeplatforminputcontextplugin": ["@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    ":composeplatforminputcontextplugin": ["@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtbase//:ibusplatforminputcontextplugin": ["@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    ":ibusplatforminputcontextplugin": ["@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtbase//:platforminputcontext_plugins": ["@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    ":platforminputcontext_plugins": ["@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtbase//:qxdgdesktopportal": ["@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    ":qxdgdesktopportal": ["@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtbase//:platformtheme_plugins": ["@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    ":platformtheme_plugins": ["@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtbase//:qctf": ["@qtbase//:network_shared", "@qtbase//:core_shared"],
    ":qctf": ["@qtbase//:network_shared", "@qtbase//:core_shared"],
    # --- @qtsvg ---
    "@qtsvg//:svg": ["@qtsvg//:svg_shared", "@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtsvg//:svgwidgets": [
        "@qtsvg//:svgwidgets_shared",
        "@qtsvg//:svg_shared",
        "@qtbase//:widgets_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:core_shared",
    ],
    "@qtsvg//:qsvg": ["@qtsvg//:svg_shared", "@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtsvg//:qsvgicon": ["@qtsvg//:svg_shared", "@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    # --- @qtshadertools ---
    "@qtshadertools//:shadertools": ["@qtshadertools//:shadertools_shared", "@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    # --- @qtimageformats (static plugins; depend only on QtGui) ---
    "@qtimageformats//:imageformats": ["@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtimageformats//:qicns": ["@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtimageformats//:qmacheif": ["@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtimageformats//:qmacjp2": ["@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtimageformats//:qtga": ["@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtimageformats//:qtiff": ["@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtimageformats//:qwbmp": ["@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtimageformats//:qwebp": ["@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    # --- @qtdeclarative ---
    "@qtdeclarative//:qml": _QTQML_BASE_SHARED,
    ":qml": _QTQML_BASE_SHARED,
    "@qtdeclarative//:qmlcompiler": ["@qtdeclarative//:qmlcompiler_shared"] + _QTQML_BASE_SHARED,
    ":qmlcompiler": ["@qtdeclarative//:qmlcompiler_shared"] + _QTQML_BASE_SHARED,
    "@qtdeclarative//:qmldom": ["@qtdeclarative//:qmlcompiler_shared"] + _QTQML_BASE_SHARED,
    ":qmldom": ["@qtdeclarative//:qmlcompiler_shared"] + _QTQML_BASE_SHARED,
    "@qtdeclarative//:qmlformat_lib": ["@qtdeclarative//:qmlcompiler_shared"] + _QTQML_BASE_SHARED,
    ":qmlformat_lib": ["@qtdeclarative//:qmlcompiler_shared"] + _QTQML_BASE_SHARED,
    "@qtdeclarative//:qmlls_lib": ["@qtdeclarative//:qmlcompiler_shared"] + _QTQML_BASE_SHARED,
    ":qmlls_lib": ["@qtdeclarative//:qmlcompiler_shared"] + _QTQML_BASE_SHARED,
    "@qtdeclarative//:qmlmodels": ["@qtdeclarative//:qmlmodels_shared"] + _QTQML_BASE_SHARED,
    "@qtdeclarative//:modelsplugin": ["@qtdeclarative//:qmlmodels_shared"] + _QTQML_BASE_SHARED,
    "@qtdeclarative//:qmlworkerscript": ["@qtdeclarative//:qmlworkerscript_shared"] + _QTQML_BASE_SHARED,
    "@qtdeclarative//:workerscriptplugin": ["@qtdeclarative//:qmlworkerscript_shared"] + _QTQML_BASE_SHARED,
    "@qtdeclarative//:qmlmeta": [
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
    ] + _QTQML_BASE_SHARED,
    "@qtdeclarative//:qmlplugin": [
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
    ] + _QTQML_BASE_SHARED,
    "@qtdeclarative//:qmlcore": ["@qtdeclarative//:qmlcore_shared"] + _QTQML_BASE_SHARED,
    "@qtdeclarative//:qtqmlcoreplugin": ["@qtdeclarative//:qmlcore_shared"] + _QTQML_BASE_SHARED,
    "@qtdeclarative//:qmlnetwork": ["@qtdeclarative//:qmlnetwork_shared"] + _QTQML_BASE_SHARED,
    "@qtdeclarative//:qmlnetworkplugin": ["@qtdeclarative//:qmlnetwork_shared"] + _QTQML_BASE_SHARED,
    "@qtdeclarative//:qmllocalstorage": ["@qtdeclarative//:qmllocalstorage_shared", "@qtbase//:sql_shared"] + _QTQML_BASE_SHARED,
    "@qtdeclarative//:qmllocalstorageplugin": ["@qtdeclarative//:qmllocalstorage_shared", "@qtbase//:sql_shared"] + _QTQML_BASE_SHARED,
    "@qtdeclarative//:qmlxmllistmodel": ["@qtdeclarative//:qmlxmllistmodel_shared", "@qtdeclarative//:qmlmodels_shared"] + _QTQML_BASE_SHARED,
    "@qtdeclarative//:qmlxmllistmodelplugin": ["@qtdeclarative//:qmlxmllistmodel_shared", "@qtdeclarative//:qmlmodels_shared"] + _QTQML_BASE_SHARED,
    "@qtdeclarative//:quick": _QTQUICK_BASE_SHARED,
    ":quick": _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:qtquick2plugin": _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:quickwindow": _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:quicklayouts": ["@qtdeclarative//:quicklayouts_shared"] + _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:qquicklayoutsplugin": ["@qtdeclarative//:quicklayouts_shared"] + _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:quickshapes": ["@qtdeclarative//:quickshapes_shared"] + _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:qmlshapesplugin": ["@qtdeclarative//:quickshapes_shared"] + _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:quickshapesdesignhelpers": ["@qtdeclarative//:quickshapesdesignhelpers_shared", "@qtdeclarative//:quickshapes_shared"] + _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:qtquickshapesdesignhelpersplugin": ["@qtdeclarative//:quickshapesdesignhelpers_shared", "@qtdeclarative//:quickshapes_shared"] + _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:quickshapesdesignhelpersplugin": ["@qtdeclarative//:quickshapesdesignhelpers_shared", "@qtdeclarative//:quickshapes_shared"] + _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:quickparticles": ["@qtdeclarative//:quickparticles_shared"] + _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:particlesplugin": ["@qtdeclarative//:quickparticles_shared"] + _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:quickeffects": ["@qtdeclarative//:quickeffects_shared"] + _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:effectsplugin": ["@qtdeclarative//:quickeffects_shared"] + _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:quickvectorimagegenerator": [
        "@qtdeclarative//:quickvectorimagegenerator_shared",
        "@qtdeclarative//:quickshapes_shared",
        "@qtsvg//:svg_shared",
    ] + _QTQUICK_BASE_SHARED,
    ":quickvectorimagegenerator": [
        "@qtdeclarative//:quickvectorimagegenerator_shared",
        "@qtdeclarative//:quickshapes_shared",
        "@qtsvg//:svg_shared",
    ] + _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:quickvectorimagehelpers": [
        "@qtdeclarative//:quickvectorimagehelpers_shared",
        "@qtdeclarative//:quickvectorimagegenerator_shared",
        "@qtdeclarative//:quickshapes_shared",
        "@qtsvg//:svg_shared",
    ] + _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:qquickvectorimagehelpersplugin": [
        "@qtdeclarative//:quickvectorimagehelpers_shared",
        "@qtdeclarative//:quickvectorimagegenerator_shared",
        "@qtdeclarative//:quickshapes_shared",
        "@qtsvg//:svg_shared",
    ] + _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:quickvectorimagehelpersplugin": [
        "@qtdeclarative//:quickvectorimagehelpers_shared",
        "@qtdeclarative//:quickvectorimagegenerator_shared",
        "@qtdeclarative//:quickshapes_shared",
        "@qtsvg//:svg_shared",
    ] + _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:quickvectorimage": [
        "@qtdeclarative//:quickvectorimage_shared",
        "@qtdeclarative//:quickvectorimagehelpers_shared",
        "@qtdeclarative//:quickvectorimagegenerator_shared",
        "@qtdeclarative//:quickshapes_shared",
        "@qtsvg//:svg_shared",
    ] + _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:qquickvectorimageplugin": [
        "@qtdeclarative//:quickvectorimage_shared",
        "@qtdeclarative//:quickvectorimagehelpers_shared",
        "@qtdeclarative//:quickvectorimagegenerator_shared",
        "@qtdeclarative//:quickshapes_shared",
        "@qtsvg//:svg_shared",
    ] + _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:quickvectorimageplugin": [
        "@qtdeclarative//:quickvectorimage_shared",
        "@qtdeclarative//:quickvectorimagehelpers_shared",
        "@qtdeclarative//:quickvectorimagegenerator_shared",
        "@qtdeclarative//:quickshapes_shared",
        "@qtsvg//:svg_shared",
    ] + _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:quicktemplates2": ["@qtdeclarative//:quicktemplates2_shared"] + _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:qtquicktemplates2plugin": ["@qtdeclarative//:quicktemplates2_shared"] + _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:quickcontrols2impl": [
        "@qtdeclarative//:quickcontrols2impl_shared",
        "@qtdeclarative//:quicktemplates2_shared",
    ] + _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:qtquickcontrols2implplugin": [
        "@qtdeclarative//:quickcontrols2impl_shared",
        "@qtdeclarative//:quicktemplates2_shared",
    ] + _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:quickcontrols2": _QTQUICKCONTROLS2_BASE_SHARED,
    "@qtdeclarative//:qtquickcontrols2plugin": [
        "@qtdeclarative//:quickcontrols2fusion_shared",
        "@qtdeclarative//:quickcontrols2fusionstyleimpl_shared",
        "@qtdeclarative//:quickcontrols2basic_shared",
        "@qtdeclarative//:quickcontrols2basicstyleimpl_shared",
    ] + _QTQUICKCONTROLS2_BASE_SHARED,
    "@qtdeclarative//:quickcontrols2basicstyleimpl": [
        "@qtdeclarative//:quickcontrols2basicstyleimpl_shared",
    ] + _QTQUICKCONTROLS2_BASE_SHARED,
    "@qtdeclarative//:qtquickcontrols2basicstyleimplplugin": [
        "@qtdeclarative//:quickcontrols2basicstyleimpl_shared",
    ] + _QTQUICKCONTROLS2_BASE_SHARED,
    "@qtdeclarative//:quickcontrols2basic": [
        "@qtdeclarative//:quickcontrols2basic_shared",
        "@qtdeclarative//:quickcontrols2basicstyleimpl_shared",
    ] + _QTQUICKCONTROLS2_BASE_SHARED,
    "@qtdeclarative//:qtquickcontrols2basicstyleplugin": [
        "@qtdeclarative//:quickcontrols2basic_shared",
        "@qtdeclarative//:quickcontrols2basicstyleimpl_shared",
    ] + _QTQUICKCONTROLS2_BASE_SHARED,
    "@qtdeclarative//:quickcontrols2fusionstyleimpl": [
        "@qtdeclarative//:quickcontrols2fusionstyleimpl_shared",
    ] + _QTQUICKCONTROLS2_BASE_SHARED,
    "@qtdeclarative//:qtquickcontrols2fusionstyleimplplugin": [
        "@qtdeclarative//:quickcontrols2fusionstyleimpl_shared",
    ] + _QTQUICKCONTROLS2_BASE_SHARED,
    "@qtdeclarative//:quickcontrols2fusion": [
        "@qtdeclarative//:quickcontrols2fusion_shared",
        "@qtdeclarative//:quickcontrols2fusionstyleimpl_shared",
        "@qtdeclarative//:quickcontrols2basic_shared",
        "@qtdeclarative//:quickcontrols2basicstyleimpl_shared",
    ] + _QTQUICKCONTROLS2_BASE_SHARED,
    "@qtdeclarative//:qtquickcontrols2fusionstyleplugin": [
        "@qtdeclarative//:quickcontrols2fusion_shared",
        "@qtdeclarative//:quickcontrols2fusionstyleimpl_shared",
        "@qtdeclarative//:quickcontrols2basic_shared",
        "@qtdeclarative//:quickcontrols2basicstyleimpl_shared",
    ] + _QTQUICKCONTROLS2_BASE_SHARED,
    "@qtdeclarative//:quickcontrols2materialstyleimpl": [
        "@qtdeclarative//:quickcontrols2materialstyleimpl_shared",
    ] + _QTQUICKCONTROLS2_BASE_SHARED,
    "@qtdeclarative//:qtquickcontrols2materialstyleimplplugin": [
        "@qtdeclarative//:quickcontrols2materialstyleimpl_shared",
    ] + _QTQUICKCONTROLS2_BASE_SHARED,
    "@qtdeclarative//:quickcontrols2material": [
        "@qtdeclarative//:quickcontrols2material_shared",
        "@qtdeclarative//:quickcontrols2materialstyleimpl_shared",
        "@qtdeclarative//:quickcontrols2basic_shared",
        "@qtdeclarative//:quickcontrols2basicstyleimpl_shared",
    ] + _QTQUICKCONTROLS2_BASE_SHARED,
    "@qtdeclarative//:qtquickcontrols2materialstyleplugin": [
        "@qtdeclarative//:quickcontrols2material_shared",
        "@qtdeclarative//:quickcontrols2materialstyleimpl_shared",
        "@qtdeclarative//:quickcontrols2basic_shared",
        "@qtdeclarative//:quickcontrols2basicstyleimpl_shared",
    ] + _QTQUICKCONTROLS2_BASE_SHARED,
    "@qtdeclarative//:quickcontrols2universalstyleimpl": [
        "@qtdeclarative//:quickcontrols2universalstyleimpl_shared",
    ] + _QTQUICKCONTROLS2_BASE_SHARED,
    "@qtdeclarative//:qtquickcontrols2universalstyleimplplugin": [
        "@qtdeclarative//:quickcontrols2universalstyleimpl_shared",
    ] + _QTQUICKCONTROLS2_BASE_SHARED,
    "@qtdeclarative//:quickcontrols2universal": [
        "@qtdeclarative//:quickcontrols2universal_shared",
        "@qtdeclarative//:quickcontrols2universalstyleimpl_shared",
        "@qtdeclarative//:quickcontrols2basic_shared",
        "@qtdeclarative//:quickcontrols2basicstyleimpl_shared",
    ] + _QTQUICKCONTROLS2_BASE_SHARED,
    "@qtdeclarative//:qtquickcontrols2universalstyleplugin": [
        "@qtdeclarative//:quickcontrols2universal_shared",
        "@qtdeclarative//:quickcontrols2universalstyleimpl_shared",
        "@qtdeclarative//:quickcontrols2basic_shared",
        "@qtdeclarative//:quickcontrols2basicstyleimpl_shared",
    ] + _QTQUICKCONTROLS2_BASE_SHARED,
    "@qtdeclarative//:quickcontrols2imaginestyleimpl": _QTQUICKCONTROLS2_BASE_SHARED,
    "@qtdeclarative//:qtquickcontrols2imaginestyleimplplugin": _QTQUICKCONTROLS2_BASE_SHARED,
    "@qtdeclarative//:quickcontrols2imagine": [
        "@qtdeclarative//:quickcontrols2imagine_shared",
        "@qtdeclarative//:quickcontrols2basic_shared",
        "@qtdeclarative//:quickcontrols2basicstyleimpl_shared",
    ] + _QTQUICKCONTROLS2_BASE_SHARED,
    "@qtdeclarative//:qtquickcontrols2imaginestyleplugin": [
        "@qtdeclarative//:quickcontrols2imagine_shared",
        "@qtdeclarative//:quickcontrols2basic_shared",
        "@qtdeclarative//:quickcontrols2basicstyleimpl_shared",
    ] + _QTQUICKCONTROLS2_BASE_SHARED,
    "@qtdeclarative//:quickcontrols2fluentwinui3styleimpl": [
        "@qtdeclarative//:quickcontrols2fluentwinui3styleimpl_shared",
    ] + _QTQUICKCONTROLS2_BASE_SHARED,
    "@qtdeclarative//:qtquickcontrols2fluentwinui3styleimplplugin": [
        "@qtdeclarative//:quickcontrols2fluentwinui3styleimpl_shared",
    ] + _QTQUICKCONTROLS2_BASE_SHARED,
    "@qtdeclarative//:quickcontrols2fluentwinui3": [
        "@qtdeclarative//:quickcontrols2fluentwinui3styleimpl_shared",
        "@qtdeclarative//:quickcontrols2fusion_shared",
        "@qtdeclarative//:quickcontrols2fusionstyleimpl_shared",
        "@qtdeclarative//:quickcontrols2basic_shared",
        "@qtdeclarative//:quickcontrols2basicstyleimpl_shared",
    ] + _QTQUICKCONTROLS2_BASE_SHARED,
    "@qtdeclarative//:qtquickcontrols2fluentwinui3styleplugin": [
        "@qtdeclarative//:quickcontrols2fluentwinui3styleimpl_shared",
        "@qtdeclarative//:quickcontrols2fusion_shared",
        "@qtdeclarative//:quickcontrols2fusionstyleimpl_shared",
        "@qtdeclarative//:quickcontrols2basic_shared",
        "@qtdeclarative//:quickcontrols2basicstyleimpl_shared",
    ] + _QTQUICKCONTROLS2_BASE_SHARED,
    "@qtdeclarative//:quicknativestyle": [
        "@qtdeclarative//:quicklayouts_shared",
    ] + _QTQUICKCONTROLS2_BASE_SHARED,
    "@qtdeclarative//:qtquickcontrols2nativestyleplugin": [
        "@qtdeclarative//:quicklayouts_shared",
    ] + _QTQUICKCONTROLS2_BASE_SHARED,
    "@qtdeclarative//:quickcontrols2macosstyleimpl": _QTQUICKCONTROLS2_BASE_SHARED,
    "@qtdeclarative//:qtquickcontrols2macosstyleimplplugin": _QTQUICKCONTROLS2_BASE_SHARED,
    "@qtdeclarative//:quickcontrols2macos": [
        "@qtdeclarative//:quicklayouts_shared",
        "@qtdeclarative//:quickcontrols2fusion_shared",
        "@qtdeclarative//:quickcontrols2fusionstyleimpl_shared",
        "@qtdeclarative//:quickcontrols2basic_shared",
        "@qtdeclarative//:quickcontrols2basicstyleimpl_shared",
    ] + _QTQUICKCONTROLS2_BASE_SHARED,
    "@qtdeclarative//:qtquickcontrols2macosstyleplugin": [
        "@qtdeclarative//:quicklayouts_shared",
        "@qtdeclarative//:quickcontrols2fusion_shared",
        "@qtdeclarative//:quickcontrols2fusionstyleimpl_shared",
        "@qtdeclarative//:quickcontrols2basic_shared",
        "@qtdeclarative//:quickcontrols2basicstyleimpl_shared",
    ] + _QTQUICKCONTROLS2_BASE_SHARED,
    "@qtdeclarative//:quickcontrols2iosstyleimpl": _QTQUICKCONTROLS2_BASE_SHARED,
    "@qtdeclarative//:qtquickcontrols2iosstyleimplplugin": _QTQUICKCONTROLS2_BASE_SHARED,
    "@qtdeclarative//:quickcontrols2ios": [
        "@qtdeclarative//:quickcontrols2basic_shared",
        "@qtdeclarative//:quickcontrols2basicstyleimpl_shared",
    ] + _QTQUICKCONTROLS2_BASE_SHARED,
    "@qtdeclarative//:qtquickcontrols2iosstyleplugin": [
        "@qtdeclarative//:quickcontrols2basic_shared",
        "@qtdeclarative//:quickcontrols2basicstyleimpl_shared",
    ] + _QTQUICKCONTROLS2_BASE_SHARED,
    "@qtdeclarative//:quickcontrols2windowsstyleimpl": _QTQUICKCONTROLS2_BASE_SHARED,
    "@qtdeclarative//:qtquickcontrols2windowsstyleimplplugin": _QTQUICKCONTROLS2_BASE_SHARED,
    "@qtdeclarative//:quickcontrols2windows": [
        "@qtdeclarative//:quicklayouts_shared",
        "@qtdeclarative//:quickcontrols2fusion_shared",
        "@qtdeclarative//:quickcontrols2fusionstyleimpl_shared",
        "@qtdeclarative//:quickcontrols2basic_shared",
        "@qtdeclarative//:quickcontrols2basicstyleimpl_shared",
    ] + _QTQUICKCONTROLS2_BASE_SHARED,
    "@qtdeclarative//:qtquickcontrols2windowsstyleplugin": [
        "@qtdeclarative//:quicklayouts_shared",
        "@qtdeclarative//:quickcontrols2fusion_shared",
        "@qtdeclarative//:quickcontrols2fusionstyleimpl_shared",
        "@qtdeclarative//:quickcontrols2basic_shared",
        "@qtdeclarative//:quickcontrols2basicstyleimpl_shared",
    ] + _QTQUICKCONTROLS2_BASE_SHARED,
    "@qtdeclarative//:quickdialogs2utils": [
        "@qtdeclarative//:quickdialogs2utils_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:core_shared",
    ],
    "@qtdeclarative//:quickdialogs2quickimpl": [
        "@qtdeclarative//:quickdialogs2quickimpl_shared",
        "@qtdeclarative//:quickdialogs2utils_shared",
        "@qtdeclarative//:labsfoldermodel_shared",
        "@qtdeclarative//:quicklayouts_shared",
        "@qtdeclarative//:quickcontrols2impl_shared",
        "@qtdeclarative//:quicktemplates2_shared",
    ] + _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:qtquickdialogs2quickimplplugin": [
        "@qtdeclarative//:quickdialogs2quickimpl_shared",
        "@qtdeclarative//:quickdialogs2utils_shared",
        "@qtdeclarative//:labsfoldermodel_shared",
        "@qtdeclarative//:quicklayouts_shared",
        "@qtdeclarative//:quickcontrols2impl_shared",
        "@qtdeclarative//:quicktemplates2_shared",
    ] + _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:quickdialogs2": [
        "@qtdeclarative//:quickdialogs2_shared",
        "@qtdeclarative//:quickdialogs2quickimpl_shared",
        "@qtdeclarative//:quickdialogs2utils_shared",
        "@qtdeclarative//:labsfoldermodel_shared",
        "@qtdeclarative//:quicklayouts_shared",
        "@qtdeclarative//:quickcontrols2impl_shared",
        "@qtdeclarative//:quicktemplates2_shared",
    ] + _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:qtquickdialogsplugin": [
        "@qtdeclarative//:quickdialogs2_shared",
        "@qtdeclarative//:quickdialogs2quickimpl_shared",
        "@qtdeclarative//:quickdialogs2utils_shared",
        "@qtdeclarative//:labsfoldermodel_shared",
        "@qtdeclarative//:quicklayouts_shared",
        "@qtdeclarative//:quickcontrols2impl_shared",
        "@qtdeclarative//:quicktemplates2_shared",
    ] + _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:labsanimation": ["@qtdeclarative//:labsanimation_shared"] + _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:labsanimationplugin": ["@qtdeclarative//:labsanimation_shared"] + _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:labssettings": ["@qtdeclarative//:labssettings_shared"] + _QTQML_BASE_SHARED,
    "@qtdeclarative//:qmlsettingsplugin": ["@qtdeclarative//:labssettings_shared"] + _QTQML_BASE_SHARED,
    "@qtdeclarative//:labsmodels": ["@qtdeclarative//:labsmodels_shared", "@qtdeclarative//:qmlmodels_shared"] + _QTQML_BASE_SHARED,
    "@qtdeclarative//:labsmodelsplugin": ["@qtdeclarative//:labsmodels_shared", "@qtdeclarative//:qmlmodels_shared"] + _QTQML_BASE_SHARED,
    "@qtdeclarative//:labsfoldermodel": ["@qtdeclarative//:labsfoldermodel_shared", "@qtdeclarative//:qmlmodels_shared"] + _QTQML_BASE_SHARED,
    "@qtdeclarative//:qmlfolderlistmodelplugin": ["@qtdeclarative//:labsfoldermodel_shared", "@qtdeclarative//:qmlmodels_shared"] + _QTQML_BASE_SHARED,
    "@qtdeclarative//:labsplatform": [
        "@qtdeclarative//:labsplatform_shared",
        "@qtdeclarative//:quicktemplates2_shared",
        "@qtbase//:widgets_shared",
    ] + _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:qtlabsplatformplugin": [
        "@qtdeclarative//:labsplatform_shared",
        "@qtdeclarative//:quicktemplates2_shared",
        "@qtbase//:widgets_shared",
    ] + _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:labswavefrontmesh": ["@qtdeclarative//:labswavefrontmesh_shared"] + _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:qmlwavefrontmeshplugin": ["@qtdeclarative//:labswavefrontmesh_shared"] + _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:labssharedimage": ["@qtdeclarative//:labssharedimage_shared"] + _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:sharedimageplugin": ["@qtdeclarative//:labssharedimage_shared"] + _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:qtlabssharedimageplugin": ["@qtdeclarative//:labssharedimage_shared"] + _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:labssynchronizer": ["@qtdeclarative//:labssynchronizer_shared"] + _QTQML_BASE_SHARED,
    "@qtdeclarative//:labssynchronizerplugin": ["@qtdeclarative//:labssynchronizer_shared"] + _QTQML_BASE_SHARED,
    "@qtdeclarative//:quickwidgets": [
        "@qtdeclarative//:quickwidgets_shared",
        "@qtbase//:widgets_shared",
    ] + _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:quicktest": [
        "@qtdeclarative//:quicktest_shared",
        "@qtbase//:test_shared",
    ] + _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:quicktestplugin": [
        "@qtdeclarative//:quicktest_shared",
        "@qtbase//:test_shared",
    ] + _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:packetprotocol": ["@qtbase//:core_shared"],
    "@qtdeclarative//:qmldebug": _QTQML_BASE_SHARED,
    "@qtdeclarative//:qmldbg_debugger": _QTQML_BASE_SHARED,
    "@qtdeclarative//:qmldbg_inspector": _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:qmldbg_local": _QTQML_BASE_SHARED,
    "@qtdeclarative//:qmldbg_messages": _QTQML_BASE_SHARED,
    "@qtdeclarative//:qmldbg_native": _QTQML_BASE_SHARED,
    "@qtdeclarative//:qmldbg_nativedebugger": _QTQML_BASE_SHARED,
    "@qtdeclarative//:qmldbg_preview": _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:qmldbg_profiler": _QTQML_BASE_SHARED,
    "@qtdeclarative//:qmldbg_quickprofiler": _QTQUICK_BASE_SHARED,
    "@qtdeclarative//:qmldbg_server": _QTQML_BASE_SHARED,
    "@qtdeclarative//:qmldbg_tcp": _QTQML_BASE_SHARED,
    # --- Phase 2 Milestone 3 modules ---
    "@qtwebsockets//:websockets": ["@qtwebsockets//:websockets_shared", "@qtbase//:network_shared", "@qtbase//:core_shared"],
    "@qtwebchannel//:webchannel": ["@qtwebchannel//:webchannel_shared", "@qtdeclarative//:qml_shared", "@qtbase//:network_shared", "@qtbase//:core_shared"],
    "@qtwebchannel//:webchannelquick": ["@qtwebchannel//:webchannelquick_shared", "@qtwebchannel//:webchannel_shared", "@qtdeclarative//:qml_shared", "@qtbase//:network_shared", "@qtbase//:core_shared"],
    "@qtwebchannel//:webchannelquickplugin": ["@qtwebchannel//:webchannelquick_shared", "@qtwebchannel//:webchannel_shared", "@qtdeclarative//:qml_shared", "@qtbase//:network_shared", "@qtbase//:core_shared"],
    "@qthttpserver//:httpserver": ["@qthttpserver//:httpserver_shared", "@qtwebsockets//:websockets_shared", "@qtbase//:network_shared", "@qtbase//:concurrent_shared", "@qtbase//:core_shared"],
    "@qtnetworkauth//:networkauth": ["@qtnetworkauth//:networkauth_shared", "@qtbase//:network_shared", "@qtbase//:core_shared"],
    "@qtserialport//:serialport": ["@qtserialport//:serialport_shared", "@qtbase//:core_shared"],
    "@qtserialbus//:serialbus": ["@qtserialbus//:serialbus_shared", "@qtserialport//:serialport_shared", "@qtbase//:network_shared", "@qtbase//:core_shared"],
    ":serialbus": ["@qtserialbus//:serialbus_shared", "@qtserialport//:serialport_shared", "@qtbase//:network_shared", "@qtbase//:core_shared"],
    "@qtserialbus//:qtpassthrucanbus": ["@qtserialbus//:serialbus_shared", "@qtserialport//:serialport_shared", "@qtbase//:network_shared", "@qtbase//:core_shared"],
    ":qtpassthrucanbus": ["@qtserialbus//:serialbus_shared", "@qtserialport//:serialport_shared", "@qtbase//:network_shared", "@qtbase//:core_shared"],
    "@qtserialbus//:qtpeakcanbus": ["@qtserialbus//:serialbus_shared", "@qtserialport//:serialport_shared", "@qtbase//:network_shared", "@qtbase//:core_shared"],
    ":qtpeakcanbus": ["@qtserialbus//:serialbus_shared", "@qtserialport//:serialport_shared", "@qtbase//:network_shared", "@qtbase//:core_shared"],
    "@qtserialbus//:qtsocketcanbus": ["@qtserialbus//:serialbus_shared", "@qtserialport//:serialport_shared", "@qtbase//:network_shared", "@qtbase//:core_shared"],
    ":qtsocketcanbus": ["@qtserialbus//:serialbus_shared", "@qtserialport//:serialport_shared", "@qtbase//:network_shared", "@qtbase//:core_shared"],
    "@qtserialbus//:qtsysteccanbus": ["@qtserialbus//:serialbus_shared", "@qtserialport//:serialport_shared", "@qtbase//:network_shared", "@qtbase//:core_shared"],
    ":qtsysteccanbus": ["@qtserialbus//:serialbus_shared", "@qtserialport//:serialport_shared", "@qtbase//:network_shared", "@qtbase//:core_shared"],
    "@qtserialbus//:qttinycanbus": ["@qtserialbus//:serialbus_shared", "@qtserialport//:serialport_shared", "@qtbase//:network_shared", "@qtbase//:core_shared"],
    ":qttinycanbus": ["@qtserialbus//:serialbus_shared", "@qtserialport//:serialport_shared", "@qtbase//:network_shared", "@qtbase//:core_shared"],
    "@qtserialbus//:qtvectorcanbus": ["@qtserialbus//:serialbus_shared", "@qtserialport//:serialport_shared", "@qtbase//:network_shared", "@qtbase//:core_shared"],
    ":qtvectorcanbus": ["@qtserialbus//:serialbus_shared", "@qtserialport//:serialport_shared", "@qtbase//:network_shared", "@qtbase//:core_shared"],
    "@qtserialbus//:qtvirtualcanbus": ["@qtserialbus//:serialbus_shared", "@qtserialport//:serialport_shared", "@qtbase//:network_shared", "@qtbase//:core_shared"],
    ":qtvirtualcanbus": ["@qtserialbus//:serialbus_shared", "@qtserialport//:serialport_shared", "@qtbase//:network_shared", "@qtbase//:core_shared"],
    "@qtserialbus//:canbus_plugins": ["@qtserialbus//:serialbus_shared", "@qtserialport//:serialport_shared", "@qtbase//:network_shared", "@qtbase//:core_shared"],
    "@qtsensors//:sensors": ["@qtsensors//:sensors_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtsensors//:qtsensors_dummy": ["@qtsensors//:sensors_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtsensors//:qtsensors_generic": ["@qtsensors//:sensors_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtsensors//:sensorsquick": ["@qtsensors//:sensorsquick_shared", "@qtsensors//:sensors_shared", "@qtdeclarative//:qml_shared", "@qtbase//:dbus_shared", "@qtbase//:network_shared", "@qtbase//:core_shared"],
    "@qtsensors//:sensorsquickplugin": ["@qtsensors//:sensorsquick_shared", "@qtsensors//:sensors_shared", "@qtdeclarative//:qml_shared", "@qtbase//:dbus_shared", "@qtbase//:network_shared", "@qtbase//:core_shared"],
    "@qtsensors//:qtsensors_iio_sensor_proxy": ["@qtsensors//:sensors_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtsensors//:qtsensors_linuxsys": ["@qtsensors//:sensors_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtsensors//:sensors_plugins": ["@qtsensors//:sensors_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qt5compat//:core5compat": ["@qt5compat//:core5compat_shared", "@qtbase//:core_shared"],
    "@qtcharts//:charts": [
        "@qtcharts//:charts_shared",
        "@qtbase//:openglwidgets_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:widgets_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:core_shared",
    ],
    "@qtcharts//:chartsqml": [
        "@qtcharts//:chartsqml_shared",
        "@qtcharts//:charts_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:openglwidgets_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:widgets_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtcharts//:qtchartsqml2": [
        "@qtcharts//:chartsqml_shared",
        "@qtcharts//:charts_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:openglwidgets_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:widgets_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtpositioning//:positioning": ["@qtpositioning//:positioning_shared", "@qtbase//:core_shared"],
    "@qtpositioning//:positioningquick": [
        "@qtpositioning//:positioningquick_shared",
        "@qtpositioning//:positioning_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtpositioning//:positioningquickplugin": [
        "@qtpositioning//:positioningquick_shared",
        "@qtpositioning//:positioning_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtpositioning//:qtposition_positionpoll": ["@qtpositioning//:positioning_shared", "@qtbase//:core_shared"],
    "@qtpositioning//:qtposition_nmea": ["@qtpositioning//:positioning_shared", "@qtserialport//:serialport_shared", "@qtbase//:network_shared", "@qtbase//:core_shared"],
    "@qtpositioning//:qtposition_geoclue2": ["@qtpositioning//:positioning_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtpositioning//:qtposition_cl": ["@qtpositioning//:positioning_shared", "@qtbase//:core_shared"],
    "@qtpositioning//:position_plugins": ["@qtpositioning//:positioning_shared", "@qtserialport//:serialport_shared", "@qtbase//:dbus_shared", "@qtbase//:network_shared", "@qtbase//:core_shared"],
    "@qtlocation//:location": [
        "@qtlocation//:location_shared",
        "@qtpositioning//:positioningquick_shared",
        "@qtpositioning//:positioning_shared",
        "@qtdeclarative//:quickshapes_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtlocation//:declarative_location": [
        "@qtlocation//:location_shared",
        "@qtpositioning//:positioningquick_shared",
        "@qtpositioning//:positioning_shared",
        "@qtdeclarative//:quickshapes_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtlocation//:qtgeoservices_itemsoverlay": [
        "@qtlocation//:location_shared",
        "@qtpositioning//:positioningquick_shared",
        "@qtpositioning//:positioning_shared",
        "@qtdeclarative//:quickshapes_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtlocation//:qtgeoservices_osm": [
        "@qtlocation//:location_shared",
        "@qtpositioning//:positioningquick_shared",
        "@qtpositioning//:positioning_shared",
        "@qtdeclarative//:quickshapes_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    "@qtlocation//:qtgeoservices_nokia": [
        "@qtlocation//:location_shared",
        "@qtpositioning//:positioningquick_shared",
        "@qtpositioning//:positioning_shared",
        "@qtdeclarative//:quickshapes_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtlocation//:geoservices_plugins": [
        "@qtlocation//:location_shared",
        "@qtpositioning//:positioningquick_shared",
        "@qtpositioning//:positioning_shared",
        "@qtdeclarative//:quickshapes_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    "@qtconnectivity//:bluetooth": ["@qtconnectivity//:bluetooth_shared", "@qtbase//:network_shared", "@qtbase//:core_shared"],
    "@qtconnectivity//:nfc": ["@qtconnectivity//:nfc_shared", "@qtbase//:core_shared"],
    "@qtlottie//:lottievectorimagehelpers": [
        "@qtlottie//:lottievectorimagehelpers_shared",
    ] + _QTQUICK_BASE_SHARED,
    "@qtlottie//:lottievectorimagehelpersplugin": [
        "@qtlottie//:lottievectorimagehelpers_shared",
    ] + _QTQUICK_BASE_SHARED,
    "@qtlottie//:lottie": [
        "@qtlottie//:lottie_shared",
    ] + _QTQUICK_BASE_SHARED,
    "@qtlottie//:lottieqtplugin": [
        "@qtlottie//:lottie_shared",
    ] + _QTQUICK_BASE_SHARED,
    "@qtlottie//:lottievectorimagegenerator": [
        "@qtlottie//:lottievectorimagegenerator_shared",
        "@qtlottie//:lottievectorimagehelpers_shared",
        "@qtlottie//:lottie_shared",
        "@qtdeclarative//:quickvectorimagegenerator_shared",
        "@qtdeclarative//:quickshapes_shared",
        "@qtsvg//:svg_shared",
    ] + _QTQUICK_BASE_SHARED,
    ":lottievectorimagegenerator": [
        "@qtlottie//:lottievectorimagegenerator_shared",
        "@qtlottie//:lottievectorimagehelpers_shared",
        "@qtlottie//:lottie_shared",
        "@qtdeclarative//:quickvectorimagegenerator_shared",
        "@qtdeclarative//:quickshapes_shared",
        "@qtsvg//:svg_shared",
    ] + _QTQUICK_BASE_SHARED,
    "@qtlottie//:qlottievectorimage": [
        "@qtlottie//:lottievectorimagegenerator_shared",
        "@qtlottie//:lottievectorimagehelpers_shared",
        "@qtlottie//:lottie_shared",
        "@qtdeclarative//:quickvectorimagegenerator_shared",
        "@qtdeclarative//:quickshapes_shared",
        "@qtsvg//:svg_shared",
    ] + _QTQUICK_BASE_SHARED,
    "@qtquicktimeline//:quicktimeline": [
        "@qtquicktimeline//:quicktimeline_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtquicktimeline//:qtquicktimelineplugin": [
        "@qtquicktimeline//:quicktimeline_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtquicktimeline//:quicktimelineblendtrees": [
        "@qtquicktimeline//:quicktimelineblendtrees_shared",
        "@qtquicktimeline//:quicktimeline_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtquicktimeline//:qtquicktimelineblendtreesplugin": [
        "@qtquicktimeline//:quicktimelineblendtrees_shared",
        "@qtquicktimeline//:quicktimeline_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtvirtualkeyboard//:virtualkeyboard": [
        "@qtvirtualkeyboard//:virtualkeyboard_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtremoteobjects//:remoteobjects": ["@qtremoteobjects//:remoteobjects_shared", "@qtbase//:network_shared", "@qtbase//:core_shared"],
    "@qtremoteobjects//:remoteobjectsqml": [
        "@qtremoteobjects//:remoteobjectsqml_shared",
        "@qtremoteobjects//:remoteobjects_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtremoteobjects//:declarative_remoteobjects": [
        "@qtremoteobjects//:remoteobjectsqml_shared",
        "@qtremoteobjects//:remoteobjects_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtscxml//:scxml": ["@qtscxml//:scxml_shared", "@qtbase//:core_shared"],
    "@qtscxml//:scxmlqml": [
        "@qtscxml//:scxmlqml_shared",
        "@qtscxml//:scxml_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtscxml//:declarative_scxml": [
        "@qtscxml//:scxmlqml_shared",
        "@qtscxml//:scxml_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtscxml//:statemachine": ["@qtscxml//:statemachine_shared", "@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtscxml//:statemachineqml": [
        "@qtscxml//:statemachineqml_shared",
        "@qtscxml//:statemachine_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtscxml//:qtqmlstatemachine": [
        "@qtscxml//:statemachineqml_shared",
        "@qtscxml//:statemachine_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    # --- Phase 2 Milestone 4 modules ---
    "@qtquick3d//:glslparser": ["@qtquick3d//:glslparser_shared", "@qtbase//:core_shared"],
    ":glslparser": ["@qtquick3d//:glslparser_shared", "@qtbase//:core_shared"],
    "@qtquick3d//:utils": [
        "@qtquick3d//:utils_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    ":utils": [
        "@qtquick3d//:utils_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtquick3d//:assetimport": [
        "@qtquick3d//:assetimport_shared",
        "@qtquick3d//:utils_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    ":assetimport": [
        "@qtquick3d//:assetimport_shared",
        "@qtquick3d//:utils_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtquick3d//:runtimerender": [
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    ":runtimerender": [
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    "@qtquick3d//:quick3d": [
        "@qtquick3d//:quick3d_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    ":quick3d": [
        "@qtquick3d//:quick3d_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    "@qtquick3d//:qquick3dplugin": [
        "@qtquick3d//:quick3d_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    ":qquick3dplugin": [
        "@qtquick3d//:quick3d_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    "@qtquick3d//:assetutils_lib": [
        "@qtquick3d//:assetutils_shared",
        "@qtquick3d//:quick3d_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:assetimport_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtquicktimeline//:quicktimeline_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    ":assetutils_lib": [
        "@qtquick3d//:assetutils_shared",
        "@qtquick3d//:quick3d_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:assetimport_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtquicktimeline//:quicktimeline_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    "@qtquick3d//:assetutils": [
        "@qtquick3d//:assetutils_shared",
        "@qtquick3d//:quick3d_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:assetimport_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtquicktimeline//:quicktimeline_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    ":assetutils": [
        "@qtquick3d//:assetutils_shared",
        "@qtquick3d//:quick3d_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:assetimport_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtquicktimeline//:quicktimeline_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    "@qtquick3d//:qtquick3dassetutilsplugin": [
        "@qtquick3d//:assetutils_shared",
        "@qtquick3d//:quick3d_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:assetimport_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtquicktimeline//:quicktimeline_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    ":qtquick3dassetutilsplugin": [
        "@qtquick3d//:assetutils_shared",
        "@qtquick3d//:quick3d_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:assetimport_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtquicktimeline//:quicktimeline_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    "@qtquick3d//:assimpimporterplugin": [
        "@qtquick3d//:quick3d_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:assetimport_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    ":assimpimporterplugin": [
        "@qtquick3d//:quick3d_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:assetimport_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    "@qtquick3d//:quick3dparticles": [
        "@qtquick3d//:quick3dparticles_shared",
        "@qtquick3d//:quick3d_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    ":quick3dparticles": [
        "@qtquick3d//:quick3dparticles_shared",
        "@qtquick3d//:quick3d_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    "@qtquick3d//:qtquick3dparticles3dplugin": [
        "@qtquick3d//:quick3dparticles_shared",
        "@qtquick3d//:quick3d_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    ":qtquick3dparticles3dplugin": [
        "@qtquick3d//:quick3dparticles_shared",
        "@qtquick3d//:quick3d_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    "@qtquick3d//:quick3dhelpersimpl": [
        "@qtquick3d//:quick3dhelpersimpl_shared",
        "@qtquick3d//:quick3d_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    ":quick3dhelpersimpl": [
        "@qtquick3d//:quick3dhelpersimpl_shared",
        "@qtquick3d//:quick3d_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    "@qtquick3d//:qtquick3dhelpersimplplugin": [
        "@qtquick3d//:quick3dhelpersimpl_shared",
        "@qtquick3d//:quick3d_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    ":qtquick3dhelpersimplplugin": [
        "@qtquick3d//:quick3dhelpersimpl_shared",
        "@qtquick3d//:quick3d_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    "@qtquick3d//:quick3dhelpers": [
        "@qtquick3d//:quick3dhelpers_shared",
        "@qtquick3d//:quick3d_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    ":quick3dhelpers": [
        "@qtquick3d//:quick3dhelpers_shared",
        "@qtquick3d//:quick3d_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    "@qtquick3d//:qtquick3dhelpersplugin": [
        "@qtquick3d//:quick3dhelpers_shared",
        "@qtquick3d//:quick3d_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    ":qtquick3dhelpersplugin": [
        "@qtquick3d//:quick3dhelpers_shared",
        "@qtquick3d//:quick3d_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    "@qtquick3d//:quick3deffects": [
        "@qtquick3d//:quick3d_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    ":quick3deffects": [
        "@qtquick3d//:quick3d_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    "@qtquick3d//:qtquick3deffectplugin": [
        "@qtquick3d//:quick3d_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    ":qtquick3deffectplugin": [
        "@qtquick3d//:quick3d_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    "@qtquick3d//:iblbaker": [
        "@qtquick3d//:iblbaker_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    ":iblbaker": [
        "@qtquick3d//:iblbaker_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    "@qtquick3d//:quick3dxr": [
        "@qtquick3d//:quick3dxr_shared",
        "@qtquick3d//:quick3d_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    ":quick3dxr": [
        "@qtquick3d//:quick3dxr_shared",
        "@qtquick3d//:quick3d_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    "@qtquick3d//:quick3dxrplugin": [
        "@qtquick3d//:quick3dxr_shared",
        "@qtquick3d//:quick3d_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    ":quick3dxrplugin": [
        "@qtquick3d//:quick3dxr_shared",
        "@qtquick3d//:quick3d_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    "@qtquick3d//:qmldbg_quick3dprofiler": [
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    ":qmldbg_quick3dprofiler": [
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    "@qtquick3dphysics//:quick3dphysics": [
        "@qtquick3dphysics//:quick3dphysics_shared",
        "@qtquick3d//:quick3d_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    "@qtquick3dphysics//:qquick3dphysicsplugin": [
        "@qtquick3dphysics//:quick3dphysics_shared",
        "@qtquick3d//:quick3d_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    "@qtquick3dphysics//:quick3dphysicshelpers": [
        "@qtquick3dphysics//:quick3dphysicshelpers_shared",
        "@qtquick3dphysics//:quick3dphysics_shared",
        "@qtquick3d//:quick3d_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    "@qtgraphs//:graphs": [
        "@qtgraphs//:graphs_shared",
        "@qtquick3d//:quick3d_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quickshapes_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    "@qtgraphs//:graphswidgets": [
        "@qtgraphs//:graphswidgets_shared",
        "@qtgraphs//:graphs_shared",
        "@qtquick3d//:quick3d_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quickwidgets_shared",
        "@qtdeclarative//:quickshapes_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:widgets_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    "@qtdatavis3d//:datavisualization": [
        "@qtdatavis3d//:datavisualization_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:core_shared",
    ],
    "@qtdatavis3d//:datavisualizationqml": [
        "@qtdatavis3d//:datavisualizationqml_shared",
        "@qtdatavis3d//:datavisualization_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtdatavis3d//:datavisualizationqmlplugin": [
        "@qtdatavis3d//:datavisualizationqml_shared",
        "@qtdatavis3d//:datavisualization_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qt3d//:3dcore": [
        "@qt3d//:3dcore_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    "@qt3d//:3drender": [
        "@qt3d//:3drender_shared",
        "@qt3d//:3dcore_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    "@qt3d//:3dinput": [
        "@qt3d//:3dinput_shared",
        "@qt3d//:3dcore_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    "@qt3d//:3dlogic": [
        "@qt3d//:3dlogic_shared",
        "@qt3d//:3dcore_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    "@qt3d//:3dextras": [
        "@qt3d//:3dextras_shared",
        "@qt3d//:3drender_shared",
        "@qt3d//:3dinput_shared",
        "@qt3d//:3dlogic_shared",
        "@qt3d//:3dcore_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    "@qt3d//:3danimation": [
        "@qt3d//:3danimation_shared",
        "@qt3d//:3drender_shared",
        "@qt3d//:3dcore_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    "@qt3d//:3dquick": [
        "@qt3d//:3dquick_shared",
        "@qt3d//:3dcore_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    "@qt3d//:3dquickrender": [
        "@qt3d//:3dquickrender_shared",
        "@qt3d//:3dquick_shared",
        "@qt3d//:3drender_shared",
        "@qt3d//:3dcore_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    "@qt3d//:3dquickinput": [
        "@qt3d//:3dquickinput_shared",
        "@qt3d//:3dquick_shared",
        "@qt3d//:3dinput_shared",
        "@qt3d//:3dcore_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    "@qt3d//:3dquicklogic": [
        "@qt3d//:3dquicklogic_shared",
        "@qt3d//:3dlogic_shared",
        "@qt3d//:3dcore_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    "@qt3d//:3dquickextras": [
        "@qt3d//:3dquickextras_shared",
        "@qt3d//:3dquick_shared",
        "@qt3d//:3dextras_shared",
        "@qt3d//:3drender_shared",
        "@qt3d//:3dinput_shared",
        "@qt3d//:3dlogic_shared",
        "@qt3d//:3dcore_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    "@qt3d//:3dquickanimation": [
        "@qt3d//:3dquickanimation_shared",
        "@qt3d//:3dquick_shared",
        "@qt3d//:3danimation_shared",
        "@qt3d//:3drender_shared",
        "@qt3d//:3dcore_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    "@qt3d//:3dquickscene2d": [
        "@qt3d//:3dquickscene2d_shared",
        "@qt3d//:3dquick_shared",
        "@qt3d//:3drender_shared",
        "@qt3d//:3dcore_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    "@qt3d//:3dquickscene3d": [
        "@qt3d//:3dquickscene3d_shared",
        "@qt3d//:3danimation_shared",
        "@qt3d//:3drender_shared",
        "@qt3d//:3dinput_shared",
        "@qt3d//:3dlogic_shared",
        "@qt3d//:3dcore_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:core_shared",
    ],
    # --- @qtmultimedia ---
    "@qtmultimedia//:multimedia": [
        "@qtmultimedia//:multimedia_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtmultimedia//:multimediawidgets": [
        "@qtmultimedia//:multimediawidgets_shared",
        "@qtmultimedia//:multimedia_shared",
        "@qtbase//:widgets_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtmultimedia//:multimediaquick": [
        "@qtmultimedia//:multimediaquick_shared",
        "@qtmultimedia//:multimedia_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtmultimedia//:quickmultimedia": [
        "@qtmultimedia//:multimediaquick_shared",
        "@qtmultimedia//:multimedia_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtmultimedia//:spatialaudio": [
        "@qtmultimedia//:spatialaudio_shared",
        "@qtmultimedia//:multimedia_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtmultimedia//:spatialaudioquick3d": [
        "@qtmultimedia//:spatialaudioquick3d_shared",
        "@qtmultimedia//:spatialaudio_shared",
        "@qtmultimedia//:multimediaquick_shared",
        "@qtmultimedia//:multimedia_shared",
        "@qtquick3d//:quick3d_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtmultimedia//:quick3dspatialaudio": [
        "@qtmultimedia//:spatialaudioquick3d_shared",
        "@qtmultimedia//:spatialaudio_shared",
        "@qtmultimedia//:multimediaquick_shared",
        "@qtmultimedia//:multimedia_shared",
        "@qtquick3d//:quick3d_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtmultimedia//:qffmpegmediaplugin": [
        "@qtmultimedia//:ffmpeg_shared",
        "@qtmultimedia//:multimedia_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtmultimedia//:qdarwinmediaplugin": [
        "@qtmultimedia//:multimedia_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtmultimedia//:qwindowsmediaplugin": [
        "@qtmultimedia//:multimedia_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtmultimedia//:multimedia_plugins": [
        "@qtmultimedia//:ffmpeg_shared",
        "@qtmultimedia//:multimedia_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    # --- @qtspeech ---
    "@qtspeech//:tts": [
        "@qtspeech//:tts_shared",
        "@qtmultimedia//:multimedia_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtspeech//:ttsqml": [
        "@qtspeech//:ttsqml_shared",
        "@qtspeech//:tts_shared",
        "@qtmultimedia//:multimedia_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtspeech//:ttsqmlplugin": [
        "@qtspeech//:ttsqml_shared",
        "@qtspeech//:tts_shared",
        "@qtmultimedia//:multimedia_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtspeech//:qtexttospeech_mock": [
        "@qtspeech//:tts_shared",
        "@qtmultimedia//:multimedia_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtspeech//:qtexttospeech_speechd": [
        "@qtspeech//:tts_shared",
        "@qtmultimedia//:multimedia_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtspeech//:qtexttospeech_speechdarwin": [
        "@qtspeech//:tts_shared",
        "@qtmultimedia//:multimedia_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtspeech//:qtexttospeech_sapi": [
        "@qtspeech//:tts_shared",
        "@qtmultimedia//:multimedia_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtspeech//:tts_plugins": [
        "@qtspeech//:tts_shared",
        "@qtmultimedia//:multimedia_shared",
        "@qtbase//:concurrent_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    # --- @qtbase Wayland client & @qtwayland ---
    "@qtbase//:wayland_client": [
        "@qtbase//:wayland_client_shared",
        "@qtbase//:x11_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:core_shared",
    ],
    "@qtbase//:wl_shell_integration_private": [
        "@qtbase//:wl_shell_integration_private_shared",
        "@qtbase//:wayland_client_shared",
        "@qtbase//:x11_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:core_shared",
    ],
    "@qtbase//:qwayland": [
        "@qtbase//:wayland_client_shared",
        "@qtbase//:x11_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:core_shared",
    ],
    "@qtbase//:qwayland_plugin": [
        "@qtbase//:wayland_client_shared",
        "@qtbase//:x11_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:core_shared",
    ],
    "@qtbase//:qwayland_bradient_decoration_plugin": [
        "@qtbase//:wayland_client_shared",
        "@qtbase//:x11_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:core_shared",
    ],
    "@qtbase//:qwayland_xdg_shell_integration_plugin": [
        "@qtbase//:wayland_client_shared",
        "@qtbase//:x11_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:core_shared",
    ],
    "@qtbase//:qwayland_wl_shell_integration_plugin": [
        "@qtbase//:wl_shell_integration_private_shared",
        "@qtbase//:wayland_client_shared",
        "@qtbase//:x11_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:core_shared",
    ],
    "@qtbase//:qwayland_fullscreen_shell_v1_plugin": [
        "@qtbase//:wayland_client_shared",
        "@qtbase//:x11_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:core_shared",
    ],
    "@qtbase//:qwayland_egl_client_buffer_plugin": [
        "@qtbase//:wayland_client_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:x11_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:core_shared",
    ],
    "@qtbase//:qwayland_shm_emulation_server_buffer_plugin": [
        "@qtbase//:wayland_client_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:x11_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:core_shared",
    ],
    "@qtbase//:qwayland_drm_egl_server_buffer_plugin": [
        "@qtbase//:wayland_client_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:x11_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:core_shared",
    ],
    "@qtwayland//:wayland_compositor": [
        "@qtwayland//:wayland_compositor_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:wayland_client_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:x11_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtwayland//:wayland_egl_compositor_hw_integration_private": [
        "@qtwayland//:wayland_egl_compositor_hw_integration_private_shared",
        "@qtwayland//:wayland_compositor_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:wayland_client_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:x11_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtwayland//:wayland_compositor_iviapplication": [
        "@qtwayland//:wayland_compositor_iviapplication_shared",
        "@qtwayland//:wayland_compositor_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:wayland_client_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:x11_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtwayland//:wayland_compositor_presentationtime": [
        "@qtwayland//:wayland_compositor_presentationtime_shared",
        "@qtwayland//:wayland_compositor_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:wayland_client_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:x11_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtwayland//:wayland_compositor_qtshell": [
        "@qtwayland//:wayland_compositor_qtshell_shared",
        "@qtwayland//:wayland_compositor_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:wayland_client_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:x11_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtwayland//:wayland_compositor_wlshell": [
        "@qtwayland//:wayland_compositor_wlshell_shared",
        "@qtwayland//:wayland_compositor_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:wayland_client_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:x11_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtwayland//:wayland_compositor_xdgshell": [
        "@qtwayland//:wayland_compositor_xdgshell_shared",
        "@qtwayland//:wayland_compositor_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:wayland_client_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:x11_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtwayland//:qwaylandcompositorplugin": [
        "@qtwayland//:wayland_compositor_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:wayland_client_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:x11_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtwayland//:qwaylandcompositoriviapplicationplugin": [
        "@qtwayland//:wayland_compositor_iviapplication_shared",
        "@qtwayland//:wayland_compositor_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:wayland_client_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:x11_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtwayland//:qwaylandcompositorpresentationtimeplugin": [
        "@qtwayland//:wayland_compositor_presentationtime_shared",
        "@qtwayland//:wayland_compositor_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:wayland_client_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:x11_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtwayland//:qwaylandqtshellplugin": [
        "@qtwayland//:wayland_compositor_qtshell_shared",
        "@qtwayland//:wayland_compositor_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:wayland_client_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:x11_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtwayland//:qwaylandcompositorwlshellplugin": [
        "@qtwayland//:wayland_compositor_wlshell_shared",
        "@qtwayland//:wayland_compositor_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:wayland_client_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:x11_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtwayland//:qwaylandcompositorxdgshellplugin": [
        "@qtwayland//:wayland_compositor_xdgshell_shared",
        "@qtwayland//:wayland_compositor_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:wayland_client_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:x11_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtwayland//:qwayland_adwaita_decoration_plugin": [
        "@qtsvg//:svg_shared",
        "@qtbase//:wayland_client_shared",
        "@qtbase//:x11_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:core_shared",
    ],
    "@qtwayland//:qwayland_ivi_shell_integration_plugin": [
        "@qtbase//:wayland_client_shared",
        "@qtbase//:x11_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:core_shared",
    ],
    "@qtwayland//:qwayland_qt_shell_integration_plugin": [
        "@qtbase//:wayland_client_shared",
        "@qtbase//:x11_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:core_shared",
    ],
    "@qtwayland//:qwayland_egl_compositor_buffer_plugin": [
        "@qtwayland//:wayland_egl_compositor_hw_integration_private_shared",
        "@qtwayland//:wayland_compositor_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:wayland_client_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:x11_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtwayland//:qwayland_shm_emulation_compositor_buffer_plugin": [
        "@qtwayland//:wayland_compositor_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:wayland_client_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:x11_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtwayland//:qwayland_drm_egl_compositor_buffer_plugin": [
        "@qtwayland//:wayland_compositor_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:wayland_client_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:x11_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtwayland//:qwayland_eglstream_compositor_buffer_plugin": [
        "@qtwayland//:wayland_egl_compositor_hw_integration_private_shared",
        "@qtwayland//:wayland_compositor_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:wayland_client_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:x11_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    # --- @qtbase additional targets ---
    "@qtbase//:qminimal_plugin": [
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:core_shared",
    ],
    "@qtbase//:qsqlite_plugin": [
        "@qtbase//:sql_shared",
        "@qtbase//:core_shared",
    ],
    # --- @qtwebview ---
    "@qtwebview//:webview": [
        "@qtwebview//:webview_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:core_shared",
    ],
    "@qtwebview//:webviewquick": [
        "@qtwebview//:webviewquick_shared",
        "@qtwebview//:webview_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtwebview//:qtwebviewquickplugin": [
        "@qtwebview//:webviewquick_shared",
        "@qtwebview//:webview_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtwebview//:qtwebview_darwin": [
        "@qtwebview//:webview_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:core_shared",
    ],
    "@qtwebview//:webview_plugins": [
        "@qtwebview//:webview_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:core_shared",
    ],
    # --- @qtgrpc ---
    "@qtgrpc//:protobuf": [
        "@qtgrpc//:protobuf_shared",
        "@qtbase//:core_shared",
    ],
    "@qtgrpc//:protobufwellknowntypes": [
        "@qtgrpc//:protobufwellknowntypes_shared",
        "@qtgrpc//:protobuf_shared",
        "@qtbase//:core_shared",
    ],
    "@qtgrpc//:protobufqtcoretypes": [
        "@qtgrpc//:protobufqtcoretypes_shared",
        "@qtgrpc//:protobuf_shared",
        "@qtbase//:core_shared",
    ],
    "@qtgrpc//:protobufqtguitypes": [
        "@qtgrpc//:protobufqtguitypes_shared",
        "@qtgrpc//:protobufqtcoretypes_shared",
        "@qtgrpc//:protobuf_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:core_shared",
    ],
    "@qtgrpc//:protobufquick": [
        "@qtgrpc//:protobufquick_shared",
        "@qtgrpc//:protobuf_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtgrpc//:protobufquickplugin": [
        "@qtgrpc//:protobufquick_shared",
        "@qtgrpc//:protobuf_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtgrpc//:grpc": [
        "@qtgrpc//:grpc_shared",
        "@qtgrpc//:protobuf_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtgrpc//:grpcquick": [
        "@qtgrpc//:grpcquick_shared",
        "@qtgrpc//:grpc_shared",
        "@qtgrpc//:protobufquick_shared",
        "@qtgrpc//:protobuf_shared",
        "@qtdeclarative//:qmlnetwork_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtgrpc//:grpcquickplugin": [
        "@qtgrpc//:grpcquick_shared",
        "@qtgrpc//:grpc_shared",
        "@qtgrpc//:protobufquick_shared",
        "@qtgrpc//:protobuf_shared",
        "@qtdeclarative//:qmlnetwork_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    # --- @qttools ---
    "@qttools//:uiplugin": [
        "@qtbase//:widgets_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:core_shared",
    ],
    ":uiplugin": [
        "@qtbase//:widgets_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:core_shared",
    ],
    "@qttools//:uitools": [
        "@qttools//:uitools_shared",
        "@qtbase//:openglwidgets_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:widgets_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:core_shared",
    ],
    ":uitools": [
        "@qttools//:uitools_shared",
        "@qtbase//:openglwidgets_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:widgets_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:core_shared",
    ],
    "@qttools//:designer_lib": [
        "@qttools//:designer_lib_shared",
        "@qtbase//:openglwidgets_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:widgets_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:xml_shared",
        "@qtbase//:core_shared",
    ],
    ":designer_lib": [
        "@qttools//:designer_lib_shared",
        "@qtbase//:openglwidgets_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:widgets_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:xml_shared",
        "@qtbase//:core_shared",
    ],
    "@qttools//:designercomponents": [
        "@qttools//:designercomponents_shared",
        "@qttools//:designer_lib_shared",
        "@qtbase//:openglwidgets_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:widgets_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:xml_shared",
        "@qtbase//:core_shared",
    ],
    ":designercomponents": [
        "@qttools//:designercomponents_shared",
        "@qttools//:designer_lib_shared",
        "@qtbase//:openglwidgets_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:widgets_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:xml_shared",
        "@qtbase//:core_shared",
    ],
    "@qttools//:qquickwidgetplugin": [
        "@qttools//:designer_lib_shared",
        "@qtdeclarative//:quickwidgets_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:openglwidgets_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:widgets_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:xml_shared",
        "@qtbase//:core_shared",
    ],
    "@qttools//:help": [
        "@qttools//:help_shared",
        "@qtbase//:widgets_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:sql_shared",
        "@qtbase//:core_shared",
    ],
    ":help": [
        "@qttools//:help_shared",
        "@qtbase//:widgets_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:sql_shared",
        "@qtbase//:core_shared",
    ],
    "@qttools//:helpplugin": [
        "@qttools//:help_shared",
        "@qtdeclarative//:qmlcompiler_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:widgets_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:sql_shared",
        "@qtbase//:core_shared",
    ],
    ":helpplugin": [
        "@qttools//:help_shared",
        "@qtdeclarative//:qmlcompiler_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:widgets_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:sql_shared",
        "@qtbase//:core_shared",
    ],
    "@qttools//:qlitehtml": [
        "@qtbase//:printsupport_shared",
        "@qtbase//:widgets_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:core_shared",
    ],
    ":qlitehtml": [
        "@qtbase//:printsupport_shared",
        "@qtbase//:widgets_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:core_shared",
    ],
    ":assistant_app_lib": [
        "@qttools//:help_shared",
        "@qtbase//:printsupport_shared",
        "@qtbase//:widgets_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:sql_shared",
        "@qtbase//:core_shared",
    ],
    ":qhelpgenerator_lib": [
        "@qttools//:help_shared",
        "@qtbase//:widgets_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:sql_shared",
        "@qtbase//:core_shared",
    ],
    ":designer_app_lib": [
        "@qttools//:designercomponents_shared",
        "@qttools//:designer_lib_shared",
        "@qtbase//:printsupport_shared",
        "@qtbase//:openglwidgets_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:widgets_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:xml_shared",
        "@qtbase//:core_shared",
    ],
    ":linguist_app_lib": [
        "@qttools//:uitools_shared",
        "@qtdeclarative//:quickwidgets_shared",
        "@qtdeclarative//:quicklayouts_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:printsupport_shared",
        "@qtbase//:openglwidgets_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:widgets_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    ":qdbusviewer_app_lib": [
        "@qtbase//:widgets_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:xml_shared",
        "@qtbase//:core_shared",
    ],
    ":pixeltool_app_lib": [
        "@qtbase//:widgets_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:core_shared",
    ],
    ":qdistancefieldgenerator_app_lib": [
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:widgets_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    ":qev_app_lib": [
        "@qtbase//:widgets_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:core_shared",
    ],
}

def _lbl(s):
    if type(s) == type("") and s.startswith("@") and not s.startswith("@@"):
        repo, rest = s[1:].split("//", 1)
        return Label("@@" + repo + "+//" + rest)
    return s

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
    target_lbl = _lbl(target_str)
    for d in deps:
        if d == target_str or d == target_lbl or _dep_key(d) == target_str:
            return True
    return False

def _resolve_qt_dynamic_deps(deps, dynamic_deps):
    """Automatically maps @qtbase library deps to their cc_shared_library dynamic_deps."""
    if type(deps) != type([]):
        return dynamic_deps
    result = [_lbl(d) for d in dynamic_deps] if type(dynamic_deps) == type([]) else []
    seen = {str(d): True for d in result}
    for dep in deps:
        key = _dep_key(dep)
        for shared_dep in _QTBASE_SHARED_MAP.get(key, _QTBASE_SHARED_MAP.get(dep, [])):
            lbl_dep = _lbl(shared_dep)
            if str(lbl_dep) not in seen:
                seen[str(lbl_dep)] = True
                result.append(lbl_dep)
    quick_lbl = str(_lbl("@qtdeclarative//:quick_shared"))
    opengl_lbl = _lbl("@qtbase//:opengl_shared")
    if quick_lbl in seen and str(opengl_lbl) not in seen:
        seen[str(opengl_lbl)] = True
        result.append(opengl_lbl)
    return result

# Public, read-only view of the Qt library -> cc_shared_library mapping
# (F-INF-9), for consumers writing plain rules_cc targets.
QT_SHARED_LIBS = _QTBASE_SHARED_MAP

def qt_shared_libs(deps):
    """Returns the Qt `cc_shared_library` targets that `deps` should link against.

    Use this with plain `cc_binary`/`cc_test`/`cc_shared_library` targets:

        cc_binary(
            name = "app",
            deps = ["@qtbase//:widgets"],
            dynamic_deps = qt_shared_libs(["@qtbase//:widgets"]),
        )

    Args:
      deps: List of Qt library labels (strings or Labels).

    Returns:
      A list of `Label`s for the matching `*_shared` targets.
    """
    return _resolve_qt_dynamic_deps(list(deps), [])

# Plugins implied by a Qt library dependency (F-INF-4). This mirrors upstream's
# per-module default plugin sets (`qt_import_plugins` / `QT_DEFAULT_PLUGINS`):
# a binary that depends on the library automatically links the backends it
# needs at runtime. Opt out per binary with `autolink_plugins = False`.
_QT_IMPLIED_PLUGINS = {
    "@qtbase//:network": ["@qtbase//:tls_plugins"],
    "@qtbase//:sql": ["@qtbase//:sqldriver_plugins"],
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
            if not _has_dep(lib_deps, p):
                lib_deps.append(_lbl(p))
    return lib_deps

def _needs_gui_plugin(deps):
    if type(deps) != type([]):
        return False
    for dep in deps:
        key = _dep_key(dep)
        if key in (
            "@qtbase//:gui",
            ":gui",
            "@qtbase//:opengl",
            ":opengl",
            "@qtbase//:openglwidgets",
            ":openglwidgets",
            "@qtbase//:widgets",
            ":widgets",
            "@qtdeclarative//:quick",
            "@qtdeclarative//:quickcontrols2",
            "@qtdeclarative//:quickwidgets",
            "@qtcharts//:charts",
            "@qtlocation//:location",
            "@qttools//:uitools",
            "@qttools//:designer_lib",
            "@qttools//:designercomponents",
            "@qttools//:help",
            ":designer_app_lib",
            ":linguist_app_lib",
            ":qdbusviewer_app_lib",
            ":pixeltool_app_lib",
            ":qdistancefieldgenerator_app_lib",
            ":qev_app_lib",
        ) or "@qtbase//:gui_shared" in _QTBASE_SHARED_MAP.get(key, _QTBASE_SHARED_MAP.get(dep, [])):
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
#
# Extend as more plugins gain Bazel targets, e.g.
#   "@platforms//os:linux": {"plugins": ["@qtbase//:xcb", "@qtwayland//:wayland"],
#                            "env": {"QT_QPA_PLATFORM": "wayland;xcb;offscreen"}},
#   "@platforms//os:macos": {"plugins": ["@qtbase//:cocoa"], "env": {}},
_QPA_PLATFORM_CONFIG = {
    Label("@platforms//os:linux"): {
        "plugins": [
            "@qtbase//:xcb",
            "@qtbase//:qxcb_glx_integration",
            "@qtbase//:qxcb_egl_integration",
            "@qtbase//:qwayland",
            "@qtbase//:qwayland_xdg_shell_integration_plugin",
            "@qtbase//:qwayland_wl_shell_integration_plugin",
            "@qtbase//:qwayland_bradient_decoration_plugin",
            "@qtbase//:qwayland_egl_client_buffer_plugin",
        ],
        "env": {"QT_QPA_PLATFORM": "xcb;wayland;offscreen"},
    },
    Label("@platforms//os:macos"): {
        "plugins": ["@qtbase//:cocoa"],
        "env": {"QT_QPA_PLATFORM": "cocoa;offscreen"},
    },
    Label("@platforms//os:windows"): {
        "plugins": ["@qtbase//:windows"],
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

def _finalize_dynamic_deps(dynamic_deps):
    if type(dynamic_deps) != type([]):
        return dynamic_deps
    dbus_lbl = _lbl("@qtbase//:dbus_shared")
    if dbus_lbl in dynamic_deps or "@qtbase//:dbus_shared" in dynamic_deps:
        return [d for d in dynamic_deps if d != dbus_lbl and d != "@qtbase//:dbus_shared"] + select({
            Label("@platforms//os:windows"): [],
            "//conditions:default": [dbus_lbl],
        })
    return dynamic_deps

def _platform_plugin_selects(deps, dynamic_deps, env):
    """Builds `select()`s for the per-OS QPA plugins and runtime environment.

    Plugins (and their shared libs) already present in `deps` / `dynamic_deps`
    are skipped so that Bazel never sees duplicate labels. Keys in `env` take
    precedence over the per-OS defaults.

    Returns:
      A `(deps_select, dynamic_deps_select, env_select)` tuple.
    """
    deps_by_os = {}
    dynamic_deps_by_os = {}
    env_by_os = {}
    dbus_lbl = _lbl("@qtbase//:dbus_shared")
    win_cond = Label("@platforms//os:windows")
    existing_dyn_strs = {str(d): True for d in dynamic_deps}
    for condition, cfg in _QPA_PLATFORM_CONFIG.items():
        new_plugins = [_lbl(p) for p in cfg["plugins"] if not _has_dep(deps, p)]
        deps_by_os[condition] = new_plugins
        dynamic_deps_by_os[condition] = [
            d
            for d in _resolve_qt_dynamic_deps(new_plugins, [])
            if str(d) not in existing_dyn_strs and (condition != win_cond or d != dbus_lbl)
        ]
        env_by_os[condition] = _update_dict(cfg["env"], env)
    return select(deps_by_os), select(dynamic_deps_by_os), select(env_by_os)

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

def qt_plugin_FixMe(
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
        moc_unity = moc_unity,
        target_compatible_with = target_compatible_with,
        testonly = testonly,
    )

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

    target_compatible_with = kwargs.get("target_compatible_with", None)
    testonly = kwargs.get("testonly", None)
    common_kwargs = {}
    if target_compatible_with != None:
        common_kwargs["target_compatible_with"] = target_compatible_with
    if testonly != None:
        common_kwargs["testonly"] = testonly

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
    """Builds a Qt C++ binary linked dynamically against @qtbase's LGPL cc_shared_library targets.

    Qt library deps (`@qtbase//:core`, `:gui`, `:widgets`, ...) are mapped automatically to
    the matching `*_shared` targets in `dynamic_deps`. GUI binaries get the `offscreen` QPA
    plugin linked in statically.

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
    common_kwargs = {}
    if target_compatible_with != None:
        common_kwargs["target_compatible_with"] = target_compatible_with
    if testonly != None:
        common_kwargs["testonly"] = testonly

    lib_deps = list(deps)
    if _needs_gui_plugin(lib_deps):
        for p in ("@qtbase//:offscreen", "@qtbase//:qgif", "@qtbase//:qico", "@qtbase//:qjpeg"):
            if not _has_dep(lib_deps, p):
                lib_deps.append(_lbl(p))
    if autolink_plugins:
        _add_implied_plugins(lib_deps)

    resolved_dynamic_deps = _resolve_qt_dynamic_deps(lib_deps, dynamic_deps)

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
    if _needs_gui_plugin(lib_deps):
        # Interactive binaries additionally link the native QPA plugin for the
        # target OS (see _QPA_PLATFORM_CONFIG); tests only use offscreen.
        deps_sel, dyn_sel, env_sel = _platform_plugin_selects(
            lib_deps,
            resolved_dynamic_deps,
            cc_binary_kwargs.pop("env", {}),
        )
        binary_deps = binary_deps + deps_sel + select({
            Label("@platforms//os:linux"): [Label("@qtbase//:glvnd_stubs")],
            "//conditions:default": [],
        })
        resolved_dynamic_deps = _finalize_dynamic_deps(resolved_dynamic_deps) + dyn_sel
        cc_binary_kwargs["env"] = env_sel
    else:
        resolved_dynamic_deps = _finalize_dynamic_deps(resolved_dynamic_deps)

    if win32_gui:
        binary_deps = binary_deps + select({
            Label("@platforms//os:windows"): [Label("@qtbase//:entrypoint")],
            "//conditions:default": [],
        })
        cc_binary_kwargs["linkopts"] = cc_binary_kwargs.get("linkopts", []) + select({
            Label("@platforms//os:windows"): ["-mwindows"],
            "//conditions:default": [],
        })

    cc_binary(
        name = name,
        srcs = srcs + extra_srcs,
        copts = copts + QT_PLATFORM_COPTS,
        defines = defines + QT_PLATFORM_DEFINES,
        deps = binary_deps,
        dynamic_deps = resolved_dynamic_deps,
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
    """Builds a Qt C++ test linked dynamically against @qtbase's LGPL cc_shared_library targets.

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
    common_kwargs = {"testonly": testonly}
    if target_compatible_with != None:
        common_kwargs["target_compatible_with"] = target_compatible_with

    lib_deps = list(deps)
    is_gui = _needs_gui_plugin(lib_deps)
    if is_gui:
        for p in ("@qtbase//:offscreen", "@qtbase//:qgif", "@qtbase//:qico", "@qtbase//:qjpeg"):
            if not _has_dep(lib_deps, p):
                lib_deps.append(_lbl(p))
    if autolink_plugins:
        _add_implied_plugins(lib_deps)

    resolved_dynamic_deps = _resolve_qt_dynamic_deps(lib_deps, dynamic_deps)

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
        deps_sel, dyn_sel, test_env = _platform_plugin_selects(
            lib_deps,
            resolved_dynamic_deps,
            _update_dict({"QT_QPA_PLATFORM": "offscreen"}, env),
        )
        test_deps = test_deps + deps_sel + select({
            Label("@platforms//os:linux"): [Label("@qtbase//:glvnd_stubs")],
            "//conditions:default": [],
        })
        resolved_dynamic_deps = _finalize_dynamic_deps(resolved_dynamic_deps) + dyn_sel
    else:
        resolved_dynamic_deps = _finalize_dynamic_deps(resolved_dynamic_deps)

    cc_test_kwargs = dict(kwargs)
    cc_test_kwargs["features"] = list(cc_test_kwargs.get("features", [])) + ["compiler_param_file"]

    cc_test(
        name = name,
        srcs = srcs + extra_srcs,
        copts = copts + QT_PLATFORM_COPTS,
        defines = defines + QT_PLATFORM_DEFINES,
        deps = test_deps,
        dynamic_deps = resolved_dynamic_deps,
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

    The Qt libraries listed in `qt_deps` are resolved to their `*_shared`
    counterparts (including transitive Qt modules) and added to
    `dynamic_deps`, so the resulting `.so`/`.dll` does not embed a private
    copy of QtCore/QtGui/... (which would break `QCoreApplication`,
    metatype and plugin singletons shared across libraries).

    Args:
      name: Target name.
      deps: Root `cc_library` targets of the shared library.
      qt_deps: Qt library labels used (directly or transitively) by `deps`,
        e.g. `["@qtbase//:widgets"]`. Defaults to `["@qtbase//:core"]`.
      dynamic_deps: Extra `cc_shared_library` deps.
      exports_filter: Forwarded to `cc_shared_library`.
      **kwargs: Forwarded to `cc_shared_library`.
    """
    if qt_deps == None:
        qt_deps = ["@qtbase//:core"]
    user_link_flags = kwargs.pop("user_link_flags", [])
    if "shared_lib_name" not in kwargs:
        # MinGW links dynamic deps with -l<name>, which only resolves a DLL
        # named lib<name>.dll (same convention as Qt's own *_shared targets).
        kwargs["shared_lib_name"] = select({
            Label("@platforms//os:windows"): "lib" + name + ".dll",
            "//conditions:default": "",
        })
    cc_shared_library(
        name = name,
        deps = deps,
        dynamic_deps = _finalize_dynamic_deps(_resolve_qt_dynamic_deps(list(qt_deps), dynamic_deps)),
        exports_filter = exports_filter,
        user_link_flags = user_link_flags + QT_SHARED_PLATFORM_LINKOPTS,
        **kwargs
    )
