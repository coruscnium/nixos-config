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
    jdk17
    rustc
    cargo
    python3Packages.keyboard
  ];

  # Auto-load a dev shell per directory: an .envrc with `use flake` enters the
  # project's nix develop shell on cd. nix-direnv caches the result.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
