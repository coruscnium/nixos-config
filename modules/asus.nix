{ pkgs, ... }:

{
  services.asusd.enable = true; # fan curves, keyboard, platform profiles
  services.supergfxd.enable = true; # MUX / Optimus GPU-mode switching
  programs.rog-control-center.enable = true; # GUI front-end (pulls in asusd)

  environment.systemPackages = with pkgs; [
    asusctl
    supergfxctl
  ];
}
