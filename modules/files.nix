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
    warehouse # GTK GUI for browsing/installing Flatpaks (Flatseal is a flatpak, nixos/services.nix)

    # Modern CLI replacements for find/cat/ls, plus a fuzzy finder, a directory
    # tree, and tldr's short man pages.
    fd
    bat
    eza
    fzf
    tree
    tldr

    # Archive tooling. ark (modules/desktop.nix) finds its CLI backends on the
    # session PATH -- the kerfuffle plugins call QStandardPaths::findExecutable --
    # and nothing here provided them, so its rar/unarchiver plugins were dead on
    # arrival: rar, StuffIt, arj all silently did nothing. unar is the rar backend
    # (RAR1.3 through RAR5 incl. AES, plus StuffIt/ACE/ZOO/LZH/ARJ); 7-Zip covers
    # zip/7z/tar/iso at the command line. _7zz is the free build -- only reach for
    # _7zz-rar if some archive defeats unar's decoder.
    unar
    _7zz
    zip
    unzip
  ];
}
