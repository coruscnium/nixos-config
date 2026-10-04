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
    # beautyline-icons (chaotic-nyx) is deliberately NOT installed: it ships an
    # empty BeautyLine (index.theme + a 648K cache, but the apps/devices/actions
    # dirs are empty), so anything pointing at it just renders broken fallbacks.
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
    #
    # gtk-3.0/gtk.css imports carl.css, colors.css and thunar.css by relative
    # name, so the installed dir needs all three *beside* it. The gtk-4.0 block
    # below always had them; the gtk-3.0 tree was missing them, so every GTK3
    # app logged "Theme parsing error ... Failed to import". The three files are
    # byte-identical to the gtk-4.0 copies (gtk-3.0/gtk.css is itself identical
    # to gtk-4.0/gtk.css) -- each tree keeps its own copy because the relative
    # import resolves against the importing file's own directory.
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

    # Chromium/CEF apps -- Steam's client UI -- run inside Steam's
    # pressure-vessel sandbox, which bind-mounts THIS directory but not
    # /run/current-system or /etc/profiles. Chromium finds the cursor theme NAME
    # (from GTK / Xcursor.theme) but reads the cursor FILES from the XCURSOR_PATH
    # dirs; with Bibata only visible in the store profile it finds no files,
    # falls back to the "default" theme and then to the 16px core X cursor.
    # A symlink here is visible in the sandbox because /nix/store is. Relying on
    # XCURSOR_THEME does NOT work -- Chromium never reads that variable.
    ".local/share/icons/Bibata-Modern-Classic".source =
      "${pkgs.bibata-cursors}/share/icons/Bibata-Modern-Classic";

    # Mirrors the GTK settings for non-GTK toolkits.
    #
    # force = true because a KDE GTK-sync daemon rewrites this file at runtime,
    # replacing home-manager's symlink with a real file (observed 2026-10-03:
    # something flipped Net/IconThemeName back to "BeautyLine" at 21:50). The
    # blanket assumption above -- "nothing writes them" -- does not hold here.
    # Without force, the next activation tries to back that real file up and
    # aborts, because the .hm-backup from the first activation still exists:
    # "Existing file '...xsettingsd.conf.hm-backup' would be clobbered". force
    # makes home-manager overwrite the daemon's copy rather than preserve it.
    ".config/xsettingsd/xsettingsd.conf" = {
      source = "${themes}/xsettingsd.conf";
      force = true;
    };
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

      # The typed workspace.iconTheme above only drives `plasma-changeicons`
      # from a login-time desktop script, so it does nothing until the Plasma
      # session restarts -- which is why the desktop sat on the stale, broken
      # BeautyLine. Writing the value here applies it at activation instead, and
      # the running plasmashell picks it up from kdeglobals.
      "kdeglobals"."Icons" = {
        Theme = "BeautySolar";
      };
    };
  };
}
