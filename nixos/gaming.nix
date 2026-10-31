{ pkgs, ... }:

# The basic gaming stack: every machine gets Steam, CachyOS Proton as its compat
# tool, the udev rules for Steam hardware, and the 32-bit graphics stack a Wine
# prefix needs. Desk-bound extras -- VR (hosts/coru/vr.nix) and the game
# launchers/modders (modules/gaming.nix) -- are not shared.
{
  programs.steam = {
    enable = true;

    # CachyOS Proton (SLR, x86-64-v3 for znver4) as a Steam compat tool (chaotic-nyx).
    extraCompatPackages = [ pkgs.proton-cachyos_x86_64_v3 ];

    # mangohud must sit INSIDE Steam's FHS sandbox, which cannot see the host
    # profile. The user-facing copy is programs.mangohud in modules/gaming.nix --
    # two consumers, not a duplicate.
    extraPackages = [ pkgs.mangohud ];

    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = false;
  };

  programs.gamemode.enable = true;
  programs.gamescope.enable = true;

  # steam-devices: udev rules for the Steam Controller / HTC Vive and the
  # hidraw+uinput devices Steam's input stack creates.
  hardware.steam-hardware.enable = true;

  hardware.graphics.enable32Bit = true;
}
