{ pkgs, ... }:

# KDE Plasma 6 desktop applications and Qt theming.
# Qt6-era packages live under `pkgs.kdePackages`; the bare names (dolphin,
# kate, konsole, ...) are throwing aliases and no longer exist at top level.
{
  home.packages = with pkgs; [
    kdePackages.ark
    kdePackages.dolphin
    kdePackages.filelight
    kdePackages.kamoso
    kdePackages.kate
    kdePackages.kdeconnect-kde
    kdePackages.konsole
    kdePackages.okular
    kdePackages.partitionmanager
    kdePackages.spectacle
    kdePackages.qt6ct
    libsForQt5.qt5ct

    micro                          # terminal editor, preferred sudoedit

    # Plasma wallpaper plugin, built from the CaptSilver fork (pkgs/wallpaper-engine.nix).
    # Plasma finds plugins through XDG_DATA_DIRS, so a user-profile install works.
    wallpaper-engine-kde-plugin
  ];

  # Vendored Plasma additions, referenced from the repo so they are reproducible
  # instead of hand-installed into ~/.local/share.
  home.file = {
    # Simple Weather plasmoid (com.owljet.simpleweather). Plasma loads applets
    # from ~/.local/share/plasma/plasmoids/<id>.
    ".local/share/plasma/plasmoids/com.owljet.simpleweather".source =
      ../plasma-widgets/plasma-simple-weather;

    # Move the focused window to desktop N and follow it. KWin scans
    # kwin/scripts/<plugin-id>; the dir name matches the metadata Id.
    ".local/share/kwin/scripts/movewindowtodesktop".source =
      ../kwin-scripts/move-window-to-desktop;
  };

  # The script ships EnabledByDefault=false, so KWin has to be told to load it.
  programs.plasma.configFile."kwinrc"."Plugins".movewindowtodesktopEnabled = true;
}
