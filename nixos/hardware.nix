{ config, lib, pkgs, ... }:

# Filesystems, CPU/GPU and firmware.
#
# Every UUID below was read off THIS machine -- /dev/disk/by-uuid, plus the
# running system's generated /etc/fstab. The old CachyOS values are gone: root
# and the ESP were recreated when NixOS was installed, and a new filesystem
# means a new UUID. The two data disks kept theirs, so they still match the
# paths the Steam libraries expect.
#
#   root    ed9b8b18-9f45-4f00-9082-7b6b85835011   nvme2n1p2  1G ESP on p1
#   ESP     3FAA-B683                               nvme2n1p1
#   swap    88505ea1-9c9c-4667-94d5-8bbce6247446   nvme2n1p3
#   SSD2    0c5412da-2b1f-4f1b-a3db-13a2ce9bdea1   nvme0n1p1  btrfs, label SSD2
#   SSD3    fb803c53-b07d-48a2-a7cb-fedbe9a5b7d4   nvme1n1p1  btrfs, label SSD3
#
# The subvolume set also changed. CachyOS used @nixos/@home/@root/@srv/@cache/
# @log/@tmp; this install has only `home` and `nix`, with root on the DEFAULT
# subvolume. There is deliberately no /root, /srv, /var/cache, /var/log or
# /var/tmp entry -- those subvolumes do not exist here, and declaring them
# would fail to mount at boot.
{
  fileSystems = {
    # NOTE: NO subvol= option here, and that is load-bearing. This install's
    # root is the btrfs DEFAULT subvolume. boot.nix only emits rootflags= when
    # it finds a subvol= option on this entry, so leaving it bare is what keeps
    # the kernel command line correct. Adding subvol=@ here would make the
    # initrd look for a subvolume that does not exist.
    # NOTE: no `x-initrd.mount` here either -- NixOS adds it to / and /nix on
    # its own (verified: the installer's generated config listed no options for
    # /, yet its fstab still carried x-initrd.mount). Specifying it by hand just
    # duplicates the flag.
    "/" = {
      device = "/dev/disk/by-uuid/ed9b8b18-9f45-4f00-9082-7b6b85835011";
      fsType = "btrfs";
    };

    "/home" = {
      device = "/dev/disk/by-uuid/ed9b8b18-9f45-4f00-9082-7b6b85835011";
      fsType = "btrfs";
      options = [ "subvol=home" ];
    };

    "/nix" = {
      device = "/dev/disk/by-uuid/ed9b8b18-9f45-4f00-9082-7b6b85835011";
      fsType = "btrfs";
      options = [ "subvol=nix" ];
    };

    # 1 GiB, and NOT shared with a second OS any more -- so the bootloader can
    # use it freely. umask=0077 mirrors what the installer generated.
    "/boot" = {
      device = "/dev/disk/by-uuid/3FAA-B683";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

    # ---- The two 1.8T data disks ------------------------------------------
    # Mounted at the same paths the old config used, so the Steam libraries at
    # /mnt/ssd2/Games/Steam and /mnt/ssd3/Games/Steam keep resolving.
    # nofail: an unplugged disk must not block boot.
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

  # A real 34G swap partition exists on this machine, so use it. (The old
  # config had swapDevices = [] because CachyOS was zram-only.) zram still runs
  # and takes priority, so this is spillover rather than the primary swap.
  swapDevices = [
    { device = "/dev/disk/by-uuid/88505ea1-9c9c-4667-94d5-8bbce6247446"; }
  ];
  zramSwap.enable = true;

  # ---- initrd / kernel modules, taken from the generated config ------------
  boot.initrd.availableKernelModules = [
    "nvme"
    "ahci"
    "xhci_pci"
    "usbhid"
    "uas"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  hardware.cpu.amd.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;

  # ---- GPU: Radeon RX 9070 XT (Navi 48 / RDNA4) ----------------------------
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
}
