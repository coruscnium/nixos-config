{
  pkgs,
  lib,
  config,
  ...
}:

# The Carl suite plus our GTK port. Carl comes from pling/KDE Store, which serves
# a bot challenge, so it is vendored under ../themes rather than fetched. KDE
# rewrites kdeglobals/kwinrc/plasmarc, so those go through plasma-manager
# (kwriteconfig); GTK only reads its css, so those are plain symlinks.
let
  themes = ../themes;
in
{
  home.packages = with pkgs; [
    kdePackages.qtstyleplugin-kvantum
  ];

  home.file = {
    ".local/share/plasma/look-and-feel/Carl".source = "${themes}/look-and-feel-Carl";
    ".local/share/plasma/desktoptheme/Carl".source = "${themes}/desktoptheme-Carl";
    ".local/share/aurorae/themes/Carl".source = "${themes}/aurorae-Carl";
    ".local/share/color-schemes/Carl.colors".source = "${themes}/Carl.colors";
    ".local/share/konsole/Carl.colorscheme".source = "${themes}/Carl.colorscheme";

    ".config/Kvantum/Carl".source = "${themes}/kvantum-Carl";
    ".config/Kvantum/kvantum.kvconfig".text = ''
      [General]
      theme=Carl
    '';

    ".local/share/themes/Carl".source = "${themes}/gtk-Carl";

    # gtk.css imports these by relative name, so each tree needs its own copy
    # beside it -- the duplication is load-bearing, not accidental.
    ".config/gtk-3.0/settings.ini".source = "${themes}/gtk-3.0/settings.ini";
    ".config/gtk-3.0/gtk.css".source = "${themes}/gtk-3.0/gtk.css";
    ".config/gtk-3.0/carl.css".source = "${themes}/gtk-3.0/carl.css";
    ".config/gtk-3.0/colors.css".source = "${themes}/gtk-3.0/colors.css";
    ".config/gtk-3.0/thunar.css".source = "${themes}/gtk-3.0/thunar.css";
    ".config/gtk-4.0/settings.ini".source = "${themes}/gtk-4.0/settings.ini";
    ".config/gtk-4.0/gtk.css".source = "${themes}/gtk-4.0/gtk.css";
    ".config/gtk-4.0/carl.css".source = "${themes}/gtk-4.0/carl.css";
    ".config/gtk-4.0/colors.css".source = "${themes}/gtk-4.0/colors.css";
    ".config/gtk-4.0/thunar.css".source = "${themes}/gtk-4.0/thunar.css";

    # Steam's client UI (Chromium under pressure-vessel) reads cursor FILES from
    # XCURSOR_PATH and cannot see /run/current-system or /etc/profiles, so Bibata
    # must sit in a dir that is bind-mounted into the sandbox. Chromium never
    # reads XCURSOR_THEME -- the symlink is the only thing that works.
    ".local/share/icons/Bibata-Modern-Classic".source =
      "${pkgs.bibata-cursors}/share/icons/Bibata-Modern-Classic";

    # force = true: a KDE GTK-sync daemon rewrites this file at runtime, so
    # without force home-manager aborts trying to back the real file up.
    ".config/xsettingsd/xsettingsd.conf" = {
      source = "${themes}/xsettingsd.conf";
      force = true;
    };
  };

  programs.plasma = {
    enable = true;

    workspace = {
      colorScheme = "Carl";
      # lookAndFeel is deliberately unset -- setting it makes plasma-manager drop
      # the explicit theme options below and apply the LNF's contents/defaults
      # (which name themes not installed here), half-theming the desktop.
      theme = "Carl";
      iconTheme = "BeautySolar"; # pkgs/beautysolar.nix
      widgetStyle = "kvantum-dark"; # kdeglobals value, not "kvantum"
      soundTheme = "ocean";
      cursor = {
        theme = "Bibata-Modern-Classic";
        size = 24;
      };
      # no splashScreen: deliberately not using a Carl splash.
    };

    # plasma-manager's typed `fonts` option has no `size`, so the real values go
    # through configFile using kdeglobals' exact encoded form.
    configFile = {
      "kwinrc"."org.kde.kdecoration2" = {
        library = "org.kde.kwin.aurorae.v2";
        # Aurorae SVG themes need this prefix -- plain "Carl" loads no titlebar.
        theme = "__aurorae__svg__Carl";
        AlwaysShowExcludeFromCapture = true;
      };

      "kwinrc"."Plugins" = {
        blurEnabled = true;
        desktopchangeosdEnabled = true;
        karouselEnabled = false;
        translucencyEnabled = true;
      };

      # encoded: family,pointsize,-1,weight,... (weight 400 = normal)
      "kdeglobals"."General" = {
        font = "Noto Sans,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,,0,0";
        fixed = "Hack,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,,0,0";
        menuFont = "Noto Sans,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,,0,0";
        smallestReadableFont = "Noto Sans,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,,0,0";
        toolBarFont = "Noto Sans,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,,0,0";
      };

      # The typed iconTheme above only applies at session restart via
      # plasma-changeicons; this applies it at activation instead.
      "kdeglobals"."Icons" = {
        Theme = "BeautySolar";
      };
    };
  };
}
