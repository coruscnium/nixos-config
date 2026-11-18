# mc7-studio -- Turtle Beach Command Series MC7 configurator.
#
# The Linux release is a PyInstaller AppImage carrying Python, PySide6, HIDAPI
# and 7-Zip. Source is not an option: the wheel pins PySide6 < 6.12 and nixpkgs
# has 6.12.0. Bump: version, then both hashes.
{
  lib,
  appimageTools,
  fetchurl,
  makeDesktopItem,
  symlinkJoin,
}:

let
  pname = "mc7-studio";
  version = "0.2.1";

  src = fetchurl {
    url = "https://github.com/dev-zetta/mc7_studio/releases/download/v${version}/MC7-Studio-${version}-x86_64.AppImage";
    hash = "sha256-JSZAC+f91ZmTkwcq0GFyHoK8O18Fg5d/rmNzQBcuqDM=";
  };

  icon = fetchurl {
    url = "https://raw.githubusercontent.com/dev-zetta/mc7_studio/v${version}/packaging/appimage/mc7-studio.svg";
    hash = "sha256-IQN7RRswRaewVYyfKz1uHVFZ1HenF1vvwN3cYGSKakY=";
  };

  desktopItem = makeDesktopItem {
    name = pname;
    desktopName = "MC7 Studio";
    genericName = "Mouse configurator";
    comment = "Configure the Turtle Beach Command Series MC7 mouse";
    exec = pname;
    icon = pname;
    categories = [
      "Settings"
      "HardwareSettings"
    ];
    extraConfig = {
      Keywords = "mouse;gaming;HID;USB;firmware;LCD;";
      StartupNotify = "true";
    };
  };

  appimage = appimageTools.wrapType2 {
    inherit pname version src;

    # libxcb-cursor: Qt 6's xcb plugin links it, the AppImage omits it and the
    # default FHS set lacks it. desktopItem: the env recomputes XDG_DATA_DIRS
    # inside its rootfs, so Qt's portal lookup needs the app itself present.
    extraPkgs = pkgs: [
      pkgs.libxcb-cursor
      desktopItem
    ];
  };
in
symlinkJoin {
  name = "${pname}-${version}";

  paths = [ appimage ];

  postBuild = ''
    install -Dm644 ${desktopItem}/share/applications/${pname}.desktop \
      $out/share/applications/${pname}.desktop
    install -Dm644 ${icon} $out/share/icons/hicolor/scalable/apps/${pname}.svg
  '';

  meta = {
    description = "Configurator for the Turtle Beach Command Series MC7 mouse";
    homepage = "https://github.com/dev-zetta/mc7_studio";
    license = lib.licenses.gpl3Plus;
    mainProgram = pname;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
