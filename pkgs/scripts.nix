# The ~/.local/bin scripts you actually use, as packages.
#
# These live in the OVERLAY rather than in a home-manager module because
# modules/services.nix also has to reference them by path — a systemd unit
# cannot point at something that only exists in home.packages.
#
# Attribute names avoid dots so they can be written as pkgs.script-foo; the
# installed binary keeps its original name (cover-extract.sh, etc.), so
# existing invocations and .desktop files keep working.
#
# Each wrapper gets a store-path shebang AND a PATH containing exactly its
# runtime dependencies, which is the point: a script can no longer break
# silently because something dropped out of the environment.
#
# NOTE: writeShellScriptBin + makeBinPath rather than writeShellApplication.
# The latter also runs shellcheck on every build, which would fail on the
# current script bodies. Once they are lint-clean, switching buys free linting.
final: prev:
let
  lib = prev.lib;

  mkScript =
    { name, src, inputs ? [ ], replace ? { } }:
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
  # /usr/local/bin/usb-port-power-cycle, reproduced from the CachyOS system.
  # It writes to sysfs, so it must run as root -- pair it with a sudoers rule on
  # the NixOS side (see PACKAGING-LEDGER.md). It is defined in THIS file so that
  # the watchdog wrapper and the sudoers rule reference the same store path.
  usb-port-power-cycle = usbPortPowerCycle;

  # Cover art: ffmpeg pulls the embedded image out of each album folder.
  script-cover-extract = mkScript {
    name = "cover-extract.sh";
    src = ../scripts/cover-extract.sh;
    inputs = [
      prev.ffmpeg
      prev.findutils
      prev.gawk
      prev.coreutils
    ];
  };

  # Lyrics tagging; kid3-cli does the embedding.
  script-embed-lyrics = mkScript {
    name = "embed_lyrics.sh";
    src = ../scripts/embed_lyrics.sh;
    inputs = [
      prev.kid3
      prev.findutils
      prev.coreutils
    ];
  };

  # One archiver per format, all on PATH.
  script-extract-here = mkScript {
    name = "extract-here.sh";
    src = ../scripts/extract-here.sh;
    inputs = [
      prev.gnutar
      prev.unzip
      prev.p7zip
      prev.unrar
      prev.gzip
      prev.bzip2
      prev.xz
      prev.zstd
      prev.coreutils
    ];
  };

  # Strips the Python env vars that make Electron apps misbehave.
  script-jan-clean = mkScript {
    name = "jan-clean";
    src = ../scripts/jan-clean;
    inputs = [ prev.coreutils ];
  };

  # Toggles the PipeWire control centre.
  script-toggle-pw-control-center = mkScript {
    name = "toggle_pw_control_center.sh";
    src = ../scripts/toggle_pw_control_center.sh;
    inputs = [
      prev.pipewire-control-center
      prev.procps
    ];
  };

  # Single mpv instance over an IPC socket; used by mpv-single.desktop.
  script-mpv-single = mkScript {
    name = "mpv-single";
    src = ../scripts/mpv-single;
    inputs = [
      prev.mpv
      prev.socat
      prev.coreutils
    ];
  };

  # Stream Deck watchdog. Two hardcoded paths are substituted:
  #   /usr/bin/streamcontroller            -> store path
  #   /usr/local/bin/usb-port-power-cycle  -> store path, matched by a NixOS
  #                                           sudoers rule (see PACKAGING-LEDGER)
  # The embedded python3 heredoc needs dbus-python on PATH.
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
      "sudo /usr/local/bin/usb-port-power-cycle" =
        "sudo ${usbPortPowerCycle}/bin/usb-port-power-cycle";
    };
  };
}
