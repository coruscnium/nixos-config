{ pkgs, ... }:

# Notes, scanning, document search. naps2 pairs with the brscan5 driver
# (nixos/desktop.nix).
{
  home.packages = with pkgs; [
    obsidian
    naps2
    clapgrep
  ];
}
