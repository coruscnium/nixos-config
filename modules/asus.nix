{ pkgs, ... }:

{
  services.asusd.enable = true; # fan curves, keyboard, platform profiles
  services.supergfxd.enable = true; # MUX / Optimus GPU-mode switching
  programs.rog-control-center.enable = true; # GUI front-end (pulls in asusd)

  # asusctl 6.3.7's asusd.service hardens with `ReadWritePaths=/etc/asusd/`,
  # which systemd insists must exist before the unit starts. The nixpkgs module
  # only creates that directory when an asusd config blob is set, so a bare
  # enable fails with 226/NAMESPACE and hits the restart limit. Create it up
  # front; asusd then writes its own state there.
  systemd.tmpfiles.rules = [
    "d /etc/asusd 0755 root root -"
  ];

  environment.systemPackages = with pkgs; [
    asusctl
    supergfxctl
  ];
}
