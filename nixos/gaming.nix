{ config, lib, pkgs, ... }:

# System-level gaming glue only. The apps themselves live in modules/gaming.nix.
{
  programs.steam = {
    enable = true;

    # proton-cachyos as a Steam compat tool (chaotic-nyx).
    extraCompatPackages = [ pkgs.proton-cachyos ];

    # mangohud must sit INSIDE Steam's FHS sandbox, which cannot see the host
    # profile. The user-facing copy is programs.mangohud in modules/gaming.nix --
    # two consumers, not a duplicate.
    extraPackages = [ pkgs.mangohud ];

    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = false;
  };

  programs.gamemode.enable = true;
  programs.gamescope.enable = true;

  hardware.steam-hardware.enable = true;
  hardware.graphics.enable32Bit = true;
}
