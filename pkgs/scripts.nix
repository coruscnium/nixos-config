# The ~/.local/bin scripts, as packages. They live in the overlay (not a module)
# because modules/services.nix references them by store path.
#
# Each wrapper gets a store-path shebang and a PATH of exactly its runtime deps.
# writeShellScriptBin (not writeShellApplication) so shellcheck does not run on
# the current script bodies.
final: prev:
let
  lib = prev.lib;

  mkScript =
    {
      name,
      src,
      inputs ? [ ],
      replace ? { },
    }:
    prev.writeShellScriptBin name (
      ''
        export PATH="${lib.makeBinPath inputs}''${PATH:+:$PATH}"
      ''
      + lib.replaceStrings (builtins.attrNames replace) (builtins.attrValues replace) (
        builtins.readFile src
      )
    );

  usbPortPowerCycle = prev.writeShellScriptBin "usb-port-power-cycle" ''
    port=$(readlink -f "$1/port")
    echo 1 > "$port/disable"
    sleep 1
    echo 0 > "$port/disable"
  '';
in
{
  # Defined here so the sudoers rule (nixos/users.nix) and the watchdog wrapper
  # reference the same store path.
  usb-port-power-cycle = usbPortPowerCycle;

  script-cover-extract = mkScript {
    name = "cover-extract.sh";
    src = ../scripts/music/cover-extract.sh;
    inputs = [
      prev.ffmpeg
      prev.findutils
      prev.gawk
      prev.coreutils
    ];
  };

  script-embed-lyrics = mkScript {
    name = "embed_lyrics.sh";
    src = ../scripts/music/embed_lyrics.sh;
    inputs = [
      prev.kid3
      prev.findutils
      prev.coreutils
    ];
  };

  script-toggle-pw-control-center = mkScript {
    name = "toggle_pw_control_center.sh";
    src = ../scripts/toggle_pw_control_center.sh;
    inputs = [
      prev.pipewire-control-center
      prev.procps
    ];
  };

  script-mpv-single = mkScript {
    name = "mpv-single";
    src = ../scripts/mpv-single;
    inputs = [
      prev.mpv
      prev.socat
      prev.coreutils
    ];
  };

  # The embedded python heredoc needs dbus-python on PATH. Two /usr paths are
  # substituted: the app binary and the sudo'd usb helper.
  script-streamcontroller-watchdog = mkScript {
    name = "streamcontroller-watchdog";
    src = ../scripts/streamcontroller-watchdog;
    inputs = [
      (prev.python3.withPackages (ps: [ ps.dbus-python ]))
      prev.procps
      prev.gnugrep
      prev.coreutils
      prev.sudo
      prev.streamcontroller
      usbPortPowerCycle
    ];
    replace = {
      "APP_BIN=\"/usr/bin/streamcontroller\"" =
        "APP_BIN=\"${prev.streamcontroller}/bin/streamcontroller\"";
      "sudo /usr/local/bin/usb-port-power-cycle" = "sudo ${usbPortPowerCycle}/bin/usb-port-power-cycle";
    };
  };
}
