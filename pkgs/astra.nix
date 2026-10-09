# Astra -- audiophile music player (Electron), shipped only as an AppImage.
#
# A straight electron-builder AppImage: the bundle carries its own Chromium and
# leans on the host for GTK3 / NSS / X11 / XTest, so appimageTools.wrapType2
# fits -- its buildFHSEnv supplies that stack. The FHS bubblewrap launcher binds
# /dev, /run and /home, so PipeWire (Astra drives ALSA hw for bit-perfect
# output), /dev/snd and the Wayland/X sockets stay reachable.
#
# Do NOT pass --no-sandbox, even though upstream's own .desktop does: the app
# parses its own argv and rejects anything it does not recognise ("bad option:
# --no-sandbox"), and it already runs its renderers with --no-sandbox internally.
# So the flag is stripped off the Exec line when rewriting it. Verified on a
# nested kwin_wayland --virtual session: bare launch stays up, --no-sandbox dies.
#
# wrapType2 installs no desktop entry or icon, so both are laid on top from the
# extracted AppImage.
{
  lib,
  callPackage,
  appimageTools,
  symlinkJoin,
}:

let
  sources = callPackage ../_sources/generated.nix { };
  inherit (sources.astra) pname version src;

  contents = appimageTools.extract { inherit pname version src; };

  wrapped = appimageTools.wrapType2 { inherit pname version src; };
in
symlinkJoin {
  name = "${pname}-${version}";
  paths = [ wrapped ];

  postBuild = ''
    install -Dm644 ${contents}/astra.desktop $out/share/applications/astra.desktop
    substituteInPlace $out/share/applications/astra.desktop \
      --replace-fail 'Exec=AppRun --no-sandbox %U' 'Exec=${pname} %U'

    for size in 16 32 48 64 128 256 512 1024; do
      install -Dm644 ${contents}/usr/share/icons/hicolor/''${size}x''${size}/apps/astra.png \
        $out/share/icons/hicolor/''${size}x''${size}/apps/astra.png
    done
  '';

  meta = {
    description = "Audiophile music player with parametric EQ and real-time DSP visualizers";
    homepage = "https://github.com/Boof2015/astra";
    license = lib.licenses.gpl3Only;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "astra";
  };
}
