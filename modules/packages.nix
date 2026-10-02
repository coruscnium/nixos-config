{ pkgs, ... }:

{
  # Brave Origin has no nixpkgs package (Brave only publishes the stable Origin
  # artifact for 1.97.53), so it is vendored in ../pkgs/brave-origin.nix and
  # exposed to the whole pkgs set.
  nixpkgs.overlays = [
    (final: prev: {
      braveOrigin = final.callPackage ../pkgs/brave-origin.nix { };
    })
  ];

  # System-wide only. User-facing applications live in home/coru.nix
  # (home-manager) — keep this list to what root or every user needs.
  environment.systemPackages = with pkgs; [
    git
    pciutils
    usbutils
    lm_sensors
    brightnessctl
    inxi
  ];
}
