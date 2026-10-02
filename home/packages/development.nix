# Editors and development tooling.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    kdePackages.kate # text/code editor
    vim
    ripgrep
    fd

    # Re-resolves the AppImage sources tracked in nvfetcher.toml.
    nvfetcher
  ];
}
