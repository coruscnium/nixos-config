{ pkgs, ... }:

# KDE Plasma 6 applications and Qt theming. Qt6-era packages live under
# pkgs.kdePackages; the bare names are throwing aliases.
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

    micro # terminal editor, preferred sudoedit
    wallpaper-engine-kde-plugin # pkgs/wallpaper-engine.nix (CaptSilver fork)
  ];

  # Vendored Plasma additions, referenced from the repo instead of hand-installed.
  home.file = {
    ".local/share/plasma/plasmoids/com.owljet.simpleweather".source =
      ../plasma-widgets/plasma-simple-weather;

    # Dir name must match the script's metadata Id.
    ".local/share/kwin/scripts/movewindowtodesktop".source = ../kwin-scripts/move-window-to-desktop;
  };

  # The script ships EnabledByDefault=false, so KWin has to be told to load it.
  programs.plasma.configFile."kwinrc"."Plugins".movewindowtodesktopEnabled = true;
}
