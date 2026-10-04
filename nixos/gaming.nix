{ config, lib, pkgs, ... }:

# System-level gaming glue ONLY.
#
# The apps themselves (lutris, heroic, prismlauncher, r2modman, winboat,
# protonup-qt, protonplus, protontricks, reigntweak, pince, mangohud, goverlay,
# vkbasalt, wine, vinegar) live in the USER config at modules/gaming.nix.
# Duplicating them here would install everything twice.
{
  programs.steam = {
    enable = true;

    # This is the point of the chaotic-nyx input: proton-cachyos installed as a
    # Steam compatibility tool, the NixOS equivalent of your
    # proton-cachyos-native.
    extraCompatPackages = [ pkgs.proton-cachyos ];

    # MangoHud has to live *inside* Steam's FHS environment: the client and the
    # games it launches run in a sandbox that cannot see the host profile (the
    # same reason the cursor theme needed its own symlink -- see
    # modules/theming.nix). extraPackages seeds it into that environment's /usr,
    # so `mangohud %command%` and MANGOHUD=1 resolve for the games. The
    # user-facing `mangohud` command for lutris / heroic / a terminal comes from
    # programs.mangohud in modules/gaming.nix -- two consumers, not a duplicate.
    # pkgs.mangohud already bundles the 32-bit build, so one package covers both.
    extraPackages = [ pkgs.mangohud ];

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
