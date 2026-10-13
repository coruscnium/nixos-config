{ pkgs, config, ... }:

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

    # VRChat avatar toolchain. ALCOM is the Linux Creator Companion -- it creates
    # and manages Unity projects and their VPM packages. The editor it drives is a
    # runtime download; Unity Hub (which installs the pinned 2022.3.22f1) is the
    # flatpak in nixos/services.nix, not a nix package -- nixpkgs' unityhub is
    # unfree AND its bwrap FHS wrapper never gets a window up.
    alcom
  ];

  # Unity Hub is a flatpak, so it activates and stores Unity's license inside its
  # sandbox (~/.var/app/com.unity.UnityHub/config/unity3d), while the Editor --
  # which ALCOM launches natively -- reads ~/.config/unity3d. Point the native
  # licenses dir at the sandbox one so the activation the Hub performs is visible
  # to the Editor. Without this the Editor opens with "No valid Unity Editor
  # license found" even though the Hub shows a free Personal license as active.
  # mkOutOfStoreSymlink (not source=) so the symlink tracks the live path --
  # the Hub rewrites it in place, and a store copy would go stale.
  xdg.configFile."unity3d/Unity/licenses".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.var/app/com.unity.UnityHub/config/unity3d/Unity/licenses";

  # Auto-load a dev shell per directory: an .envrc with `use flake` enters the
  # project's nix develop shell on cd. nix-direnv caches the result.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
