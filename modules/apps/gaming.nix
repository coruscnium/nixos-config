# Gaming — system-level enablement for the "gaming" category.
#
# The user-side gaming packages live in home/packages/gaming.nix. This file is
# its system twin: home-manager can't set NixOS options like `programs.steam`,
# so those lines live here, right next to their category.
{ ... }:

{
  programs.steam.enable = true;
  hardware.steam-hardware.enable = true; # Steam Controller / VR udev rules

  # Steam/Wine also need 32-bit graphics — already on in modules/hardware.nix
  # (hardware.graphics.enable32Bit = true).
}
