{ pkgs, ... }:

# File management, encryption, disk tooling.
{
  home.packages = with pkgs; [
    gocryptfs
    sirikali
    trash-cli
    ripgrep
    gum
    duf
    compsize
    xdg-ninja
    gparted
    btrfs-assistant
    plocate

    # Modern CLI replacements for find/cat/ls, plus a fuzzy finder, a directory
    # tree, and tldr's short man pages.
    fd
    bat
    eza
    fzf
    tree
    tldr
  ];
}
