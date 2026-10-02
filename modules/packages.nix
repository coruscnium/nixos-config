{ pkgs, inputs, ... }:

{
  # NUR (nix-community/user-repository) provides packages nixpkgs lacks —
  # Brave Origin lives there. It's built/maintained by its own CI, so it moves
  # with `nix flake update` alongside everything else.
  nixpkgs.overlays = [ inputs.nur.overlays.default ];

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
