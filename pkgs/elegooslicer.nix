# ElegooSlicer — Elegoo's OrcaSlicer fork, distributed only as an AppImage.
#
# The AppImage is a thin GTK bundle: it ships the slicer binary and Elegoo's
# cloud SDK (libagora_rtm_sdk.so), and expects a host GTK3 / webkit2gtk-4.1 /
# gstreamer / OpenGL stack — lib/orca-runtime carries only expat/lzma/zlib/mspack.
# So wrapType2 fits, its buildFHSEnv supplies that stack, except the default
# package set omits webkit2gtk (which the app's own AppRun probes for and aborts
# without) and libsoup3 (which the binary links directly), hence extraPkgs.
#
# Upstream's AppRun is kept rather than exec'ing the bare binary: it exports
# LC_ALL=C (their segfault workaround) and the NVIDIA/zink Wayland overrides,
# and it only runs at all inside the FHS env. wrapType2 installs no desktop
# entry or icon, so those are laid on top.
{
  lib,
  callPackage,
  appimageTools,
  symlinkJoin,
  libsoup_3,
  webkitgtk_4_1,
}:

let
  sources = callPackage ../_sources/generated.nix { };
  inherit (sources.elegooslicer) pname version src;

  contents = appimageTools.extract { inherit pname version src; };

  wrapped = appimageTools.wrapType2 {
    inherit pname version src;
    extraPkgs = _: [
      libsoup_3
      webkitgtk_4_1
    ];
  };

  # ElegooSlicer kept OrcaSlicer's reverse-DNS app id.
  desktopId = "com.orcaslicer.ElegooSlicer";
in
symlinkJoin {
  name = "${pname}-${version}";
  paths = [ wrapped ];

  postBuild = ''
    install -Dm644 ${contents}/usr/share/applications/${desktopId}.desktop \
      $out/share/applications/${desktopId}.desktop
    substituteInPlace $out/share/applications/${desktopId}.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=${pname}'

    install -Dm644 ${contents}/usr/share/icons/hicolor/192x192/apps/ElegooSlicer.png \
      $out/share/icons/hicolor/192x192/apps/ElegooSlicer.png
  '';

  meta = {
    description = "Elegoo's OrcaSlicer fork for Elegoo FDM printers (upstream AppImage)";
    homepage = "https://github.com/elegooofficial/ElegooSlicer";
    # AGPL-3.0 slicer (strings in the binary confirm it); the AppImage also
    # bundles the proprietary Agora RTM SDK used for Elegoo's cloud printing.
    license = lib.licenses.agpl3Only;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "elegooslicer";
  };
}
