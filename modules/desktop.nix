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

    # The plugin's web backend (QtWebView.qml) does `import QtWebEngine` and
    # `import QtWebChannel` -- and those resolve in plasmashell's QML engine, not
    # the plugin's. plasmashell has no reason to build-depend on them, so they are
    # on none of its import paths; the profile's lib/qt-6/qml IS on the session's
    # QML2_IMPORT_PATH, so landing them here is what makes the imports resolve.
    # Do NOT instead patch the plugin to call QQmlEngine::addImportPath() from
    # initializeEngine() -- that runs mid-load and segfaults Qt 6.11's type loader.
    kdePackages.qtwebchannel
    kdePackages.qtwebengine
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
