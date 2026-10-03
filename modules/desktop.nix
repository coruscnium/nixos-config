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
}
