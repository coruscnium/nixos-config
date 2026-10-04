{ pkgs, ... }:

# Peripherals, monitoring and Wayland input.
#
# quadcast2s is your own package -- see pkgs/default.nix. Its udev rule is
# installed by the derivation and consumed on the NixOS side with
#   services.udev.packages = [ pkgs.quadcast2s ];
# ydotool + wl-clipboard are required by ~/.local/bin/paste-into-game.sh.
{
  home.packages = with pkgs; [
    quadcast2s
    streamcontroller               # Stream Deck; autostarts itself, kept honest
                                   # by the watchdog unit (modules/services.nix)
    solaar
    input-remapper
    lact
    openrgb
    brightnessctl
    uhubctl

    btop
    htop

    ydotool
    wl-clipboard
    wl-clip-persist
  ];
}
