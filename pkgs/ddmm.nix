# ddmm -- Democracy Defender Mod Manager (katsyk/DemocracyDefenderModManager).
#
# A Tauri v2 app: the whole UI is a WebKitGTK 4.1 webview over a Rust core, and
# upstream ships it as one self-contained binary in a flat tarball (./ddmm and
# ./QUICKSTART.txt, no top directory). Building from source would drag in the
# complete Cargo + WebKit toolchain for no gain, so the release binary is
# repacked and patched instead.
#
# Bump: version, then src.hash and icon.hash (nix-prefetch-url --type sha256
# <url>, or set lib.fakeHash and read the "got:" out of a failed build).
# Not nvfetcher: every upstream release so far is a prerelease (rc.N), and
# nvfetcher's src.github resolves via releases/latest, which 404s on this repo.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  wrapGAppsHook3,
  makeDesktopItem,
  copyDesktopItems,
  glib,
  gtk3,
  gdk-pixbuf,
  cairo,
  dbus,
  webkitgtk_4_1,
  libsoup_3,
}:

let
  desktopItem = makeDesktopItem {
    name = "ddmm";
    desktopName = "Democracy Defender";
    comment = "Mod manager for Helldivers 2";
    exec = "ddmm";
    icon = "ddmm";
    categories = [
      "Game"
      "Utility"
    ];
  };
in
stdenv.mkDerivation rec {
  pname = "ddmm";
  version = "2.0.0-rc.16";

  src = fetchurl {
    url = "https://github.com/katsyk/DemocracyDefenderModManager/releases/download/v${version}/DDMM-${version}-linux-x64.tar.gz";
    hash = "sha256-+yv7y6a0cA9bl9/jvLRE6ndlCeCxNepQ2n1lc7GwpwE=";
  };

  # The tarball has no top-level directory; keep "." so unpackPhase leaves the
  # binary in the build root.
  sourceRoot = ".";

  # Upstream's launcher icon, same tag as the binary.
  icon = fetchurl {
    url = "https://raw.githubusercontent.com/katsyk/DemocracyDefenderModManager/v${version}/src-tauri/icons/128x128.png";
    hash = "sha256-olLtbYTlJvObV1DVioHH7BxxxL8tU965A+1+izM7hJ8=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    wrapGAppsHook3
    copyDesktopItems
  ];

  buildInputs = [
    glib
    gtk3
    gdk-pixbuf
    cairo
    dbus
    webkitgtk_4_1
    libsoup_3
    # The binary links libstdc++.so.6, which the Rust toolchain does not vendor.
    stdenv.cc.cc.lib
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 ddmm $out/bin/ddmm
    install -Dm644 ${icon} $out/share/icons/hicolor/128x128/apps/ddmm.png
    install -Dm644 QUICKSTART.txt $out/share/doc/ddmm/QUICKSTART.txt

    runHook postInstall
  '';

  desktopItems = [ desktopItem ];

  meta = {
    description = "Source-neutral mod manager for Helldivers 2";
    homepage = "https://github.com/katsyk/DemocracyDefenderModManager";
    license = lib.licenses.asl20;
    mainProgram = "ddmm";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
