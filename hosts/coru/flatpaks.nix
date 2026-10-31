# The desktop's flatpak set. This file is the *app list* -- enable, the update
# timer and each app's sandbox overrides are shared policy (nixos/services.nix,
# nixos/flatpaks.nix).
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
  };
}
