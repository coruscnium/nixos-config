{ config, lib, pkgs, ... }:

# System-level gaming glue ONLY.
#
# The apps themselves (lutris, heroic, prismlauncher, r2modman, winboat,
# protonup-qt, protonplus, protontricks, reigntweak, cheatengine-launcher,
# pince, mangohud, goverlay, vkbasalt, wine, vinegar) live in the USER config
# at modules/gaming.nix. Duplicating them here would install everything twice.
{
  programs.steam = {
    enable = true;

    # This is the point of the chaotic-nyx input: proton-cachyos installed as a
    # Steam compatibility tool, the NixOS equivalent of your
    # proton-cachyos-native.
    extraCompatPackages = [ pkgs.proton-cachyos ];

    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = false;
  };

  programs.gamemode.enable = true;
  programs.gamescope.enable = true;

  # Controller udev rules / hidraw access for Steam Input.
  hardware.steam-hardware.enable = true;

  # Steam's 32-bit runtime needs 32-bit graphics.
  hardware.graphics.enable32Bit = true;
}
