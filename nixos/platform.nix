{ lib, ... }:

# Platform baseline: true of every host this flake targets -- x86_64, an AMD CPU,
# firmware + Mesa. Kept on lib.mkDefault so a future Intel, ARM or headless box
# overrides a line here instead of silently inheriting something wrong.
{
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  hardware.cpu.amd.updateMicrocode = lib.mkDefault true;
  hardware.enableRedistributableFirmware = lib.mkDefault true;
  hardware.graphics.enable = lib.mkDefault true;

  # mkAfter, not mkDefault: a list option that gets a normal definition elsewhere
  # would otherwise swallow the default and silently drop KVM.
  boot.kernelModules = lib.mkAfter [ "kvm-amd" ];
}
