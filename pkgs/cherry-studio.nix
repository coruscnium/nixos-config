# Cherry Studio — built from upstream's AppImage, WITHOUT a bubblewrap sandbox.
#
# Two reasons this does not use appimageTools.wrapType2:
#
#   1. wrapType2 is literally `extract` + buildFHSEnv, and buildFHSEnv is a
#      bubblewrap sandbox. That is why the previous build produced
#      cherry-studio-2.1.4-bwrap and a wrapper full of --ro-bind calls. There is
#      no option to turn it off: appimageTools hardcodes `constructDrv =
#      buildFHSEnv`.
#   2. The FHS sandbox is what makes an AppImage see a synthetic root rather than
#      the real $HOME, which is exactly the wrong thing for an app whose entire
#      state is ~/.config/CherryStudio.
#
# What we do instead:
#
#   * appimageTools.extract is a plain runCommand with no FHS env. It just
#     unpacks the AppImage at build time (so no FUSE at runtime either).
#   * The Electron binary wants /lib64/ld-linux-x86-64.so.2, which NixOS does
#     not have and which `programs.nix-ld` supplies. nixos/system.nix has it on
#     for precisely this class of program.
#   * The AppImage bundles only ~6 libraries and expects the host to provide the
#     rest, so we hand it upstream's own curated AppImage library list (the very
#     list the bwrap wrapper would have mounted into its rootfs) via
#     LD_LIBRARY_PATH instead.
#   * We exec the Electron binary directly rather than AppRun, because AppRun's
#     shebang is `#!/usr/bin/env bash` and /usr/bin/env does not exist on NixOS.
#     Everything AppRun exports is reproduced below.
#
# The version and hash come from nvfetcher:
#   nix run nixpkgs#nvfetcher && nixos-rebuild switch --flake .#coru
#
# ---------------------------------------------------------------------------
# Wayland patch: the Quick Assistant global shortcut
#
# 2.1.4's main process does try to enable Chromium's Wayland global-shortcut
# portal, then clobbers its own flag. In out/main/main.js:
#
#   if (isLinux && XDG_SESSION_TYPE === "wayland")
#     appendSwitch("enable-features", "GlobalShortcutsPortal");
#   ...
#   appendSwitch("enable-features", "DocumentPolicy...,EarlyEstablishGpuChannel,...");
#
# Electron keeps one value per switch name, so the second call overwrites the
# first and "GlobalShortcutsPortal" never reaches Chromium. Under Wayland that
# makes Electron's globalShortcut.register() a silent no-op: the Quick Assistant
# hotkey never binds, and nothing shows up in KDE's shortcut settings.
#
# The install phase rewrites two strings in resources/app.asar IN PLACE. Both
# edits are byte-length-preserving, so the archive's per-file offsets and sizes
# stay valid and the 791 native modules under app.asar.unpacked are untouched --
# a full asar repack could not guarantee that. Each anchor is asserted to occur
# exactly once, so a Cherry bump that moves this code fails the build loudly
# instead of silently shipping an unpatched app.
#
# That flag is necessary but, on xdg-desktop-portal >= 1.21, not sufficient.
# The portal now hard-rejects a GlobalShortcuts CreateSession whose caller has
# no app id (src/global-shortcuts.c: NOT_ALLOWED "An app id is required"), so
# Chromium must first identify itself via
# org.freedesktop.host.portal.Registry.Register. Electron 44 / Chromium 152
# does make that call, but with the app id "CherryStudio" (the app's own name),
# and the portal refuses it:
#
#   Could not register app ID: App info not found for 'CherryStudio'
#
# The id has to be backed by an installed .desktop file. Upstream's AppImage
# ships CherryStudio.desktop -- but this wrapper used to install it *renamed*
# to cherry-studio.desktop, so the lookup could never match and the whole
# portal path died there. Installing it under its own name is the fix.
#
# (A CHROME_DESKTOP env var was tried first and did nothing: Electron derives
# that itself from the app name, so overriding it was moot.)
# ---------------------------------------------------------------------------
{ lib
, stdenv
, appimageTools
, makeWrapper
, callPackage
, util-linux
, python3
, pkgs
}:

