# `qt` — Rules for building Qt 6 from source with Bazel

This module contains the Starlark build logic shared by every Qt 6 submodule
(`qtbase`, `qtdeclarative`, `qtwayland`, ...) when they are built **from
source** under Bazel using bzlmod. It is a *rules-only* module: it ships no C++
code and no prebuilt Qt. Each Qt submodule declares `bazel_dep(name = "qt")`
and loads the macros below from `@qt//:...`.

## Highlights

- **Qt 6 is compiled from source, inside the Bazel action graph.** Nothing is
  downloaded from `download.qt.io` except the upstream source tarballs, which
  are pinned by integrity hash in the registry. Qt's own code generators
  (`moc`, `rcc`, `uic`, `qmltyperegistrar`, `qmlcachegen`, `qsb`, ...) are
  built as host tools and run as ordinary Bazel actions.
- **Cross-compilation is a first-class feature.** With a hermetic LLVM
  toolchain, the same Qt modules build for **Linux, macOS and Windows** on both
  **x86_64 and arm64** from a single Linux host — including the native QPA
  platform plugins (`xcb`/`wayland`, `cocoa`, `windows`) — just by passing
  `--platforms=...`. No Xcode, Visual Studio or Windows SDK is required.
- **Most of Qt is already available out of the box.** The following Qt 6.10
  modules are packaged as bzlmod modules on top of these rules and build on
  all supported platforms:

  | Area | Modules |
  | --- | --- |
  | Core | `qtbase` (Core, Gui, Widgets, Network, Sql, Dbus, OpenGL, PrintSupport, Test, Concurrent, Xml), `qt5compat`, `qttools`, `qttranslations` |
  | QML / Quick | `qtdeclarative`, `qtshadertools`, `qtsvg`, `qtimageformats`, `qtlanguageserver`, `qtquicktimeline`, `qtlottie`, `qtvirtualkeyboard` |
  | 3D / Visualization | `qtquick3d`, `qtquick3dphysics`, `qt3d`, `qtgraphs`, `qtdatavis3d`, `qtcharts` |
  | Multimedia | `qtmultimedia` (FFmpeg backend, spatial audio), `qtspeech`, `qtwebview` |
  | Networking / IPC | `qtwebsockets`, `qtwebchannel`, `qthttpserver`, `qtnetworkauth`, `qtgrpc` (protobuf + gRPC), `qtremoteobjects` |
  | Devices / Sensors | `qtserialport`, `qtserialbus`, `qtsensors`, `qtpositioning`, `qtlocation`, `qtconnectivity` |
  | Platform / Misc | `qtwayland` (compositor + client), `qtscxml` (SCXML + state machine) |

  Adding another Qt submodule is a matter of writing its `BUILD.bazel` with
  the macros in this module; no changes to the upstream Qt sources are needed.

## What's here

| File | Purpose |
| --- | --- |
| `qt.bzl` | Public rules for Qt consumers and modules: `qt_cc_library`, `qt_cc_binary`, `qt_cc_test`, `qt_ui_library`, `qt_resource`, `qt_qml_module`, `qt_module_headers`, `qt_export_header`, `qt_config_header`, `qt_generate_qrc`. |
| `qt_internal_library.bzl` | `qt_internal_library` / `qt_static_plugin`: the equivalent of CMake's `qt_internal_add_module` / `qt_internal_add_plugin`, used to build the Qt libraries themselves (header syncing, export macros, platform copts/defines, plugin registration). |
| `qt_tools.bzl` | Low-level rules that wrap the Qt code generators: `moc`, `rcc`, `uic`, `qlalr`, `qmltyperegistrar`, `qmlcachegen`, `qsb`, `qdbusxml2cpp`, `repc`, `qscxmlc`, `lrelease`, plus `qt_sync_headers` (the `syncqt` replacement). |
| `qt_protobuf.bzl` | `qt_protobuf_gen` / `qt_grpc_gen` for the `qtgrpc` module's protobuf/gRPC code generators. |
| `qt_wayland.bzl` | `qt_wayland_client_protocol` / `qt_wayland_server_protocol` for `wayland-scanner` + `qtwaylandscanner` generated code. |
| `BUILD.bazel` | Platform `config_setting`s and license metadata shared by all Qt modules. |

## How this differs from other Bazel + Qt projects

