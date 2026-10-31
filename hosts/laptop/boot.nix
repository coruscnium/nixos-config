{ lib, pkgs, ... }:

# Limine on the installer's 1 GiB ESP -- the same loader as the desktop. Shared
# boot policy (derived rootflags, gc, kernel params) comes from ../../nixos/boot.nix.
{
  boot.loader.limine = {
    enable = lib.mkDefault true;
    efiSupport = lib.mkDefault true;
    efiInstallAsRemovable = lib.mkDefault false;
    maxGenerations = lib.mkDefault 3;
  };

  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
  boot.loader.timeout = 5;

  # Same CoruscOS branding as the desktop, minus its ultrawide wallpaper and
  # pinned 3440x1440 interface: this is a 2.8K panel, so Limine runs at whatever
  # mode the firmware hands it rather than blitting a resampled image.
  boot.loader.limine.style = {
    interface = {
      branding = "CoruscOS";
      brandingColor = "B79BF0";
      helpColor = "8E7BB8";
      helpColorBright = "C9A9F5";
    };
    graphicalTerminal = {
      foreground = "D8CBEF";
      brightForeground = "EDE4FF";
      background = "800F0325";
      brightBackground = "532678";
      palette = "0F0325;C05A7A;7FB58A;B08A5A;7A6FD0;B06FD0;6FB5C0;8E7BB8";
      brightPalette = "4A3A6B;E5809D;A6D4AE;E0C98A;9E93F0;D2A0F5;9AD4DE;EDE4FF";
    };
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.plymouth.enable = true;
  boot.plymouth.logo = ../../boot/plymouth-logo.png;
}
