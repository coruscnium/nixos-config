{
  config,
  lib,
  pkgs,
  ...
}:

# System services that need root / a system daemon / global state.
{
  networking.networkmanager.enable = true;

  # NextDNS over DoH via the official client. The module only runs `nextdns run`
  # (listening on 127.0.0.1:53) and never touches resolv.conf, so the resolver
  # wiring is on us; NM owns resolv.conf here, hence `dns = "none"`.
  #
  # The client's own defaults are cache-size 0 (cache off) and 32 inflight
  # upstream requests, and it fails extra requests instantly rather than queuing
  # them. Warframe's launcher opens ~48 connections to one CDN host in the same
  # millisecond; the over-32 ones got SERVFAIL, Wine surfaced
  # ERROR_WINHTTP_NAME_NOT_RESOLVED, and the launcher blacklisted the host for 60s
  # and declared the update failed. Measured 2026-11-03: 50 parallel lookups at
  # defaults -> 18 SERVFAIL; with the two flags below -> 0, second wave cached.
  services.nextdns = {
    enable = true;
    arguments = [
      "-profile"
      "a8561e"
      "-cache-size"
      "10MB"
      "-max-inflight-upstream-requests"
      "128"
    ];
  };
  networking.networkmanager.dns = "none";
  networking.nameservers = [ "127.0.0.1" ];

  virtualisation.docker.enable = true;

  # Flatpak is machine policy; the per-host app list lives in flatpaks.nix. It
  # has to be here, not there: the laptop declares no apps but still needs the
  # tooling. Without this, flatpak ships no org.freedesktop.Flatpak session
  # helper, and Warehouse (a home package on both hosts) fails every action with
  # "Portal call failed: The name is not activatable" -- it drives flatpak
  # entirely through `flatpak-spawn --host`, which needs that bus name.
  services.flatpak.enable = true;

  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
  };
  services.fstrim.enable = true;

  # Runs as coru, not the default `syncthing` system user: /home/coru is 0700, so
  # that user cannot even traverse into it, let alone read the vault. dataDir and
  # configDir move out of /var/lib/syncthing for the same reason.
  services.syncthing = {
    enable = true;
    user = "coru";
    group = "users";
    dataDir = "/home/coru/.local/state/syncthing";
    configDir = "/home/coru/.config/syncthing";
    # LAN sync: TCP/UDP 22000 for transfers, UDP 21027 for discovery.
    openDefaultPorts = true;
  };
  services.tailscale.enable = true;

  # Models live under /var/lib/ollama (not the old ~/.ollama).
  services.ollama.enable = true;

  # rustland, the module default. It schedules from userspace and cancels itself
  # when a runnable task goes 5s unscheduled -- that killed a full-core compile
  # on 2026-10-27. bpfland (same algorithm, in BPF) was tried instead and
  # stuttered system-wide, so this is deliberately back on rustland.
  services.scx.enable = true;
  services.psd.enable = true;

  # Deliberately no gnome-keyring: KWallet (ksecretd) is the Secret Service on
  # Plasma. Running both made the D-Bus provider a boot race, and Electron
  # safeStorage keys are tied to whichever daemon answered first (broke Tuta).
  services.fwupd.enable = true;
}
