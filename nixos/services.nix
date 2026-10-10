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

    # Declaring `remotes` REPLACES the module's flathub default, so flathub is
    # listed explicitly. modmanager-origin is Amethyst Mod Manager's own signed
    # repo (chrisdkn.github.io) -- the app is not on flathub. The GPG key is
    # embedded in the .flatpakrepo, so no gpg-import is needed.
    remotes = [
      {
        name = "flathub";
        location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
      }
      {
        name = "modmanager-origin";
        location = "https://chrisdkn.github.io/Amethyst-Mod-Manager/amethyst.flatpakrepo";
      }
    ];

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
      # Game mod manager. Upstream ships an AppImage too, but it is a
      # quick-sharun build whose stripped section headers break nixpkgs'
      # appimageTools offset calc, so the AppImage cannot be wrapped. Upstream's
      # flatpak is the supported managed path (its manifest grants ~ plus /mnt
      # for Steam libraries and multiarch for Proton's 32-bit wine).
      {
        appId = "io.github.Amethyst.ModManager";
        origin = "modmanager-origin";
      }
    ];

    # Weekly flatpak upgrade via a systemd timer (nix-flatpak has no per-app
    # scope, so this covers every declared app).
    update.auto.enable = true;

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
