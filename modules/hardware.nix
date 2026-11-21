{
  config,
  lib,
  pkgs,
  ...
}:

# Peripherals and Wayland input. solaar / input-remapper are NOT listed -- their
# NixOS modules install the packages and udev rules (nixos/desktop.nix).
{
  home.packages = with pkgs; [
    streamcontroller # autostarts itself; watchdog in services.nix
    openrgb
    brightnessctl
    ddcutil # external monitors over DDC/CI; also the CLI to verify the i2c path
    uhubctl

    btop
    htop

    ydotool
    wl-clipboard
    wl-clip-persist
  ];

  # input-remapper rewrites its config on GUI save, so these must be REAL files,
  # not store symlinks -- seed them only when missing so GUI edits survive.
  home.activation.seedInputRemapper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    cfg="$HOME/.config/input-remapper-2"
    g502="$cfg/presets/Logitech G502 X LIGHTSPEED/G502X.json"
    run mkdir -p "$(dirname "$g502")"
    [ -e "$g502" ] || run install -m644 ${../input-remapper/G502X.json} "$g502"
    [ -e "$cfg/config.json" ] || run install -m644 ${../input-remapper/config.json} "$cfg/config.json"
  '';
}
