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

  # Make KWin (Plasma Wayland) *render* on the NVIDIA GPU instead of the iGPU.
  # This is NOT "NVIDIA only": the internal panel is wired to the iGPU and there
  # is no MUX dGPU mode, so the iGPU still scans the frame out (reverse PRIME)
  # and the dGPU never powers down — expect a battery hit and possible
  # tearing/sync artifacts. Remove this line to go back to iGPU rendering.
  # Format: DRM devices colon-separated, preferred renderer first, by-path so
  # the order is stable across boots.
  environment.sessionVariables.KWIN_DRM_DEVICES =
    "/dev/dri/by-path/pci-0000:c4:00.0-card:/dev/dri/by-path/pci-0000:c5:00.0-card";
}