let
  sources = callPackage ../_sources/generated.nix { };
  inherit (sources.cherry-studio) pname version src;

  # Unpacked at build time. No FHS env, no bwrap, no runtime FUSE.
  contents = appimageTools.extract { inherit pname version src; };

  # Upstream's own appimage library lists -- the same packages defaultFhsEnvArgs
  # would have put in the sandbox rootfs.
  fhsArgs = appimageTools.defaultFhsEnvArgs;
  runtimeLibs = lib.makeLibraryPath (fhsArgs.multiPkgs pkgs ++ fhsArgs.targetPkgs pkgs);
  runtimeBin = lib.makeBinPath (fhsArgs.targetPkgs pkgs);

  # Length-preserving byte edits to resources/app.asar -- see the header note.
  # Invoked as: python3 <this> <path-to-app.asar>
  asarPatch = pkgs.writeText "cherry-studio-wayland-shortcut.py" ''
    import sys

    path = sys.argv[1]
    data = open(path, "rb").read()

    # (old, new) pairs, each the same byte length. The first call is dead code
    # -- its value is always overwritten -- so it is emptied to free the bytes
    # the second call needs in order to carry the portal flag.
    edits = [
        (
            b'appendSwitch("enable-features", "GlobalShortcutsPortal")',
            b'appendSwitch("enable-features","")',
        ),
        (
            b'appendSwitch("enable-features", "DocumentPolicyIncludeJSCallStacksInCrashReports,',
            b'appendSwitch("enable-features", "GlobalShortcutsPortal,DocumentPolicyIncludeJSCallStacksInCrashReports,',
        ),
    ]

    # The file size must not change, or the archive's stored offsets break.
    # Only the sum of the edits has to net to zero, not each edit on its own.
    assert sum(len(new) - len(old) for old, new in edits) == 0, "edits are not length-preserving overall"

    for old, new in edits:
        assert data.count(old) == 1, ("anchor not unique", old.decode(), data.count(old))
        data = data.replace(old, new)

    open(path, "wb").write(data)
  '';
in
stdenv.mkDerivation {
  pname = "cherry-studio";
  inherit version;
  src = contents;

  nativeBuildInputs = [ makeWrapper python3 ];

  dontConfigure = true;
  dontBuild = true;
  # Upstream's binaries are correct as shipped; do not let anything rewrite
  # their interpreter or RPATH. nix-ld handles the interpreter at runtime.
  dontPatchELF = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt/cherry-studio
    cp -a . $out/opt/cherry-studio
    chmod +x $out/opt/cherry-studio/CherryStudio

    # Wayland Quick Assistant hotkey fix -- see the header note. cp -a keeps
    # upstream's read-only file mode, so make the archive writable first.
    asar=$out/opt/cherry-studio/resources/app.asar
    chmod u+w "$asar"
    python3 ${asarPatch} "$asar"

    # Mirrors AppRun's exports, minus the sandbox:
    #   PATH             -> the AppDir itself
    #   LD_LIBRARY_PATH  -> the AppImage's own libs FIRST, then the nix ones
    #   XDG_DATA_DIRS    -> the AppImage's share dir
    #
    # The --run replicates AppRun's sandbox probe: it uses
    # `unshare -Ur true` to test whether unprivileged user namespaces work, and
    # falls back to Electron's --no-sandbox only when they do not. Without this
    # a kernel with userns disabled would crash on startup instead of starting.
    makeWrapper $out/opt/cherry-studio/CherryStudio $out/bin/cherry-studio \
      --prefix LD_LIBRARY_PATH : "$out/opt/cherry-studio/usr/lib:${runtimeLibs}" \
      --prefix PATH : "$out/opt/cherry-studio:$out/opt/cherry-studio/usr/sbin:${runtimeBin}" \
      --prefix XDG_DATA_DIRS : "$out/opt/cherry-studio/usr/share" \
      --run 'if ! ${util-linux}/bin/unshare -Ur true 2>/dev/null; then set -- --no-sandbox "$@"; fi'

    # Menu entry and icon, straight from the AppImage's own metadata.
    # Keep the AppImage's own file name: Chromium registers the portal app id
    # as "CherryStudio", and the portal resolves it by looking up exactly
    # CherryStudio.desktop. Renaming the file to cherry-studio.desktop broke
    # that lookup and with it every portal feature for the app.
    install -Dm644 CherryStudio.desktop $out/share/applications/CherryStudio.desktop
    substituteInPlace $out/share/applications/CherryStudio.desktop \
      --replace-fail 'Exec=AppRun %U' 'Exec=cherry-studio %U'
    install -Dm644 usr/share/icons/hicolor/1024x1024/apps/CherryStudio.png \
      $out/share/icons/hicolor/1024x1024/apps/CherryStudio.png

    runHook postInstall
  '';

  meta = {
    description = "Desktop AI assistant / LLM client (upstream AppImage, no sandbox)";
    homepage = "https://github.com/CherryHQ/cherry-studio";
    license = lib.licenses.agpl3Only;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "cherry-studio";
  };
}
