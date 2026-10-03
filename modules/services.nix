{ pkgs, lib, config, ... }:

# Custom systemd USER units, ported from ~/.config/systemd/user/.
#
# Every /usr/bin/... path from the originals is replaced with a store path —
# that substitution is the whole point, since on NixOS those paths do not exist.
#
# DELIBERATELY NOT PORTED:
#   lock-displays.service           excluded on your instruction
#   shelly-notifications.service    excluded (Shelly is ALPM/Arch-only)
#   pwctl-chain@.service            generated at runtime by PipeWire Controller;
#                                   hand-porting it would fight the app
#   voxtype.service                 dropped
#   hyprpolkitagent / xdg-desktop-portal-hyprland drop-ins -- Hyprland remnants
#   quadcast2s.service.d/restart.conf  written by quadcast2s-gui at runtime
#   octoeverywhere.service          moved to nixos/octoeverywhere.nix: it needs
#                                   root + Docker, so it cannot be a user unit

let
  hm = config.home.homeDirectory;
in
{
  systemd.user.services = {
    # ------------------------------------------------------------------ Stream Deck
    # Your own unit. The upstream package's unit is NOT used: this pair exists
    # because of the enumeration bug the watchdog works around.
    streamcontroller = {
      Unit = {
        Description = "StreamController";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
        StartLimitIntervalSec = 60;
        StartLimitBurst = 5;
      };
      Service = {
        Type = "simple";
        ExecStart = "${lib.getExe pkgs.streamcontroller} -b";
        Restart = "on-failure";
        RestartSec = 5;
        ExecStopPost = "-${pkgs.procps}/bin/pkill -f streamcontroller";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

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
      # No Install: it is driven by the timer below.
    };

    # --------------------------------------------------------------- QuadCast 2 S
    # Mirrors systemd/quadcast2s.service from your own repo. ExecStart keeps
    # $QUADCAST2S_ARGS unquoted so systemd splits it into separate arguments.
    quadcast2s = {
      Unit = {
        Description = "QuadCast 2 S RGB lighting";
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        Environment = [ "QUADCAST2S_ARGS=solid ff0000" ];
        EnvironmentFile = "-%h/.config/quadcast2s/service.env";
        ExecStart = "${pkgs.quadcast2s}/bin/quadcast2s --foreground --wait $QUADCAST2S_ARGS";
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install.WantedBy = [ "default.target" ];
    };

    # Started by udev via SYSTEMD_USER_WANTS in 70-quadcast2s.rules, which is
    # installed on the NixOS side with services.udev.packages = [ pkgs.quadcast2s ].
    # A no-op unless the user has opted in.
    quadcast2s-hotplug = {
      Unit = {
        Description = "Start QuadCast 2 S lighting when the microphone is connected";
        ConditionPathExists = "%h/.config/quadcast2s/start-on-connect";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.systemd}/bin/systemctl --user start quadcast2s.service";
      };
    };

    # ------------------------------------------------------------------- lsyncd
    lsyncd = {
      Unit.Description = "lsyncd mirror";
      Service = {
        ExecStart = "${pkgs.lsyncd}/bin/lsyncd -nodaemon %h/.config/lsyncd/lsyncd.conf.lua";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [ "default.target" ];
    };

    # ----------------------------------------------------------------- mcp-proxy
    # NOTE: this deliberately does NOT use pkgs.mcp-proxy. That package is a
    # different tool (stdio <-> SSE). Yours is the uv-installed PyPI package
    # whose CLI takes --port / --named-server-config. uv keeps it entirely under
    # ~/.local/share/uv (its own interpreter included), so it survives on NixOS.
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

    # ----------------------------------------------------------------- MEGA cloud
    mega-mount = {
      Unit = {
        Description = "MEGA cloud storage mount";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        Type = "simple";
        Environment = [ "PATH=${lib.makeBinPath [ pkgs.megacmd pkgs.procps pkgs.coreutils ]}" ];
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
