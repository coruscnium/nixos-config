{ pkgs, ... }:

# Editors, toolchains, Android tooling for your custom phone app.
#
# Pick rustc+cargo OR rustup, not both -- they collide on PATH.
# android-tools gives adb/fastboot. The full SDK is available as
# pkgs.androidenv.androidPkgs.{platform-tools,build-tools,platforms}; add those
# when you actually build the APK.
{
  home.packages = with pkgs; [
    vscode
    claude-code
    git
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
