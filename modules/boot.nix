{ lib, ... }:

{
  # Limine replaces the installer-default systemd-boot. We deliberately leave
  # the existing systemd-boot EFI entry on the ESP until Limine is confirmed
  # booting, so a bad install still has something to fall back to.
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.limine = {
    enable = true;
    maxGenerations = 10;
    # Editing entries at the menu would allow `init=/bin/sh` root access.
    enableEditor = false;
  };

  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 5;
}
