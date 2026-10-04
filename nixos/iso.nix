{ config, lib, pkgs, modulesPath, ... }:

# LIVE ISO VARIANT -- the full system as a squashfs image, for a stick too small
# for a real install (the closure is ~44 GiB, the stick ~24 GiB).
#
# Build: nix build .#nixosConfigurations.coru-iso.config.system.build.isoImage
{
  imports = [ "${toString modulesPath}/installer/cd-dvd/iso-image.nix" ];

  isoImage = {
    makeEfiBootable = true;
    makeUsbBootable = true;
    squashfsCompression = "zstd -Xcompression-level 15";
  };

  # Force fileSystems to the ISO's own set, discarding every internal btrfs mount
  # hardware.nix declares.
  fileSystems = lib.mkForce config.lib.isoFileSystems;

  swapDevices = lib.mkForce [ ];

  # A live medium installs no bootloader and must never write NVRAM.
  boot.loader.limine.enable = lib.mkForce false;
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  # boot.nix sets 5, iso-image.nix wants 10; both normal priority, so force.
  boot.loader.timeout = lib.mkForce 10;

  boot.initrd.supportedFilesystems = lib.mkForce [
    "squashfs"
    "iso9660"
    "vfat"
    "ext4"
  ];

  services.btrfs.autoScrub.enable = lib.mkForce false;

  services.displayManager.autoLogin = {
    enable = true;
    user = "coru";
  };

  # Everything else is the real config -- Plasma, the Carl theme, Steam, ROCm --
  # because this is a hardware test, not a cut-down demo.
}
