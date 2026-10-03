# =============================================================================
# NixOS system configuration for coru.
#
# This is the target of the migration. Nothing here touches the CachyOS install
# until you actually boot it; the standalone home-manager config
# (homeConfigurations.coru) keeps working on CachyOS in the meantime.
#
# Facts this was written from, all read off the running CachyOS system:
#   UEFI, Secure Boot disabled
#   ESP        /dev/nvme2n1p1  vfat  UUID BC66-E13C        mounted /boot
#   root       /dev/nvme2n1p2  btrfs UUID 08a86259-...     subvol @
#   data disks nvme0n1p1 -> /mnt/ssd2, nvme1n1p1 -> /mnt/ssd3 (btrfs)
#   bootloader Limine 9.3.4 on the ESP
#   CPU        Ryzen 7 7800X3D (znver4)
#   GPU        Radeon RX 9070 XT (Navi 48, RDNA4) -- needs a recent kernel+mesa
#   DM         plasmalogin.service (Plasma Login Manager), NOT sddm
#   TZ         America/Chicago
#   shell      zsh
# =============================================================================

{ config, pkgs, lib, ... }:

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
    ./vm.nix
  ];
}
