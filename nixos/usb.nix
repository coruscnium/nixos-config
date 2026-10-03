{ config, lib, pkgs, ... }:

# =============================================================================
# REMOVABLE-MEDIA VARIANT — a self-contained NixOS you can boot from a USB stick
# while your CachyOS install sits untouched on the internal disks.
#
# Used two ways:
#   1. nixos-install into a USB stick (recommended, only real data is copied):
#        sudo nixos-install --root /mnt/usb --flake ...#coru-usb
#   2. nixos-generators -f raw-efi (a sparse disk image you dd to the stick)
#
# WHY THE WHOLE fileSystems SET IS mkForce'd BELOW:
#   hardware.nix mounts the INTERNAL btrfs subvolumes by UUID (/, /home, /root,
#   /srv, /var/cache, /var/log, /var/tmp, /mnt/ssd2, /mnt/ssd3). Inherited into a
#   USB build they are actively harmful:
#     * /home would be the CachyOS home, and home-manager would rewrite the
#       user's real dotfiles into store symlinks on a system they are only
#       TESTING;
#     * any entry without `nofail` that fails to mount drops the boot into
#       emergency mode.
#   Replacing the entire set removes all of them at once.
#
# The device names are LABELS, not /dev/sdX, because a USB stick enumerates
# differently on every boot.
# =============================================================================

{
  fileSystems = lib.mkForce {
    "/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
      options = [ "noatime" ];
    };
    "/boot" = {
      device = "/dev/disk/by-label/ESP";
      fsType = "vfat";
      options = [ "umask=0077" ];
    };
  };

  swapDevices = lib.mkForce [ ];   # no swap partition on the stick; zram still runs

  # Limine writes to the ESP it is told about, but it is built for a fixed disk
  # layout. GRUB with a REMOVABLE EFI install is the correct tool here.
  boot.loader.limine.enable = lib.mkForce false;
  # mkForce so this outranks boot.nix's Limine settings. A USB stick has its
  # own ESP and no second OS to avoid clobbering, so GRUB's removable install
  # (\EFI\BOOT\BOOTX64.EFI, no NVRAM entry) is the simplest thing that boots.
  boot.loader.grub = {
    enable = lib.mkForce true;
    device = lib.mkForce "nodev";
    efiSupport = lib.mkForce true;
    efiInstallAsRemovable = lib.mkForce true;
  };

  # CRITICAL SAFETY: never write an EFI boot entry into the firmware NVRAM.
  # Your internal ESP keeps Boot0000 (cachyos) and Boot0001 (Limine) untouched,
  # and you pick the USB from the firmware boot menu (usually F12/F11).
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  boot.initrd.supportedFilesystems = [ "ext4" "vfat" ];

  # The USB has no btrfs filesystem, and the module asserts on that.
  services.btrfs.autoScrub.enable = lib.mkForce false;

  # A test stick should not be gated on a password. Remove this line once you
  # have set a real one with `passwd`.
  services.displayManager.autoLogin = {
    enable = true;
    user = "coru";
  };

  # Used only by `nixos-generators -f raw`, ignored by nixos-install.
  virtualisation.diskSize = 40960;

  # NOTE DELIBERATELY KEPT, so the stick is a REAL test:
  #   hardware.graphics ROCm   -> the RX 9070 XT stack actually runs
  #   programs.steam           -> huge (32-bit dupes) but that is the point
  #   the OctoEverywhere container -> it can reach the printer on your LAN
}
