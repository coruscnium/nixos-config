{ config, lib, pkgs, modulesPath, ... }:

# =============================================================================
# LIVE ISO VARIANT — the FULL system, compressed, on one USB stick.
#
# Use this when the target stick is too small for a real install. Your stick is
# 28.6 GB (~24 GiB usable) but the installed closure is 43.7 GiB, so a real
# install does not fit. A squashfs compresses that closure to roughly 16-22 GiB,
# which does.
#
# It is also the least destructive option that exists here:
#   * the stick is written with `dd`, or just copied onto a Ventoy stick
#   * no partitioning of anything
#   * the internal ESP, the Limine config and the NVRAM are never touched
#   * you pick the stick from the firmware boot menu
#
# The tradeoff: it is a LIVE system. / is a tmpfs overlay over the squashfs, so
# changes are lost at power-off. Perfect for answering "does NixOS drive this
# hardware and does my config come up", useless for accumulating state.
#
# Build with, no nixos-generators required:
#   nix build .#nixosConfigurations.coru-iso.config.system.build.isoImage
#   -> result/iso/nixos-*.iso
# =============================================================================

{
  imports = [ "${toString modulesPath}/installer/cd-dvd/iso-image.nix" ];

  isoImage = {
    makeEfiBootable = true;   # boot on UEFI
    makeUsbBootable = true;   # dd-able rather than CD-only
    # The whole 43.7 GiB closure goes through here.
    squashfsCompression = "zstd -Xcompression-level 15";
  };

  # THE CRITICAL LINE. iso-image.nix exposes its own complete filesystem set as
  # config.lib.isoFileSystems; forcing `fileSystems` to exactly that discards
  # every internal btrfs mount that hardware.nix declares, so the live system
  # cannot mount your CachyOS root or home.
  fileSystems = lib.mkForce config.lib.isoFileSystems;

  swapDevices = lib.mkForce [ ];

  # A live medium installs no bootloader and must never write to the NVRAM.
  boot.loader.limine.enable = lib.mkForce false;
  # An ISO carries its own boot configuration and must not run an installer.
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  # boot.nix sets 5 for the real machine's menu; iso-image.nix wants 10 so you
  # have time to pick a boot option on live media. Those two are both normal
  # priority and CONFLICT, aborting the build -- so the ISO's value wins here.
  boot.loader.timeout = lib.mkForce 10;

  # boot.nix asks for btrfs, which a squashfs live root does not need; the ISO
  # needs to find its own medium instead.
  boot.initrd.supportedFilesystems = lib.mkForce [
    "squashfs"
    "iso9660"
    "vfat"
    "ext4"
  ];

  # No btrfs here either, and the module asserts on that.
  services.btrfs.autoScrub.enable = lib.mkForce false;

  # Live media should drop straight into the desktop.
  services.displayManager.autoLogin = {
    enable = true;
    user = "coru";
  };

  # Everything else is the REAL config: Plasma 6, the Carl theme, the user
  # services, ROCm for the RX 9070 XT, Steam, LM Studio. That is the point --
  # this is a hardware test, not a cut-down demo.
}
