{ config, lib, pkgs, ... }:

let
  # ===========================================================================
  # WHICH SUBVOLUME NIXOS TAKES OVER -- READ THIS BEFORE INSTALLING.
  #
  #   "@nixos"  a NEW subvolume, side by side with CachyOS. CachyOS is left
  #             completely untouched and you keep booting it. THIS IS THE
  #             CURRENT VALUE -- it is what you install into.
  #
  #   "@"       the CachyOS root itself. Installing here REPLACES its /etc and
  #             takes over the system -- CachyOS stops booting. This is the
  #             END state, after you are satisfied.
  #
  # Create the new subvolume with:
  #   sudo mkdir -p /mnt/btrfs
  #   sudo mount -o subvolid=5 /dev/nvme2n1p2 /mnt/btrfs
  #   sudo btrfs subvolume create /mnt/btrfs/@nixos
  #
  # boot.nix derives rootflags= from this same value automatically, so the
  # config and the kernel command line cannot disagree.
  # ===========================================================================
  rootSubvol = "@nixos";
in

# Filesystems, CPU/GPU and firmware. Every UUID and option here is copied from
# /etc/fstab on the CachyOS install, so this describes the SAME disk layout --
# which is what makes installing NixOS into a new subvolume possible without
# touching /home.
{
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/08a86259-d4d2-4bc9-b8c6-24da18aa2adb";
      fsType = "btrfs";
      options = [ "subvol=${rootSubvol}" "noatime" "compress=zstd" "commit=120" ];
    };
    "/home" = {
      device = "/dev/disk/by-uuid/08a86259-d4d2-4bc9-b8c6-24da18aa2adb";
      fsType = "btrfs";
      options = [ "subvol=@home" "noatime" "compress=zstd" "commit=120" ];
    };
    "/root" = {
      device = "/dev/disk/by-uuid/08a86259-d4d2-4bc9-b8c6-24da18aa2adb";
      fsType = "btrfs";
      options = [ "subvol=@root" "noatime" "compress=zstd" "commit=120" ];
    };
    "/srv" = {
      device = "/dev/disk/by-uuid/08a86259-d4d2-4bc9-b8c6-24da18aa2adb";
      fsType = "btrfs";
      options = [ "subvol=@srv" "noatime" "compress=zstd" "commit=120" ];
    };
    "/var/cache" = {
      device = "/dev/disk/by-uuid/08a86259-d4d2-4bc9-b8c6-24da18aa2adb";
      fsType = "btrfs";
      options = [ "subvol=@cache" "noatime" "compress=zstd" "commit=120" ];
    };
    "/var/log" = {
      device = "/dev/disk/by-uuid/08a86259-d4d2-4bc9-b8c6-24da18aa2adb";
      fsType = "btrfs";
      options = [ "subvol=@log" "noatime" "compress=zstd" "commit=120" ];
    };
    "/var/tmp" = {
      device = "/dev/disk/by-uuid/08a86259-d4d2-4bc9-b8c6-24da18aa2adb";
      fsType = "btrfs";
      options = [ "subvol=@tmp" "noatime" "compress=zstd" "commit=120" ];
    };

    # The SHARED ESP. umask=0077 mirrors the CachyOS fstab.
    "/boot" = {
      device = "/dev/disk/by-uuid/BC66-E13C";
      fsType = "vfat";
      options = [ "umask=0077" ];
    };

    # Two other NVMe drives. KEEP THESE PATHS: the Steam libraries are
    # /mnt/ssd2/Games/Steam (1.7T) and /mnt/ssd3/Games/Steam (341G).
    # nofail so an unplugged disk cannot block boot.
    "/mnt/ssd2" = {
      device = "/dev/disk/by-uuid/0c5412da-2b1f-4f1b-a3db-13a2ce9bdea1";
      fsType = "btrfs";
      options = [ "noatime" "nodatacow" "nofail" ];
    };
    "/mnt/ssd3" = {
      device = "/dev/disk/by-uuid/fb803c53-b07d-48a2-a7cb-fedbe9a5b7d4";
      fsType = "btrfs";
      options = [ "noatime" "nodatacow" "nofail" ];
    };
  };

  swapDevices = [ ];
  zramSwap.enable = true;                       # CachyOS had 30.9G of zram

  hardware.cpu.amd.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;

  # ---- GPU: Radeon RX 9070 XT (Navi 48 / RDNA4) -----------------------------
  # mesa + vulkan + radeonsi come from hardware.graphics.enable.
  hardware.graphics = {
    enable = true;
    # ROCm/HIP for Blender Cycles, DaVinci Resolve, LM Studio. RDNA4 is gfx1201
    # and needs a recent ROCm. If any of these fail to evaluate, drop it -- the
    # mesa/vulkan path is what the desktop actually uses.
    extraPackages = with pkgs; [
      rocmPackages.clr
      rocmPackages.rocm-runtime
      rocmPackages.rocminfo
    ];
  };

  # v4l2loopback was only for phonecam, which is dropped -- and a kernel-module
  # package has to match the cachyos kernel set exactly. Uncomment if you want
  # your phone as a webcam again:
  #   boot.kernelModules = [ "v4l2loopback" ];
  #   boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
}
