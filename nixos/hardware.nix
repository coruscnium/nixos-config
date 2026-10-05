{
  config,
  lib,
  pkgs,
  ...
}:

# Filesystems, CPU/GPU and firmware. UUIDs read off this machine.
#
# Root is the btrfs DEFAULT subvolume, so "/" deliberately has NO subvol= option
# (adding one would point the initrd at a subvolume that does not exist). The
# older CachyOS subvolumes (/root, /srv, /var/cache, /var/log, /var/tmp) are not
# present here and must not be declared.
{
  fileSystems = {
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

    "/boot" = {
      device = "/dev/disk/by-uuid/3FAA-B683";
      fsType = "vfat";
      options = [
        "fmask=0077"
        "dmask=0077"
      ];
    };

    # Steam libraries resolve at /mnt/ssd{2,3}/Games/Steam. nofail so an unplugged
    # disk cannot block boot.
    "/mnt/ssd2" = {
      device = "/dev/disk/by-uuid/0c5412da-2b1f-4f1b-a3db-13a2ce9bdea1";
      fsType = "btrfs";
      options = [
        "noatime"
        "nodatacow"
        "nofail"
      ];
    };

    "/mnt/ssd3" = {
      device = "/dev/disk/by-uuid/fb803c53-b07d-48a2-a7cb-fedbe9a5b7d4";
      fsType = "btrfs";
      options = [
        "noatime"
        "nodatacow"
        "nofail"
      ];
    };
  };

  swapDevices = [
    { device = "/dev/disk/by-uuid/88505ea1-9c9c-4667-94d5-8bbce6247446"; }
  ];
  zramSwap.enable = true;

  boot.initrd.availableKernelModules = [
    "nvme"
    "ahci"
    "xhci_pci"
    "usbhid"
    "uas"
    "usb_storage"
    "sd_mod"
  ];
  boot.kernelModules = [ "kvm-amd" ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  hardware.cpu.amd.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;

  # Radeon RX 9070 XT (RDNA4). ROCm for Blender Cycles / Resolve / LM Studio; the
  # desktop itself uses the mesa/vulkan path.
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      rocmPackages.clr
      rocmPackages.rocm-runtime
      rocmPackages.rocminfo
    ];
  };
}
