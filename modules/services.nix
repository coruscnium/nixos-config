{
  pkgs,
  lib,
  config,
  ...
}:

# Custom systemd USER units, ported from ~/.config/systemd/user/. Every
# /usr/bin/... path is replaced with a store path.
#
# Deliberately NOT ported: lock-displays, shelly-notifications (ALPM-only),
# pwctl-chain@ (generated at runtime by PipeWire Controller), voxtype, the
# Hyprland drop-ins, and octoeverywhere.service (needs root -- see
# nixos/octoeverywhere.nix).
let
  hm = config.home.homeDirectory;
in
{
  systemd.user.services = {
    # input-remapper's daemon only autoloads once a logged-in user has told it
    # where the config lives, and at boot the mouse is already plugged in, so the
    # udev autoload (off by default) would have fired too early. Re-apply the
    # G502X preset at session start instead -- the preset itself is seeded by
    # modules/hardware.nix from input-remapper/.
    input-remapper-autoload = {
      Unit = {
        Description = "Apply the input-remapper G502X preset";
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.input-remapper}/bin/input-remapper-control --command start --device 'Logitech G502 X LIGHTSPEED' --preset G502X";
      };
      Install.WantedBy = [ "default.target" ];
    };

    # No streamcontroller.service on purpose: StreamController autostarts itself
    # (writing ~/.config/autostart), and a second launcher races it -- the loser's
    # quit_running() fires a DBus reopen that presents the window. The watchdog
    # below pkills before it relaunches, so it never triggers a reopen.
    streamcontroller-watchdog = {
      Unit = {
        Description = "StreamController Watchdog";
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        Restart = "always";
        RestartSec = 5;
        KillMode = "process";
        Environment = [
          "DISPLAY=:0"
          "WAYLAND_DISPLAY=wayland-0"
          "XDG_RUNTIME_DIR=/run/user/1000"
          "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus"
          "GSK_RENDERER=ngl"
        ];
        ExecStart = "${pkgs.script-streamcontroller-watchdog}/bin/streamcontroller-watchdog";
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };

    lsyncd = {
      Unit.Description = "lsyncd mirror";
      Service = {
        ExecStart = "${pkgs.lsyncd}/bin/lsyncd -nodaemon %h/.config/lsyncd/lsyncd.conf.lua";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [ "default.target" ];
    };

    # NOT pkgs.mcp-proxy (a different tool). This is the uv-installed PyPI one,
    # which keeps its interpreter under ~/.local/share/uv.
    mcp-proxy = {
      Unit.Description = "Centralized MCP proxy (all stdio servers)";
      Service = {
        Type = "simple";
        Environment = [ "PATH=${hm}/.local/bin:/run/current-system/sw/bin" ];
        ExecStart = "${hm}/.local/bin/mcp-proxy --port 8000 --named-server-config ${hm}/.config/mcp-proxy/servers.json";
        Restart = "on-failure";
        RestartSec = 3;
      };
      Install.WantedBy = [ "default.target" ];
    };

    mega-mount = {
      Unit = {
        Description = "MEGA cloud storage mount";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        Type = "simple";
        Environment = [
          "PATH=${
            lib.makeBinPath [
              pkgs.megacmd
              pkgs.procps
              pkgs.coreutils
            ]
          }"
        ];
        ExecStart = "${pkgs.bash}/bin/sh -c 'mega-cmd-server & sleep 3 && mega-fuse-enable %h/MEGA && wait'";
        ExecStop = "${pkgs.bash}/bin/sh -c 'mega-fuse-disable %h/MEGA 2>/dev/null; mega-quit 2>/dev/null; pkill mega-cmd-server'";
        Restart = "on-failure";
        RestartSec = 10;
      };
      Install.WantedBy = [ "default.target" ];
    };

    mega-cache-clean = {
      Unit.Description = "Clean MEGA FUSE cache older than 7 days";
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.findutils}/bin/find %h/.megaCmd/fuse-cache/ -type f -mtime +7 -delete";
      };
    };
  };

  systemd.user.timers = {
    streamcontroller-watchdog = {
      Unit.Description = "StreamController Watchdog — every 30 minutes";
      Timer = {
        OnActiveSec = "0";
        OnCalendar = "*:0/30";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };

    mega-cache-clean = {
      Unit.Description = "Weekly MEGA FUSE cache cleanup";
      Timer = {
        OnCalendar = "weekly";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
