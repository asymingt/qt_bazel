"""Public Bazel rules for building Qt C++ libraries, binaries, tests, UI headers, and resources."""

load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@rules_cc//cc:cc_library.bzl", "cc_library")
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
    "@qtbase//:xcb": ["@qtbase//:xcb_qpa_shared", "@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    ":xcb": ["@qtbase//:xcb_qpa_shared", "@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
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
    "@qtbase//:network": ["@qtbase//:network_shared", "@qtbase//:core_shared"],
    ":network": ["@qtbase//:network_shared", "@qtbase//:core_shared"],
    "@qtbase//:qopensslbackend": ["@qtbase//:network_shared", "@qtbase//:core_shared"],
    ":qopensslbackend": ["@qtbase//:network_shared", "@qtbase//:core_shared"],
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
    "@qtimageformats//:qtga": ["@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtimageformats//:qtiff": ["@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtimageformats//:qwbmp": ["@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtimageformats//:qwebp": ["@qtbase//:gui_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    # --- @qtdeclarative ---
    "@qtdeclarative//:qml": [
        "@qtdeclarative//:qml_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtdeclarative//:qmlmodels": [
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtdeclarative//:qmlworkerscript": [
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtdeclarative//:qmlmeta": [
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtdeclarative//:quick": [
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
    "@qtdeclarative//:quicklayouts": [
        "@qtdeclarative//:quicklayouts_shared",
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
    "@qtdeclarative//:quickshapes": [
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
    "@qtdeclarative//:quicktemplates2": [
        "@qtdeclarative//:quicktemplates2_shared",
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
    "@qtdeclarative//:quickcontrols2impl": [
        "@qtdeclarative//:quickcontrols2impl_shared",
        "@qtdeclarative//:quicktemplates2_shared",
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
    "@qtdeclarative//:quickcontrols2": [
        "@qtdeclarative//:quickcontrols2_shared",
        "@qtdeclarative//:quickcontrols2impl_shared",
        "@qtdeclarative//:quicktemplates2_shared",
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
    "@qtdeclarative//:quickcontrols2basic": [
        "@qtdeclarative//:quickcontrols2basic_shared",
        "@qtdeclarative//:quickcontrols2basicstyleimpl_shared",
        "@qtdeclarative//:quickcontrols2_shared",
        "@qtdeclarative//:quickcontrols2impl_shared",
        "@qtdeclarative//:quicktemplates2_shared",
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
    "@qtdeclarative//:quickwidgets": [
        "@qtdeclarative//:quickwidgets_shared",
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
    "@qtdeclarative//:quicktest": [
        "@qtdeclarative//:quicktest_shared",
        "@qtdeclarative//:quick_shared",
        "@qtdeclarative//:qmlmeta_shared",
        "@qtdeclarative//:qmlmodels_shared",
        "@qtdeclarative//:qmlworkerscript_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:opengl_shared",
        "@qtbase//:test_shared",
        "@qtbase//:gui_shared",
        "@qtbase//:dbus_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtdeclarative//:qtquick2plugin": [
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
    "@qtdeclarative//:quickwindow": [
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
    "@qtdeclarative//:qquicklayoutsplugin": [
        "@qtdeclarative//:quicklayouts_shared",
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
    "@qtdeclarative//:qmlshapesplugin": [
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
    "@qtdeclarative//:qtquicktemplates2plugin": [
        "@qtdeclarative//:quicktemplates2_shared",
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
    "@qtdeclarative//:qtquickcontrols2plugin": [
        "@qtdeclarative//:quickcontrols2_shared",
        "@qtdeclarative//:quickcontrols2impl_shared",
        "@qtdeclarative//:quicktemplates2_shared",
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
    "@qtdeclarative//:qtquickcontrols2basicstyleplugin": [
        "@qtdeclarative//:quickcontrols2basic_shared",
        "@qtdeclarative//:quickcontrols2basicstyleimpl_shared",
        "@qtdeclarative//:quickcontrols2_shared",
        "@qtdeclarative//:quickcontrols2impl_shared",
        "@qtdeclarative//:quicktemplates2_shared",
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
    # --- Phase 2 Milestone 3 modules ---
    "@qtwebsockets//:websockets": ["@qtwebsockets//:websockets_shared", "@qtbase//:network_shared", "@qtbase//:core_shared"],
    "@qtwebchannel//:webchannel": ["@qtwebchannel//:webchannel_shared", "@qtdeclarative//:qml_shared", "@qtbase//:network_shared", "@qtbase//:core_shared"],
    "@qtwebchannel//:webchannelquick": ["@qtwebchannel//:webchannelquick_shared", "@qtwebchannel//:webchannel_shared", "@qtdeclarative//:qml_shared", "@qtbase//:network_shared", "@qtbase//:core_shared"],
    "@qthttpserver//:httpserver": ["@qthttpserver//:httpserver_shared", "@qtwebsockets//:websockets_shared", "@qtbase//:network_shared", "@qtbase//:concurrent_shared", "@qtbase//:core_shared"],
    "@qtnetworkauth//:networkauth": ["@qtnetworkauth//:networkauth_shared", "@qtbase//:network_shared", "@qtbase//:core_shared"],
    "@qtserialport//:serialport": ["@qtserialport//:serialport_shared", "@qtbase//:core_shared"],
    "@qtserialbus//:serialbus": ["@qtserialbus//:serialbus_shared", "@qtserialport//:serialport_shared", "@qtbase//:network_shared", "@qtbase//:core_shared"],
    "@qtsensors//:sensors": ["@qtsensors//:sensors_shared", "@qtbase//:dbus_shared", "@qtbase//:core_shared"],
    "@qtsensors//:sensorsquick": ["@qtsensors//:sensorsquick_shared", "@qtsensors//:sensors_shared", "@qtdeclarative//:qml_shared", "@qtbase//:dbus_shared", "@qtbase//:network_shared", "@qtbase//:core_shared"],
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
    "@qtconnectivity//:bluetooth": ["@qtconnectivity//:bluetooth_shared", "@qtbase//:network_shared", "@qtbase//:core_shared"],
    "@qtconnectivity//:nfc": ["@qtconnectivity//:nfc_shared", "@qtbase//:core_shared"],
    "@qtlottie//:lottievectorimagehelpers": [
        "@qtlottie//:lottievectorimagehelpers_shared",
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
    "@qtlottie//:lottie": [
        "@qtlottie//:lottie_shared",
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
    "@qtscxml//:scxml": ["@qtscxml//:scxml_shared", "@qtbase//:core_shared"],
    "@qtscxml//:scxmlqml": [
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
    # --- Phase 2 Milestone 4 modules ---
    "@qtquick3d//:glslparser": ["@qtquick3d//:glslparser_shared", "@qtbase//:core_shared"],
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
    "@qtquick3d//:assetutils": [
        "@qtquick3d//:assetutils_shared",
        "@qtquick3d//:quick3d_shared",
        "@qtquick3d//:runtimerender_shared",
        "@qtquick3d//:assetimport_shared",
        "@qtquick3d//:utils_shared",
        "@qtshadertools//:shadertools_shared",
        "@qtdeclarative//:quicktimeline_shared" if False else "@qtdeclarative//:quick_shared",
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
    "@qtmultimedia//:qffmpegmediaplugin": [
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
    "@qtspeech//:qtexttospeech_mock": [
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
    # --- @qtdeclarative QmlNetwork & @qtbase additional targets ---
    "@qtdeclarative//:qmlnetwork": [
        "@qtdeclarative//:qmlnetwork_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
    "@qtdeclarative//:qmlnetworkplugin": [
        "@qtdeclarative//:qmlnetwork_shared",
        "@qtdeclarative//:qml_shared",
        "@qtbase//:network_shared",
        "@qtbase//:core_shared",
    ],
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
        "@qtdeclarative//:qmlls_private_shared",
        "@qtdeclarative//:qmltoolingsettings_private_shared",
        "@qtdeclarative//:qmlcompiler_shared",
        "@qtdeclarative//:qml_shared",
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

def _resolve_qt_dynamic_deps(deps, dynamic_deps):
    """Automatically maps @qtbase library deps to their cc_shared_library dynamic_deps."""
    if type(deps) != type([]):
        return dynamic_deps
    result = list(dynamic_deps) if type(dynamic_deps) == type([]) else []
    seen = {d: True for d in result}
    for dep in deps:
        for shared_dep in _QTBASE_SHARED_MAP.get(dep, []):
            if shared_dep not in seen:
                seen[shared_dep] = True
                result.append(shared_dep)
    if "@qtdeclarative//:quick_shared" in seen and "@qtbase//:opengl_shared" not in seen:
        seen["@qtbase//:opengl_shared"] = True
        result.append("@qtbase//:opengl_shared")
    return result

def _needs_gui_plugin(deps):
    if type(deps) != type([]):
        return False
    for dep in deps:
        if dep in (
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
        ):
            return True
    return False

# Per-target-OS QPA (windowing system) configuration for GUI binaries, in the
# style of reference/qt6_from_binary/qt.bzl's LINUX_*_ENV_DATA tables.
#
#   plugins: static QPA plugins to link in addition to `offscreen`.
#   env:     default runtime environment for `bazel run`/`bazel test`.
#
# `offscreen` is always linked and is Qt's compiled-in default
# (`QT_QPA_DEFAULT_PLATFORM_NAME`). Without an explicit `QT_QPA_PLATFORM`, Qt
# on Linux probes `wayland` and `xcb` first whenever it detects a desktop
# session, warning for each plugin that is not linked in. Pinning a
# `;`-separated list keeps desktop runs quiet and headless runs working.
#
# Extend as more plugins gain Bazel targets, e.g.
#   "@platforms//os:linux": {"plugins": ["@qtbase//:xcb", "@qtwayland//:wayland"],
#                            "env": {"QT_QPA_PLATFORM": "wayland;xcb;offscreen"}},
#   "@platforms//os:macos": {"plugins": ["@qtbase//:cocoa"], "env": {}},
_QPA_PLATFORM_CONFIG = {
    "@platforms//os:linux": {
        "plugins": ["@qtbase//:xcb"],
        "env": {"QT_QPA_PLATFORM": "xcb;offscreen"},
    },
    "@platforms//os:macos": {
        "plugins": ["@qtbase//:cocoa"],
        "env": {"QT_QPA_PLATFORM": "cocoa;offscreen"},
    },
    "@platforms//os:windows": {
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
    if "@qtbase//:dbus_shared" in dynamic_deps:
        return [d for d in dynamic_deps if d != "@qtbase//:dbus_shared"] + select({
            Label("@platforms//os:windows"): [],
            "//conditions:default": ["@qtbase//:dbus_shared"],
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
    for condition, cfg in _QPA_PLATFORM_CONFIG.items():
        new_plugins = [p for p in cfg["plugins"] if p not in deps]
        deps_by_os[condition] = new_plugins
        dynamic_deps_by_os[condition] = [
            d
            for d in _resolve_qt_dynamic_deps(new_plugins, [])
            if d not in dynamic_deps and (condition != "@platforms//os:windows" or d != "@qtbase//:dbus_shared")
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
        srcs = [],
        hdrs = [],
        qml_files = [],
        strip_prefix = "",
        plugin_target = None,
        plugin_class_name = None,
        generate_plugin = True,
        included_moc_hdrs = [],
        moc_hdrs = None,
        moc_srcs = None,
        includes = [],
        copts = [],
        defines = [],
        local_defines = [],
        deps = [],
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

    uri_path = import_name.replace(".", "/")
    qmldir_lines = ["module " + import_name]
    if plugin_target:
        qmldir_lines.append("optional plugin " + plugin_target)
    if plugin_class_name:
        qmldir_lines.append("classname " + plugin_class_name)
    qmldir_lines.append("typeinfo plugins.qmltypes")
    qmldir_lines.append("prefer :/qt-project.org/imports/" + uri_path + "/")
    qmldir_content = "\n".join(qmldir_lines) + "\n"

    target_compatible_with = kwargs.get("target_compatible_with", None)
    qt_internal_library(
        name = name,
        srcs = srcs,
        hdrs = hdrs,
        moc_hdrs = actual_moc_hdrs,
        moc_srcs = moc_srcs,
        qml_args = {
            "uri": import_name,
            "major_version": major_ver,
            "minor_version": minor_ver,
            "qmldir_content": qmldir_content,
            "qml_files": qml_files,
            "qml_strip_prefix": strip_prefix,
        },
        includes = includes,
        copts = ["-w"] + copts,
        defines = defines,
        local_defines = _with_building_qt(local_defines),
        deps = deps,
        create_shared = False,
        moc_unity = kwargs.pop("moc_unity", True),
        **kwargs
    )

    if plugin_target and generate_plugin and plugin_class_name:
        gen_target = plugin_target + "_gen"
        gen_kwargs = {"target_compatible_with": target_compatible_with} if target_compatible_with != None else {}
        qt_qml_plugin_gen(
            name = gen_target,
            plugin_name = plugin_target,
            class_name = plugin_class_name,
            uri = import_name,
            **gen_kwargs
        )
        qt_static_plugin(
            name = plugin_target,
            plugin_class_name = plugin_class_name,
            srcs = [":" + gen_target],
            moc_srcs = [":" + gen_target],
            copts = ["-w"] + copts,
            local_defines = _with_building_qt(local_defines),
            deps = [":" + name] + deps,
            target_compatible_with = target_compatible_with,
        )

common_copts = [
    "-w",
    "-fPIC",
    "-O2",
    "-DNDEBUG",
    "-DQT_NO_CAST_TO_ASCII",
    "-DQT_BUILDING_QT",
    "-Wno-expansion-to-defined",
]

common_defines = []

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
    _ = kwargs
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
        deps = ["@qtbase//:widgets"]
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
            cmd = "$(execpath @qtbase//:uic) $(location %s) -o $@" % u,
            tools = ["@qtbase//:uic"],
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
        deps = ["@qtbase//:core"]
    if not qrc_file:
        qrc_file = "qrc_%s.qrc" % name

    # rcc resolves <file> paths relative to the .qrc file, which is generated
    # under bazel-out/, so each entry must point back at the real file via a
    # relative path. The alias keeps the logical resource name package-relative.
    pkg = native.package_name()
    pkg_prefix = pkg + "/" if pkg else ""
    cmd = (
        "out=$@; d=$$(dirname $$out); {" +
        " printf '<RCC><qresource prefix=\"%s\">';" % prefix +
        " for f in $(SRCS); do" +
        "   printf '<file alias=\"%s\">%s</file>' \"$${f#" + pkg_prefix + "}\" \"$$(realpath -s --relative-to=$$d $$f)\";" +
        " done;" +
        " printf '</qresource></RCC>\\n';" +
        " } > $$out"
    )
    native.genrule(
        name = "%s_qrc" % name,
        srcs = files,
        outs = [qrc_file],
        cmd = cmd,
    )

    out_src = "qrc_%s.cpp" % name
    native.genrule(
        name = "%s_rcc" % name,
        srcs = files + [":%s_qrc" % name],
        outs = [out_src],
        cmd = "QT_RCC_SOURCE_DATE_OVERRIDE=1 $(execpath @qtbase//:rcc) --name %s $(location :%s_qrc) --output $@" % (name, name),
        tools = ["@qtbase//:rcc"],
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
        deps = ["@qtbase//:core"]
    out_src = "qrc_%s.cpp" % name
    native.genrule(
        name = "%s_rcc" % name,
        srcs = files + [qrc_file],
        outs = [out_src],
        cmd = "QT_RCC_SOURCE_DATE_OVERRIDE=1 $(execpath @qtbase//:rcc) --name %s $(location %s) --output $@" % (name, qrc_file),
        tools = ["@qtbase//:rcc"],
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
      local_defines: Private defines; `QT_BUILDING_QT` is added.
      deps: Dependencies.
      moc_unity: Compile moc outputs through a single `mocs_compilation.cpp`
        (CMake AUTOMOC behaviour).
      **kwargs: Forwarded to `cc_library`.
    """
    local_defines = _with_building_qt(local_defines)
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
    common_kwargs = {"target_compatible_with": target_compatible_with} if target_compatible_with != None else {}

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
        copts = ["-w"] + copts + QT_PLATFORM_COPTS,
        defines = defines,
        local_defines = local_defines + QT_PLATFORM_DEFINES,
        deps = deps + extra_deps + select({
            "@platforms//os:windows": ["@qt//:win_cxxabi_shim"],
            "//conditions:default": [],
        }),
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
      **kwargs: Forwarded to `cc_binary`.
    """
    actual_moc_hdrs = hdrs if moc_hdrs == None else moc_hdrs
    if moc_srcs == None:
        if type(srcs) == type([]):
            moc_srcs = [s for s in srcs if s.endswith((".cpp", ".cc", ".cxx", ".mm"))]
        else:
            moc_srcs = []

    target_compatible_with = kwargs.get("target_compatible_with", None)
    common_kwargs = {"target_compatible_with": target_compatible_with} if target_compatible_with != None else {}

    lib_deps = list(deps)
    if _needs_gui_plugin(lib_deps) and "@qtbase//:offscreen" not in lib_deps:
        lib_deps.append("@qtbase//:offscreen")

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
    binary_deps = lib_deps + extra_deps
    if _needs_gui_plugin(lib_deps):
        # Interactive binaries additionally link the native QPA plugin for the
        # target OS (see _QPA_PLATFORM_CONFIG); tests only use offscreen.
        deps_sel, dyn_sel, env_sel = _platform_plugin_selects(
            lib_deps,
            resolved_dynamic_deps,
            cc_binary_kwargs.pop("env", {}),
        )
        binary_deps = binary_deps + deps_sel
        resolved_dynamic_deps = _finalize_dynamic_deps(resolved_dynamic_deps) + dyn_sel
        cc_binary_kwargs["env"] = env_sel
    else:
        resolved_dynamic_deps = _finalize_dynamic_deps(resolved_dynamic_deps)

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
      **kwargs: Forwarded to `cc_test`.
    """
    actual_moc_hdrs = hdrs if moc_hdrs == None else moc_hdrs
    if moc_srcs == None:
        if type(srcs) == type([]):
            moc_srcs = [s for s in srcs if s.endswith((".cpp", ".cc", ".cxx", ".mm"))]
        else:
            moc_srcs = []

    target_compatible_with = kwargs.get("target_compatible_with", None)
    common_kwargs = {"target_compatible_with": target_compatible_with} if target_compatible_with != None else {}

    lib_deps = list(deps)
    is_gui = _needs_gui_plugin(lib_deps)
    if is_gui and "@qtbase//:offscreen" not in lib_deps:
        lib_deps.append("@qtbase//:offscreen")

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
        test_deps = test_deps + deps_sel
        resolved_dynamic_deps = _finalize_dynamic_deps(resolved_dynamic_deps) + dyn_sel
    else:
        resolved_dynamic_deps = _finalize_dynamic_deps(resolved_dynamic_deps)

    cc_test(
        name = name,
        srcs = srcs + extra_srcs,
        copts = copts + QT_PLATFORM_COPTS,
        defines = defines + QT_PLATFORM_DEFINES,
        deps = test_deps,
        dynamic_deps = resolved_dynamic_deps,
        env = test_env,
        **kwargs
    )
