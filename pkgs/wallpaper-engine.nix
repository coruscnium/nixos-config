# Wallpaper Engine integration for Plasma 6 -- the CaptSilver fork.
#
# Has a git submodule (src/backend_scene), so fetchSubmodules is required -- a
# plain tarball has an empty submodule and will not build. Deps come from
# upstream CMakeLists.txt.
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

    # It is a Plasma plugin (loaded by plasmashell), not a standalone app, so it
    # must NOT be wrapped with a Qt environment. qtbase's setup hook demands you
    # choose; there is no executable to wrap.
    dontWrapQtApps = true;

    cmakeBuildType = "Release";

    # backend_scene's SoundManager calls Device::Init({}) with a zeroed
    # DeviceDesc, so the playback device asks PulseAudio for 0 channels. miniaudio
    # only overrides that from the sink's sample spec, and when that comes back
    # empty -- plasmashell loading the wallpaper in the same second PipeWire does
    # -- libpulse's pa_channel_map_init_extend asserts on pa_channels_valid(0)
    # and aborts plasmashell. Stereo is what the mixer already assumes; pinning
    # phyChannels makes ss.channels 2 whatever the sink query returns.
    # Upstream still has both the zeroed struct and Init({}) at 2026-10-28.
    postPatch = ''
      substituteInPlace src/backend_scene/src/Audio/miniaudio-wrapper.hpp \
        --replace-fail '    ma_uint32              phyChannels;' \
        '    ma_uint32              phyChannels = 2;'
    '';

    meta = {
      description = "Wallpaper Engine integration for KDE Plasma 6 (native C++, no Python)";
      homepage = "https://github.com/CaptSilver/wallpaper-engine-kde-plugin";
      license = lib.licenses.gpl2Only;
      platforms = [ "x86_64-linux" ];
    };
  };
}
