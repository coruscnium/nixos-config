{ pkgs, ... }:

{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    # Ada (RTX 40 series) is fully supported by the open kernel modules.
    open = true;
    modesetting.enable = true;
    powerManagement.enable = true;
    dynamicBoost.enable = true;
    nvidiaSettings = true;

    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true; # provides `nvidia-offload`
      };
      nvidiaBusId = "PCI:196:0:0"; # RTX 4050 Laptop
      amdgpuBusId = "PCI:197:0:0"; # Radeon 890M (integrated)
    };
  };

  # Needed for a clean Wayland handoff on modern NVIDIA drivers.
  boot.kernelParams = [ "nvidia_drm.fbdev=1" ];
}
