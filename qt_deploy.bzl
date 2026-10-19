"""Deployment rules for Qt applications (Phase 4, F-RT-1 / F-RT-2 / F-TOOL-4).

`qt_deploy` packages a `qt_cc_binary` into a relocatable tarball with an
upstream-style prefix layout, so that `QLibraryInfo` resolves real paths
instead of locations inside Bazel's `_solib_*` / runfiles trees:

    <name>/
      bin/<app>                 the executable
      bin/<app>.runfiles/...    shared libraries + data (RUNPATH-relative)
      bin/qt.conf               Prefix=.. ; Translations/Plugins/Qml paths
      translations/*.qm         QTranslator catalogs (e.g. @qttranslations)
      plugins/  qml/            reserved for dynamic plugins / QML imports

With `macos_app = True` the layout is an `.app` bundle instead:

    <name>.app/Contents/MacOS/<app>, Contents/Resources/qt.conf,
    Contents/Resources/translations/*.qm, Contents/Info.plist
"""

_QT_CONF = """[Paths]
Prefix={prefix}
Binaries={bindir}
Translations={translations}
Plugins=plugins
QmlImports=qml
Qml2Imports=qml
Data=.
"""

_INFO_PLIST = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>{exe}</string>
  <key>CFBundleIdentifier</key><string>{bundle_id}</string>
  <key>CFBundleName</key><string>{name}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>{version}</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
"""

def _runfiles_path(f, workspace_name):
    sp = f.short_path
    if sp.startswith("../"):
        return sp[3:]
    return workspace_name + "/" + sp

def _qt_deploy_impl(ctx):
    exe = ctx.executable.binary
    exe_name = exe.basename
    ws = ctx.workspace_name
    name = ctx.attr.package_name or ctx.label.name

    if ctx.attr.macos_app:
        root = name + ".app/Contents"
        bindir = root + "/MacOS"
        confdir = root + "/Resources"
        trdir = root + "/Resources/translations"
        conf = _QT_CONF.format(prefix = "..", bindir = "MacOS", translations = "Resources/translations")
    else:
        root = name
        bindir = root + "/bin"
        confdir = bindir
        trdir = root + "/translations"
        conf = _QT_CONF.format(prefix = "..", bindir = "bin", translations = "translations")

    qt_conf = ctx.actions.declare_file(ctx.label.name + "_qt.conf")
    ctx.actions.write(qt_conf, conf)

    entries = [(exe, bindir + "/" + exe_name), (qt_conf, confdir + "/qt.conf")]
    if ctx.attr.macos_app:
        plist = ctx.actions.declare_file(ctx.label.name + "_Info.plist")
        ctx.actions.write(plist, _INFO_PLIST.format(
            exe = exe_name,
            bundle_id = ctx.attr.bundle_id or ("org.qt-project." + name),
            name = name,
            version = ctx.attr.version,
        ))
        entries.append((plist, root + "/Info.plist"))

    runfiles = ctx.attr.binary[DefaultInfo].default_runfiles
    rf_root = bindir + "/" + exe_name + ".runfiles/"
    seen = {}
    for f in runfiles.files.to_list():
        dest = rf_root + _runfiles_path(f, ws)
        if dest not in seen:
            seen[dest] = True
            entries.append((f, dest))
    for f in ctx.files.translations:
        entries.append((f, trdir + "/" + f.basename))
    for f in ctx.files.data:
        entries.append((f, root + "/" + f.basename))

    manifest = ctx.actions.declare_file(ctx.label.name + "_manifest.txt")
    ctx.actions.write(manifest, "".join(["%s\t%s\n" % (src.path, dest) for src, dest in entries]))

    out = ctx.actions.declare_file(ctx.label.name + ".tar")
    ctx.actions.run_shell(
        inputs = depset([manifest] + [src for src, _ in entries]),
        outputs = [out],
        command = """
set -euo pipefail
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/{root}/plugins" "$stage/{root}/qml"
while IFS="$(printf '\\t')" read -r src dest; do
  mkdir -p "$stage/$(dirname "$dest")"
  cp -L "$src" "$stage/$dest"
done < "{manifest}"
chmod +x "$stage/{bindir}/{exe}"
tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner \
    -cf "{out}" -C "$stage" "{top}"
""".format(
            root = root,
            manifest = manifest.path,
            bindir = bindir,
            exe = exe_name,
            out = out.path,
            top = root.split("/")[0],
        ),
        mnemonic = "QtDeploy",
        progress_message = "Packaging Qt application %s" % ctx.label,
    )
    return [DefaultInfo(files = depset([out]))]

qt_deploy = rule(
    implementation = _qt_deploy_impl,
    doc = "Packages a Qt binary with its runtime, translations and qt.conf into a relocatable tarball.",
    attrs = {
        "binary": attr.label(
            mandatory = True,
            executable = True,
            cfg = "target",
            doc = "The `qt_cc_binary` to deploy.",
        ),
        "translations": attr.label_list(
            allow_files = [".qm"],
            doc = "`.qm` catalogs placed in the `translations/` prefix dir (e.g. `@qttranslations//:qm_files`).",
        ),
        "data": attr.label_list(
            allow_files = True,
            doc = "Extra files copied to the package root.",
        ),
        "package_name": attr.string(doc = "Top-level directory name; defaults to the target name."),
        "macos_app": attr.bool(default = False, doc = "Produce a macOS `.app` bundle layout."),
        "bundle_id": attr.string(doc = "CFBundleIdentifier for `macos_app`."),
        "version": attr.string(default = "1.0", doc = "CFBundleShortVersionString for `macos_app`."),
    },
)
