{ pkgs, ... }:

# VR is the desktop's alone -- a streamed Quest over Wi-Fi. The basic gaming
# stack Steam/Proton/steam-devices lives in ../../nixos/gaming.nix.
{
  # --- VR (WiVRn) ------------------------------------------------------------
  # WiVRn streams Monado -- an OpenXR runtime of its own -- to the Quest over
  # Wi-Fi, replacing SteamVR for it, so none of SteamVR's FHS-sandbox/`pkexec`
  # pain applies. highPriority grants CAP_SYS_NICE (AMD async reprojection) the
  # NixOS way: a security.wrappers entry set at build time, never a runtime
  # pkexec. avahi (mDNS discovery, 5353) is already on in desktop.nix; the
  # module opens WiVRn's own port.
  services.wivrn = {
    enable = true;
    openFirewall = true; # 9757 tcp+udp
    highPriority = true; # CAP_SYS_NICE: async reprojection
    autoStart = true;
    steam.importOXRRuntimes = true; # Steam games discover the WiVRn runtime

    # WayVR is the in-headset desktop overlay and app launcher.
    config = {
      enable = true;
      json.application = [ pkgs.wayvr ];
    };
  };

  # WayVR-native apps -- a browser launched from WayVR's own launcher -- run
  # inside WayVR's Smithay compositor on a second Wayland display. Copying there
  # lands in that compositor's clipboard, which Plasma never sees, while VRChat
  # reads Plasma's: paste comes up empty. Mirror text both ways so "copy a link
  # in the in-VR browser, paste it into VRChat" works.
  #
  # The unit idles until WayVR's display exists (WayVR writes it to
  # $XDG_RUNTIME_DIR/wayvr.disp only while native apps run), so it costs a
  # 1 Hz poll the rest of the time.
  systemd.user.services.wayvr-clipboard-sync = {
    description = "Mirror text between WayVR's compositor clipboard and Plasma's";
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.script-wayvr-clipboard-sync}/bin/wayvr-clipboard-sync";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  # The wivrn-server wrapper is created by activation. A switch that restarts
  # this user unit can race the /run/wrappers swap and fail it with ENOENT
  # (status 127), so let the service come back on its own.
  systemd.user.services.wivrn.serviceConfig = {
    Restart = "on-failure";
    RestartSec = 5;
  };
}
