# olsvr -- Wayland OLED burn-in screensaver (laveez/olsvr). Not in nixpkgs, and
# upstream ships no release binaries, so it is built from source at the tag.
# Shown on an idle desktop -- which is exactly what a VR session looks like to
# the monitor, since input goes to the headset -- it blanks the panel with a
# clock that fades and repositions instead of holding a static frame.
#
# Bump: update version + src.hash (nix-prefetch-github laveez olsvr --rev vX) +
# cargoHash (set to lib.fakeHash, rebuild, copy the "got:" hash). Nothing else.
{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  makeWrapper,
  wayland,
  libxkbcommon,
  dbus,
  fontconfig,
  vulkan-loader,
}:

rustPlatform.buildRustPackage rec {
  pname = "olsvr";
  version = "0.2.1";

  src = fetchFromGitHub {
    owner = "laveez";
    repo = "olsvr";
    rev = "v${version}";
    hash = "sha256-H4cxUWw6pklU43HGvtqi9MX6UvL0NAXuxDY8LKaYCog=";
  };

  cargoHash = "sha256-241GKn2crPKEX8QyoXPUYOt9iIClE/WsrO0WKwK5cwE=";

  nativeBuildInputs = [
    pkg-config
    makeWrapper
  ];
  buildInputs = [
    wayland
    libxkbcommon
    dbus
    fontconfig
    vulkan-loader
  ];

  # wgpu loads the Vulkan loader at runtime (dlopen), which the binary's RPATH
  # does not cover.
  postInstall = ''
    wrapProgram $out/bin/olsvr --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ vulkan-loader ]}
  '';

  meta = {
    description = "OLED burn-in screensaver for Wayland";
    homepage = "https://github.com/laveez/olsvr";
    license = lib.licenses.mit;
    mainProgram = "olsvr";
    platforms = [ "x86_64-linux" ];
  };
}
