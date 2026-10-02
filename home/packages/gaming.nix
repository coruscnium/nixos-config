# Gaming — user-level packages.
#
# The system-side bits (Steam, udev rules) live in modules/apps/gaming.nix.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # lutris
    # heroic
    # mangohud
    # gamescope
  ];
}
