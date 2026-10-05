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
