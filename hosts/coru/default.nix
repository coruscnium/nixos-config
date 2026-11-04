# The desktop. Everything shared across machines is in ../../nixos/; this
# directory holds only what is true of this box and no other -- disk UUIDs, the
# ESP, the bootloader that owns it, its peripherals, the VR stack, its flatpak
# list, and the printer container.
{
  pkgs,
  ...
}:

{
  imports = [
    ../../nixos
    ./hardware.nix
    ./boot.nix
    ./peripherals.nix
    ./vr.nix
    ./flatpaks.nix
    ./octoeverywhere.nix
  ];

  networking.hostName = "coru";
  system.stateVersion = "25.11";

  # Only this one helper is passwordless. pkgs.usb-port-power-cycle is defined in
  # the overlay so this rule and the watchdog wrapper pin the same path.
  security.sudo.extraRules = [
    {
      users = [ "coru" ];
      commands = [
        {
          command = "${pkgs.usb-port-power-cycle}/bin/usb-port-power-cycle";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