The [Related projects](https://github.com/Vertexwahn/rules_qt6#related-projects)
table in `rules_qt6` lists the existing ways to use Qt from Bazel. Nearly all
of them (including `rules_qt6` itself) solve a different problem: **consuming
a prebuilt Qt** from an application. This module instead exists to **build Qt
itself**, one bzlmod module per Qt submodule, so that Qt can be published to
and consumed from a Bazel registry like any other dependency.

| Project | Approach | Contrast with this module |
| --- | --- | --- |
| [Vertexwahn/rules_qt6](https://github.com/Vertexwahn/rules_qt6) | Fetches prebuilt Qt 6 from `download.qt.io`; provides `qt_cc_library`, `qt_ui_library`, `qt_resource`, `qt_qml_module` for apps. Linux/macOS/Windows, bzlmod. | Same consumer-facing macro names, but here they are backed by Qt libraries compiled in the Bazel action graph rather than by a downloaded SDK. No network fetch of binaries; fully hermetic and cross-compilable with the workspace toolchain. |
| [aabtop/rules_qt](https://github.com/aabtop/rules_qt) | Prebuilt Qt, WORKSPACE-only, Windows/Linux. Unmaintained since 2021. | Prebuilt-consumer; no bzlmod; no from-source build. |
| [bbreslauer/qt-bazel-example](https://github.com/bbreslauer/qt-bazel-example) | The original example that most later projects forked. System-installed Qt 5, Linux, WORKSPACE-only. | Example-scale `moc`/`uic` wrapper around a system Qt; not a build of Qt. |
| [FirasRomaneh/QT5WithBazel](https://github.com/FirasRomaneh/QT5WithBazel) | Prebuilt/system Qt 5, Linux, WORKSPACE-only. | Same category as above; Qt 5 rather than Qt 6. |
| [gwkawano/bazel_qt](https://github.com/gwkawano/bazel_qt) | Prebuilt/system Qt, Linux, WORKSPACE-only. | Prebuilt-consumer only. |
| [jheaff1/rules_qt](https://github.com/jheaff1/rules_qt) | Prebuilt Qt, Linux/macOS/Windows, WORKSPACE-only. | Prebuilt-consumer; no bzlmod. |
| [justbuchanan/bazel_rules_qt](https://github.com/justbuchanan/bazel_rules_qt) | Prebuilt/system Qt, Linux/macOS/Windows, WORKSPACE-only. Direct ancestor of `rules_qt6`. | Prebuilt-consumer; no bzlmod. |
| [kklochkov/rules_qt](https://github.com/kklochkov/rules_qt) | bzlmod; Linux/macOS; supports **both** prebuilt and from-source. | Closest in spirit. The from-source path there is a monolithic build driven from the rules repo; here Qt is split into independent bzlmod modules (one per Qt submodule) with the Starlark factored out into this shared `qt` module, so modules version and depend on each other through the registry. |
| [The-OpenROAD-Project/qt_bazel_prebuilts](https://github.com/The-OpenROAD-Project/qt_bazel_prebuilts) | bzlmod; builds Qt from source as a single dependency for OpenROAD's GUI. | Also from-source, but packaged as one bundled module tailored to one downstream consumer. This module is designed to be generic: it carries no Qt sources, supports the full set of Qt code generators (QML, shaders, D-Bus, SCXML, remote objects, protobuf/gRPC, Wayland), and is reused by dozens of Qt submodules. |

In short:

- **Prebuilt-consumer rules** (`rules_qt6` and most of the table) answer
  *"how do I link my app against a Qt I downloaded?"*
- **This module** answers *"how do I express Qt's own build — `syncqt`,
  export headers, `moc`/`rcc`/`uic`, plugins, QML type registration — in
  Starlark so Qt can be built, versioned and consumed as ordinary Bazel
  modules?"*

## Acknowledgements

The **application-facing API** of this module — `qt_cc_library`,
`qt_cc_binary`, `qt_cc_test`, `qt_ui_library`, `qt_resource` and
`qt_qml_module` — is deliberately modelled on
[Vertexwahn/rules_qt6](https://github.com/Vertexwahn/rules_qt6) (Apache-2.0),
which in turn descends from
[justbuchanan/bazel_rules_qt](https://github.com/justbuchanan/bazel_rules_qt)
and the original
[bbreslauer/qt-bazel-example](https://github.com/bbreslauer/qt-bazel-example).
We kept the same macro names and attribute conventions so that switching an
existing project from a prebuilt Qt to a from-source Qt is mostly a matter of
changing the `load()` path. The implementations here are our own (they drive
Qt code generators built in-tree rather than a downloaded SDK), but the shape
of the API and much of the user experience is owed to those projects — thank
you to their authors and contributors.

The module-internal rules (`qt_internal_library`, `qt_static_plugin`,
`qt_sync_headers`, and the rest of `qt_tools.bzl`) mirror the structure of Qt's
own CMake build system (`qt_internal_add_module`, `qt_internal_add_plugin`,
`syncqt`, `qt_add_qml_module`, ...), which was used as the reference for what
each Qt submodule needs.
