{
  pkgs,
  ...
}:

# User units that exist for hardware on the desk: the mouse presets and the
# Stream Deck watchdog. Split out of services.nix so a machine without those
# peripherals does not carry units that can never do anything.
{
  systemd.user.services = {
    # input-remapper's daemon only autoloads once a logged-in user has told it
    # where the config lives, and at boot the peripherals are already plugged in,
    # so the udev autoload (off by default) would have fired too early. Run the
    # autoload command at session start instead -- it reads the autoload map in
    # ~/.config/input-remapper-2/config.json, so that file stays the only place
    # a device/preset pair is named. A wireless mouse that is off at login is
    # skipped silently and picked up on the next autoload.
    #
    # WantedBy=graphical-session.target, NOT default.target + After=graphical-session.target.
    # A target orders after everything it wants, so that pair closed a loop
    # (default.target -> this unit -> the session -> plasma-core -> drkonqi -> default.target)
    # and systemd broke it at every login by deleting a KDE job -- polkit agent, powerdevil,
    # xembedsniproxy, kaccess. Being wanted by the session target starts the unit with the
    # session without ordering anything after it.
    input-remapper-autoload = {
      Unit.Description = "Apply the input-remapper presets for the desk peripherals";
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.input-remapper}/bin/input-remapper-control --command autoload";
      };
      Install.WantedBy = [ "graphical-session.target" ];
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
        # The session vars (DISPLAY, WAYLAND_DISPLAY, XDG_RUNTIME_DIR, DBus) come
        # from the systemd user manager. Pinning WAYLAND_DISPLAY here is what broke
        # the watchdog: kwin came up on wayland-1 and every relaunch died on a
        # missing wayland-0 socket. The script resolves the socket per cycle.
        Environment = [ "GSK_RENDERER=ngl" ];
        ExecStart = "${pkgs.script-streamcontroller-watchdog}/bin/streamcontroller-watchdog";
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };
  };

  systemd.user.timers.streamcontroller-watchdog = {
    Unit.Description = "StreamController Watchdog — every 30 minutes";
    Timer = {
      OnActiveSec = "0";
      OnCalendar = "*:0/30";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
