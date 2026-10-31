{
  config,
  pkgs,
  lib,
  ...
}:

# Shared machine policy: everything true of every host. Both hosts import this
# whole set, so anything machine-specific must NOT land here -- put it in
# ../hosts/<name>/ instead. Per-host facts (disk UUIDs, the ESP, the bootloader,
# the hostname, that machine's flatpak list and printer) live there.
{
  imports = [
    ./boot.nix
    ./desktop.nix
    ./gaming.nix
    ./services.nix
    ./users.nix
    ./system.nix
    ./windscribe.nix
  ];
}
