{ pkgs, lib, config, ... }:

# =============================================================================
# Theming — the Carl suite plus your own GTK port.
#
# CARL IS UPSTREAM, NOT OURS, AND NOT IN NIXPKGS. It comes from pling/KDE Store:
#   Look-and-Feel   pling.com/p/1338881   (store.kde.org/p/1338881)
#   Kvantum theme   pling.com/p/1331615
#   Colour schemes  pling.com/p/1331616
#   Aurorae theme   pling.com/p/1331617
#   Konsole theme   pling.com/p/1331618
#   (plus store.kde.org/p/1330604)
#
# Those URLs ARE NOT AUTOMATABLE — verified, not assumed: pling.com answers a
# plain request with a bot challenge ("Making sure you're not a bot!") and its
# OCS API (ocs/v1/content/data/<id>) returns no download metadata. There is
# therefore no stable URL for fetchurl, so the themes are VENDORED under
# ./themes (3.3 MB, copied from the installed system).
#
# The GTK THEME IS A SEPARATE LOCAL PORT, not part of the store downloads.
# themes/gtk-Carl/README.md describes it as a re-implementation of jomada's
# Kvantum theme for GTK 3 / GTK 4 + libadwaita, with the palette living in
# themes/gtk-4.0/{gtk.css,colors.css}. That is the "custom GTK4 scheme".
#
# WHY THE KDE/GTK SPLIT:
#   KDE rewrites kdeglobals / kwinrc / plasmarc every time a setting changes, so
#   they must NOT be read-only store symlinks. plasma-manager applies them with
#   kwriteconfig at activation and leaves them writable (immutableByDefault
#   defaults to false). GTK only READS settings.ini and the CSS, so those are
#   symlinked normally.
# =============================================================================

let
  themes = ../themes;
in
{
  # ------------------------------------------------------ third-party pieces
  home.packages = with pkgs; [
    bibata-cursors                 # provides Bibata-Modern-Classic
                                   # (nixpkgs name is bibata-cursors, NOT
                                   # bibata-cursor-theme — that is the Arch name)
    beautyline-icons               # BeautyLine (chaotic-nyx)
    beautysolar                    # BeautySolar -- our package; nixpkgs carries
                                   # BeautyLine but not this sibling, which is
                                   # why the old iconTheme name silently failed
    kdePackages.qtstyleplugin-kvantum
  ];

  # ------------------------------------------------------- vendored theme files
  home.file = {
    # KDE / Plasma pieces
    ".local/share/plasma/look-and-feel/Carl".source = "${themes}/look-and-feel-Carl";
    ".local/share/plasma/desktoptheme/Carl".source = "${themes}/desktoptheme-Carl";
    ".local/share/aurorae/themes/Carl".source = "${themes}/aurorae-Carl";
    ".local/share/color-schemes/Carl.colors".source = "${themes}/Carl.colors";
    ".local/share/konsole/Carl.colorscheme".source = "${themes}/Carl.colorscheme";

    # Kvantum reads user themes from ~/.config/Kvantum/<name>
    ".config/Kvantum/Carl".source = "${themes}/kvantum-Carl";
    ".config/Kvantum/kvantum.kvconfig".text = ''
      [General]
      theme=Carl
    '';

    # The local GTK port
    ".local/share/themes/Carl".source = "${themes}/gtk-Carl";

    # GTK reads these; nothing writes them, so read-only symlinks are correct.
    ".config/gtk-3.0/settings.ini".source = "${themes}/gtk-3.0/settings.ini";
    ".config/gtk-3.0/gtk.css".source = "${themes}/gtk-3.0/gtk.css";
    ".config/gtk-4.0/settings.ini".source = "${themes}/gtk-4.0/settings.ini";
    ".config/gtk-4.0/gtk.css".source = "${themes}/gtk-4.0/gtk.css";
    ".config/gtk-4.0/carl.css".source = "${themes}/gtk-4.0/carl.css";
    ".config/gtk-4.0/colors.css".source = "${themes}/gtk-4.0/colors.css";
    ".config/gtk-4.0/thunar.css".source = "${themes}/gtk-4.0/thunar.css";

    # Mirrors the GTK settings for non-GTK toolkits
    ".config/xsettingsd/xsettingsd.conf".source = "${themes}/xsettingsd.conf";
  };

  # ------------------------------------------- KDE settings (kwriteconfig)
  programs.plasma = {
    enable = true;

    workspace = {
      colorScheme = "Carl";
      # lookAndFeel is deliberately NOT set. plasma-manager treats it as
      # mutually exclusive with the individual theme options below: with it set,
      # it stops writing colorScheme/iconTheme/cursor/plasmarc and instead runs
      # `plasma-apply-lookandfeel -a Carl` at login. That applies the vendored
      # LNF's contents/defaults, which still names themes that are NOT installed
      # here (WhiteSur-cursors, kora) and a decoration library that disagrees
      # with the kwinrc block further down -- so the explicit settings below get
      # discarded and the desktop comes up half-themed.
      #
      # plasma-manager's own warning (modules/workspace.nix:411) says the same:
      # "Setting lookAndFeel together with ... windowDecorations ... is not
      # recommended since lookAndFeel themes often override these settings."
      #
      # If you ever want the LNF back, fix themes/look-and-feel-Carl/contents/
      # defaults FIRST so it names Bibata/BeautyLine and org.kde.kwin.aurorae.v2.
      theme = "Carl";                  # Plasma desktop theme (plasmarc)
      iconTheme = "BeautySolar";       # provided by pkgs/beautysolar.nix.
                                       # nixpkgs' beautyline-icons supplies only
                                       # BeautyLine, so asking for BeautySolar
                                       # used to fail silently AND leave
                                       # plasma-manager's login script unable to
                                       # stamp itself complete.
      # kdeglobals says kvantum-dark, not "kvantum"
      widgetStyle = "kvantum-dark";
      soundTheme = "ocean";
      # renamed from cursorTheme -> cursor.theme in plasma-manager
      cursor = {
        theme = "Bibata-Modern-Classic";
        size = 24;
      };
      # NOTE: no splashScreen here. ksplashrc says org.kde.breeze.desktop —
      # you are deliberately NOT using a Carl splash.
    };

    # NOTE: plasma-manager's typed `fonts` option has no `size` field (only
    # family/style/stretch), so the real font settings go through configFile
    # below, using the exact encoded values from kdeglobals [General].

    # Everything else, read verbatim from the running system. plasma-manager
    # does not model these as typed options, and configFile is the supported
    # escape hatch.
    configFile = {
      "kwinrc"."org.kde.kdecoration2" = {
        library = "org.kde.kwin.aurorae.v2";
        # NOT plain "Carl". Aurorae SVG themes are addressed with this prefix;
        # with "Carl" the decoration fails to load and windows come up with no
        # titlebar at all. This is the pair the running (working) session uses.
        theme = "__aurorae__svg__Carl";
        AlwaysShowExcludeFromCapture = true;
      };

      "kwinrc"."Plugins" = {
        blurEnabled = true;
        desktopchangeosdEnabled = true;
        karouselEnabled = false;
        translucencyEnabled = true;
        "window-to-desktop-followEnabled" = true;
      };

      # Exact font values from kdeglobals [General]. The encoded form is
      # family,pointsize,-1,weight,... (weight 400 = normal).
      "kdeglobals"."General" = {
        font = "Noto Sans,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,,0,0";
        fixed = "Hack,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,,0,0";
        menuFont = "Noto Sans,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,,0,0";
        smallestReadableFont = "Noto Sans,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,,0,0";
        toolBarFont = "Noto Sans,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,,0,0";
      };
    };
  };
}
