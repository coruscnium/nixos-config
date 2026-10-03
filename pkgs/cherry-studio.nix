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
{ lib
, stdenv
, appimageTools
, makeWrapper
, callPackage
, util-linux
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
in
stdenv.mkDerivation {
  pname = "cherry-studio";
  inherit version;
  src = contents;

  nativeBuildInputs = [ makeWrapper ];

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
    install -Dm644 CherryStudio.desktop $out/share/applications/cherry-studio.desktop
    substituteInPlace $out/share/applications/cherry-studio.desktop \
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
