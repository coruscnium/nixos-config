{ pkgs, ... }:

# Editors and toolchains. git is NOT listed -- it comes from nixos/system.nix, so
# listing it here would install it twice (AGENTS.md rule 11).
# Pick rustc+cargo OR rustup, not both.
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
