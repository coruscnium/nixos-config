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
# hosts/coru/octoeverywhere.nix).
let
  hm = config.home.homeDirectory;
in
{
  # The unit below pins olsvr's store path, so it runs on both hosts regardless.
  # Listing it here keeps the binary on PATH for `olsvr run --now` -- the unit and
  # its package are one declaration, not two files that can drift.
  home.packages = [ pkgs.olsvr ];

  systemd.user.services = {
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

    # olsvr -- OLED burn-in screensaver. Idle-activated, which is exactly what a
    # VR session looks like to the desktop: input goes to the headset, so the
    # monitor sits idle and the panel blanks instead of holding a static frame.
    # Any keyboard/mouse input dismisses it. Triggered manually with
    # `olsvr run --now`.
    # Same ordering rule as input-remapper-autoload (services-desktop.nix):
    # wanted by the session target rather than ordered after it, or default.target
    # loops through the session chain again.
    olsvr = {
      Unit.Description = "olsvr OLED screensaver";
      Service = {
        ExecStart = "${pkgs.olsvr}/bin/olsvr run";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [ "graphical-session.target" ];
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
