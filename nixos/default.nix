{
  config,
  pkgs,
  lib,
  ...
}:

# Shared machine policy: everything true of every host. Per-host facts -- disk
# UUIDs, the ESP, the bootloader, the hostname -- live in ../hosts/<name>/.
{
  imports = [
    ./boot.nix
    ./desktop.nix
    ./flatpaks.nix
    ./services.nix
    ./gaming.nix
    ./users.nix
    ./system.nix
    ./octoeverywhere.nix
    ./windscribe.nix
  ];
}
