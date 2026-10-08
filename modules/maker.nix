{ pkgs, ... }:

# 3D printing / making. ElegooSlicer is Elegoo's own OrcaSlicer fork (a custom
# package wrapping the upstream AppImage); the printer is reached over the LAN
# through OctoEverywhere, which lives on the machine side (nixos/octoeverywhere.nix).
{
  home.packages = with pkgs; [
    elegooslicer
  ];
}
