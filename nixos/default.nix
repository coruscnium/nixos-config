{
  config,
  pkgs,
  lib,
  ...
}:

# NixOS system configuration. Hardware facts and UUIDs live in hardware.nix.
{
  imports = [
    ./hardware.nix
    ./boot.nix
    ./desktop.nix
    ./services.nix
    ./gaming.nix
    ./users.nix
    ./system.nix
    ./octoeverywhere.nix
    ./windscribe.nix
  ];
}
