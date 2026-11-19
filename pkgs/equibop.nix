# Equibop, repacked from the upstream release tarball.
#
# nixpkgs froze this package at 3.2.2 on 2026-10-07 and has never carried 3.3.x,
# so `nix flake update` cannot reach a current build -- there is no route to one
# through nixpkgs at all. 3.3.3 is the release that rewrote the screenshare path
# and moved to Electron 45, and it is the fix for the Wayland capture failure
# 3.2.2 exhibits here (Chromium 4x asked KWin for a BGRA buffer, had every frame
# marked content-free, and tore the stream down).
#
# Repack rather than build from source: upstream ships a self-contained tarball
# with its own Electron runtime, which is far more predictable than maintaining a
# bun + electron-builder build plus a node_modules FOD against a moving tree.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  copyDesktopItems,
  makeDesktopItem,
  alsa-lib,
  at-spi2-core,
  cups,
  dbus,
  expat,
  glib,
  gtk3,
  libdrm,
  libgbm,
  libGL,
  libice,
  libpulseaudio,
  libsm,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxkbcommon,
  libxrandr,
  libxrender,
  libxtst,
  nspr,
  nss,
  pipewire,
  systemd,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "equibop";
  version = "3.3.4";

  src = fetchurl {
    url = "https://github.com/Equicord/Equibop/releases/download/v${finalAttrs.version}/equibop-${finalAttrs.version}.tar.gz";
    hash = "sha256-Zu1mdRhduacTDu3wCyJOkj8t/9EeqiBwiULAueA+2d0=";
  };

  # The release tarball ships no icon; upstream keeps it in the repo instead.
  icon = fetchurl {
    url = "https://raw.githubusercontent.com/Equicord/Equibop/v${finalAttrs.version}/build/icon.svg";
    hash = "sha256-SWW6UYNr3B1NDJ1nK06Yq1m5GJwG/20j5cJ+LFmtLwU=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    copyDesktopItems
  ];

  buildInputs = [
    alsa-lib
    at-spi2-core
    cups
    dbus
    expat
    gtk3
    libdrm
    libgbm
    libGL
    libice
    libpulseaudio
    libsm
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxi
    libxkbcommon
    libxrandr
    libxrender
    libxtst
    nspr
    nss
    systemd
  ];

  # The release binary is already stripped upstream; re-stripping 230 MB of
  # Electron every build buys nothing.
  dontStrip = true;

  desktopItems = [
    (makeDesktopItem {
      name = "equibop";
      desktopName = "Equibop";
      exec = "equibop %U";
      icon = "equibop";
      startupWMClass = "Equibop";
      genericName = "Internet Messenger";
      keywords = [
        "discord"
        "equibop"
        "electron"
        "chat"
      ];
      categories = [
        "Network"
        "InstantMessaging"
        "Chat"
      ];
    })
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt/equibop
    cp -r . $out/opt/equibop

    # Electron's setuid sandbox helper cannot be setuid inside the store. Removing
    # it makes Chromium fall back to the user-namespace sandbox, which NixOS
    # permits, instead of aborting on the empty helper.
    rm -f $out/opt/equibop/chrome-sandbox

    install -Dm644 ${finalAttrs.icon} $out/share/icons/hicolor/scalable/apps/equibop.svg

    # Flags match what the nixpkgs wrapper passed when NIXOS_OZONE_WL was set.
    # Unconditional: --ozone-platform-hint=auto resolves to X11 when Wayland is
    # absent, so this is correct under either session.
    mkdir -p $out/bin
    cat > $out/bin/equibop <<WRAPPER
    #!${stdenv.shell}
    # Native modules live INSIDE app.asar. Electron extracts them to a temp dir
    # before dlopen()ing, so they carry no RUNPATH and autoPatchelfHook cannot see
    # them at all -- everything they need must already be searchable. Measured per
    # module: venmic-x64.node -> libpipewire + libpulse (this is the audio device
    # picker), game-detection-x64.node -> libstdc++, libvesktop-x64.node ->
    # libglib/libgio/libgobject + libstdc++. Missing any one of these is silent:
    # the feature's list just comes up empty.
    LD_LIBRARY_PATH=${
      lib.makeLibraryPath [
        glib
        libpulseaudio
        pipewire
        stdenv.cc.cc.lib
      ]
    }''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
    export LD_LIBRARY_PATH

    exec ${placeholder "out"}/opt/equibop/equibop \
      --ozone-platform-hint=auto \
      --enable-features=WaylandWindowDecorations \
      --enable-wayland-ime=true \
      "\$@"
    WRAPPER
    chmod +x $out/bin/equibop

    runHook postInstall
  '';

  meta = {
    description = "Custom Discord app with Equicord preinstalled";
    homepage = "https://github.com/Equicord/Equibop";
    changelog = "https://github.com/Equicord/Equibop/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.gpl3Only;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "equibop";
  };
})
