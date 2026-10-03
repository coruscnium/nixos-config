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
  ];
}
