# Cherry Studio, built from upstream's AppImage WITHOUT a bubblewrap sandbox.
#
# appimageTools.wrapType2 is extract + buildFHSEnv, and buildFHSEnv is a sandbox
# with no way to disable it -- wrong for an app whose whole state is
# ~/.config/CherryStudio. So: extract unpacked (no FUSE), exec the Electron
# binary directly (AppRun's `#!/usr/bin/env bash` has no /usr/bin/env on NixOS),
# and hand it upstream's own AppImage library list via LD_LIBRARY_PATH. nix-ld
# supplies the interpreter (nixos/system.nix).
#
# Wayland Quick Assistant fix: Electron keeps one value per switch, and 2.1.4
# appends "enable-features" twice, so GlobalShortcutsPortal is clobbered and the
# hotkey never binds. The install phase does two length-preserving in-place edits
# to app.asar (the second call carries the flag). Each anchor must occur exactly
# once, so a Cherry bump that moves this code fails the build loudly.
#
# The portal (>= 1.21) also needs an app id backed by an installed .desktop file;
# it resolves the id "CherryStudio", so the file MUST keep that exact name.
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

  contents = appimageTools.extract { inherit pname version src; };

  fhsArgs = appimageTools.defaultFhsEnvArgs;
  runtimeLibs = lib.makeLibraryPath (fhsArgs.multiPkgs pkgs ++ fhsArgs.targetPkgs pkgs);
  runtimeBin = lib.makeBinPath (fhsArgs.targetPkgs pkgs);

  # Length-preserving byte edits in place. Invoked as: python3 <this> <app.asar>
  asarPatch = pkgs.writeText "cherry-studio-wayland-shortcut.py" ''
    import sys

    path = sys.argv[1]
    data = open(path, "rb").read()

    # (old, new) pairs, equal length. The first call is dead code -- its value is
    # always overwritten -- so it is emptied to free the bytes the second needs.
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

    # Only the sum has to net to zero, or the archive's offsets break.
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
  # Upstream's binaries are correct as shipped; nix-ld handles the interpreter.
  dontPatchELF = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt/cherry-studio
    cp -a . $out/opt/cherry-studio
    chmod +x $out/opt/cherry-studio/CherryStudio

    asar=$out/opt/cherry-studio/resources/app.asar
    chmod u+w "$asar"
    python3 ${asarPatch} "$asar"

    # Mirrors AppRun's exports, minus the sandbox. The --run replicates AppRun's
    # userns probe, falling back to --no-sandbox only when unshare fails.
    makeWrapper $out/opt/cherry-studio/CherryStudio $out/bin/cherry-studio \
      --prefix LD_LIBRARY_PATH : "$out/opt/cherry-studio/usr/lib:${runtimeLibs}" \
      --prefix PATH : "$out/opt/cherry-studio:$out/opt/cherry-studio/usr/sbin:${runtimeBin}" \
      --prefix XDG_DATA_DIRS : "$out/opt/cherry-studio/usr/share" \
      --run 'if ! ${util-linux}/bin/unshare -Ur true 2>/dev/null; then set -- --no-sandbox "$@"; fi'

    # Keep the AppImage's own file name -- the portal resolves the app id
    # "CherryStudio" by looking up exactly CherryStudio.desktop.
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
