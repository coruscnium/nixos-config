{ inputs, pkgs, ... }:

{
  nixpkgs.overlays = [ inputs.nix-cachyos-kernel.overlays.pinned ];

  # `latest` is the flagship CachyOS-patched kernel (generic x86-64 build, so
  # it's fully served by the binary cache). Other variants are exposed under
  # `pkgs.cachyosKernels`, e.g. "linuxPackages-cachyos-lts" for the LTS base or
  # "linuxPackages-cachyos-latest-zen4" for a -march=znver4 build.
  boot.kernelPackages = pkgs.cachyosKernels."linuxPackages-cachyos-latest";

  boot.kernelParams = [
    # Strix Point runs best on the active P-state driver.
    "amd_pstate=active"
  ];
}
