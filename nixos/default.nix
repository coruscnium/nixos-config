# =============================================================================
# NixOS system configuration for coru.
#
# Facts this was written from, re-read off THIS machine (NixOS 26.05, kernel
# 7.2.8) after the CachyOS era. The UUIDs below are the ones that actually
# exist here; hardware.nix carries the same list with the full explanation.
#
#   UEFI, Secure Boot disabled
#   ESP        /dev/nvme2n1p1  vfat  UUID 3FAA-B683       1 GiB, mounted /boot
#   root       /dev/nvme2n1p2  btrfs UUID ed9b8b18-...    DEFAULT subvolume
#                /home -> subvol=home, /nix -> subvol=nix, same UUID
#              (no /root, /srv, /var/cache, /var/log or /var/tmp subvolumes)
#   swap       /dev/nvme2n1p3  UUID 88505ea1-...          34 GiB partition
#   data disks nvme0n1p1 -> /mnt/ssd2 (0c5412da-..., label SSD2)
#              nvme1n1p1 -> /mnt/ssd3 (fb803c53-..., label SSD3)   both btrfs
#   bootloader systemd-boot TODAY; this config targets Limine
#   CPU        Ryzen 7 7800X3D (znver4)
#   GPU        Radeon RX 9070 XT (Navi 48, RDNA4) -- needs a recent kernel+mesa
#   DM         sddm is running today; this config targets plasma-login-manager
#   TZ         America/Chicago
#   shell      zsh (this config); the stock install used bash
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
