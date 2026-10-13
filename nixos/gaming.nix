{
  config,
  lib,
  pkgs,
  ...
}:

# System-level gaming glue only. The apps themselves live in modules/gaming.nix.
{
  programs.steam = {
    enable = true;

    # CachyOS Proton (SLR, x86-64-v3 for znver4) as a Steam compat tool (chaotic-nyx).
    extraCompatPackages = [ pkgs.proton-cachyos_x86_64_v3 ];

    # mangohud must sit INSIDE Steam's FHS sandbox, which cannot see the host
    # profile. The user-facing copy is programs.mangohud in modules/gaming.nix --
    # two consumers, not a duplicate.
    extraPackages = [ pkgs.mangohud ];

    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = false;
  };

  programs.gamemode.enable = true;
  programs.gamescope.enable = true;

  hardware.steam-hardware.enable = true;
  hardware.graphics.enable32Bit = true;

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

  # The wivrn-server wrapper is created by activation. A switch that restarts
  # this user unit can race the /run/wrappers swap and fail it with ENOENT
  # (status 127), so let the service come back on its own.
  systemd.user.services.wivrn.serviceConfig = {
    Restart = "on-failure";
    RestartSec = 5;
  };
}
