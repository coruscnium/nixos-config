{ pkgs, ... }:

# Editors, toolchains, Android tooling for your custom phone app.
#
# git is NOT listed here -- it comes from nixos/system.nix
# (environment.systemPackages), so it is already on PATH for every user.
# Listing it in both layers installs it twice (AGENTS.md rule 11).
#
# Pick rustc+cargo OR rustup, not both -- they collide on PATH.
# android-tools gives adb/fastboot. The full SDK is available as
# pkgs.androidenv.androidPkgs.{platform-tools,build-tools,platforms}; add those
# when you actually build the APK.
{
  home.packages = with pkgs; [
    vscode
    claude-code
    uv
    nodejs
    pnpm
    gradle
    jdk17
    dotnet-sdk_8
    rustc
    cargo
    android-tools
    python3Packages.keyboard
  ];
}
