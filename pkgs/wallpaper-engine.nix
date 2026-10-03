# Wallpaper Engine integration for Plasma 6 — the CaptSilver fork.
#
# In nixpkgs, nyx and NUR: nowhere. This builds the exact commit you are running
# on CachyOS: 1.5.r97.gc1f55bd == rev c1f55bd. That is the "native C++, no
# Python" rewrite, and it is a FORK of the original cat-in-136 plugin.
#
# It has a GIT SUBMODULE (src/backend_scene -> CaptSilver/wallpaper-scene-renderer),
# so the source MUST be fetched with fetchSubmodules. A plain fetchFromGitHub
# tarball has an empty src/backend_scene and will not build.
#
# !! NEVER COMPILED. Evaluation is verified; the build is not, because this
# !! machine has no nix-daemon and cannot build anything as coru. Expect to
# !! iterate on buildInputs the first time it actually builds.
#
# Dependencies come from upstream CMakeLists.txt, not from guessing:
#   top-level: find_package(ECM), find_package(Plasma REQUIRED),
#              KF6 Package Config Notifications Crash I18n
#              (+ GlobalAccel CoreAddons, PlasmaActivities)
#   src/:      Qt6 >= 6.7 Quick Qml Core DBus Network
#              WebEngineCore WebEngineQuick   <-- REQUIRED, so qtwebengine is
#                                                 mandatory (and heavy)
#              KF6XmlGui (optional)
#   Arch PKGBUILD: mpv, gst-libav, lz4, vulkan-icd-loader
final: prev:
let
  inherit (prev) lib;
in
{
  wallpaper-engine-kde-plugin = prev.stdenv.mkDerivation {
    pname = "wallpaper-engine-kde-plugin";
    version = "1.5.r97.gc1f55bd";

    src = prev.fetchgit {
      url = "https://github.com/CaptSilver/wallpaper-engine-kde-plugin";
      rev = "c1f55bd69239f32acc3d4a59c4c96f3e0557e9fb";
      fetchSubmodules = true;
      hash = "sha256-UuVjfIkoyJ5KTq5JcdgzWQIDbzbC2uDrIGhYU7aW9AY=";
    };

    nativeBuildInputs = with prev; [
      cmake
      ninja
      pkg-config
      kdePackages.extra-cmake-modules
    ];

    buildInputs = with prev; [
      kdePackages.libplasma
      kdePackages.kpackage
      kdePackages.kconfig
      kdePackages.knotifications
      kdePackages.kcrash
      kdePackages.ki18n
      kdePackages.kglobalaccel
      kdePackages.kcoreaddons
      kdePackages.kxmlgui
      kdePackages.plasma-activities

      kdePackages.qtbase
      kdePackages.qtdeclarative
      kdePackages.qtwebsockets
      kdePackages.qtwebchannel
      kdePackages.qtwebengine

      mpv
      gst_all_1.gst-libav
      lz4
      vulkan-loader
      vulkan-headers
    ];

    # This is a PLASMA PLUGIN (a shared library loaded by plasmashell), not a
    # standalone application, so it must NOT be wrapped with a Qt environment:
    # the host process already provides one. qtbase's setup hook demands you
    # declare which you mean, and fails with
    #   "this derivation depends on qtbase, but no wrapping behavior was specified"
    # if you do neither. Since there is no executable to wrap, this is the
    # correct answer rather than adding wrapQtAppsHook.
    dontWrapQtApps = true;

    cmakeBuildType = "Release";

    meta = {
      description = "Wallpaper Engine integration for KDE Plasma 6 (native C++, no Python)";
      homepage = "https://github.com/CaptSilver/wallpaper-engine-kde-plugin";
      license = lib.licenses.gpl2Only;
      platforms = [ "x86_64-linux" ];
    };
  };
}
