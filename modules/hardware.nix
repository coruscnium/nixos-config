{ config, lib, pkgs, ... }:

# Peripherals, monitoring and Wayland input.
#
# quadcast2s is your own package -- see pkgs/default.nix. Its udev rule is
# installed by the derivation and consumed on the NixOS side with
#   services.udev.packages = [ pkgs.quadcast2s ];
# ydotool + wl-clipboard are required by ~/.local/bin/paste-into-game.sh.
#
# solaar and input-remapper are NOT listed here: their NixOS modules
# (nixos/desktop.nix) install the packages system-wide together with the udev
# rules and the services, so listing them again would duplicate them.
{
  home.packages = with pkgs; [
    quadcast2s
    streamcontroller               # Stream Deck; autostarts itself, kept honest
                                   # by the watchdog unit (modules/services.nix)
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

  # input-remapper rewrites its preset files and ~/.config/input-remapper-2/config.json
  # whenever you save from the GUI, so they must not be read-only store symlinks
  # (a home.file symlink would make the GUI's save fail). Seed them as REAL files
  # instead, and only when missing, so edits made in the GUI survive a rebuild.
  #
  # The preset directory is the device's group NAME. The autoload key in
  # config.json is a hardware-unique key that encodes the USB port, so the entry
  # below is best-effort -- if the preset does not load on connect, pick it once
  # in input-remapper's GUI and it writes the correct key.
  home.activation.seedInputRemapper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    cfg="$HOME/.config/input-remapper-2"
    preset="$cfg/presets/Logitech G502 X LIGHTSPEED/G502X.json"
    run mkdir -p "$(dirname "$preset")"
    [ -e "$preset" ] || run install -m644 ${../input-remapper/G502X.json} "$preset"
    [ -e "$cfg/config.json" ] || run install -m644 ${../input-remapper/config.json} "$cfg/config.json"
  '';
}
