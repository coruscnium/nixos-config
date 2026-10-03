{ pkgs, ... }:

# Notes, scanning, document search.
# naps2 pairs with brscan5, which is a NixOS-side driver (unfree .deb repack).
{
  home.packages = with pkgs; [
    obsidian
    naps2
    clapgrep
  ];
}
