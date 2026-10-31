# The declared flatpak set. Split out of services.nix because it is a list of
# this machine's apps, not a service policy -- the laptop declares none.
# `services.flatpak.enable` itself is in services.nix: that is policy, and the
# laptop needs flatpak even with an empty list.
{
  # Apps are declared here; nix-flatpak installs/removes them on activation.
  # Hand-installed flatpaks are left alone (uninstallUnmanaged off).
  services.flatpak = {
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
}
