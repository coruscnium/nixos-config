{
  config,
  lib,
  pkgs,
  ...
}:

# System services that need root / a system daemon / global state.
{
  networking.networkmanager.enable = true;
  networking.firewall.allowedTCPPorts = [ 1883 ]; # OctoEverywhere MQTT relay

  # NextDNS over DoH via the official client. The module only runs `nextdns run`
  # (listening on 127.0.0.1:53) and never touches resolv.conf, so the resolver
  # wiring is on us; NM owns resolv.conf here, hence `dns = "none"`.
  services.nextdns = {
    enable = true;
    arguments = [
      "-profile"
      "a8561e"
    ];
  };
  networking.networkmanager.dns = "none";
  networking.nameservers = [ "127.0.0.1" ];

  virtualisation.docker.enable = true;

  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
  };
  services.fstrim.enable = true;

  services.syncthing.enable = true;
  services.tailscale.enable = true;

  # Models live under /var/lib/ollama (not the old ~/.ollama).
  services.ollama.enable = true;

  services.scx.enable = true;
  services.psd.enable = true;

  # Apps are declared here; nix-flatpak installs/removes them on activation.
  # Hand-installed flatpaks are left alone (uninstallUnmanaged off).
  services.flatpak = {
    enable = true;
    packages = [
      "org.vinegarhq.Sober"
      "app.fluxer.Fluxer"
      "com.github.tchx84.Flatseal"
      "com.stremio.Stremio"
      "com.unity.UnityHub"
      "com.usebottles.bottles"
      "io.github.loot.loot"
      "io.gitlab.adhami3310.Footage"
      "org.nickvision.tubeconverter"
      "org.onlyoffice.desktopeditors"
      "org.upscayl.Upscayl"
      "page.codeberg.libre_menu_editor.LibreMenuEditor"
    ];

    # Sober (Roblox) needs the Discord IPC socket + an input device or it comes up
    # a black window. writeMode defaults to "merge".
    overrides.settings."org.vinegarhq.Sober".Context = {
      filesystems = [
        "xdg-run/app/com.discordapp.Discord:create"
        "xdg-run/discord-ipc-0"
      ];
      devices = [ "input" ];
    };
  };

  services.gnome.gnome-keyring.enable = true;
  services.fwupd.enable = true;
}
