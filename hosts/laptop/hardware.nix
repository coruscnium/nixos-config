{ lib, ... }:

# ASUS ProArt PX13 (HN7306WU): Ryzen AI 9 HX 370, Radeon 890M iGPU, AD107M
# RTX 4050 Max-Q. Disk and ESP facts come from the installer's own
# hardware-configuration.nix, not from inference.
{
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/2b7a387e-ae79-4f05-8258-dc83c26980f6";
      fsType = "btrfs";
    };

    "/home" = {
      device = "/dev/disk/by-uuid/2b7a387e-ae79-4f05-8258-dc83c26980f6";
      fsType = "btrfs";
      options = [ "subvol=home" ];
    };

    "/nix" = {
      device = "/dev/disk/by-uuid/2b7a387e-ae79-4f05-8258-dc83c26980f6";
      fsType = "btrfs";
      options = [ "subvol=nix" ];
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/BD31-2BA2";
      fsType = "vfat";
      options = [
        "fmask=0077"
        "dmask=0077"
      ];
    };
  };

  swapDevices = [
    { device = "/dev/disk/by-uuid/6e1c8923-43c2-410e-bf68-29c6c49d2646"; }
  ];

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "thunderbolt"
    "usb_storage"
    "usbhid"
    "sd_mod"
    "sdhci_pci"
  ];
  boot.kernelModules = [ "kvm-amd" ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  hardware.cpu.amd.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;

  # Strix Point. Mesa/vulkan drives the panel; the dGPU is offload-only.
  hardware.graphics.enable = true;

  # AD107M at c4:00.0, iGPU at c5:00.0. The bus-ID options take DECIMAL while
  # lspci prints hex: 0xc4 = 196, 0xc5 = 197.
  services.xserver.videoDrivers = [
    "nvidia"
    "amdgpu"
  ];
  hardware.nvidia = {
    # The default for driver >= 560 is `null`, and nvidia.nix asserts on a
    # Boolean. AD107 is Turing-or-newer, so the open module is the right one.
    open = true;
    modesetting.enable = true;
    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
      nvidiaBusId = "PCI:196:0:0";
      amdgpuBusId = "PCI:197:0:0";
    };
  };
}
