{ lib, ... }:

# Declarative MIME/URL-scheme defaults. home-manager owns ~/.config/mimeapps.list
# here, so KDE's System Settings can no longer persist a change to it -- edits go
# through this file. Desktop ids resolve via the profile's share/applications, so a
# rename upstream leaves a dangling association rather than a boot failure.
let
  # Every video container mpv's own .desktop claims, plus the playlist and
  # streaming types that arrive as media links. umpv, not mpv: same player,
  # single-instance socket, so a second file queues into the window already
  # open instead of spawning another. Audio is deliberately absent -- those
  # stay on whatever KDE picks.
  videoMimeTypes = [
    "video/mpeg"
    "video/x-mpeg2"
    "video/x-mpeg3"
    "video/mp4"
    "video/mp4v-es"
    "video/x-m4v"
    "application/x-extension-mp4"
    "video/divx"
    "video/vnd.divx"
    "video/msvideo"
    "video/x-msvideo"
    "video/avi"
    "video/x-avi"
    "video/vnd.avi"
    "video/quicktime"
    "video/ogg"
    "video/x-theora"
    "video/x-theora+ogg"
    "video/x-matroska"
    "video/mkv"
    "application/x-matroska"
    "video/webm"
    "video/x-flv"
    "video/flv"
    "video/x-flic"
    "video/fli"
    "video/x-flc"
    "video/x-ms-wmv"
    "video/x-ms-wmx"
    "video/x-ms-wvxvideo"
    "video/x-ms-asf"
    "video/x-ms-afs"
    "video/vnd.rn-realvideo"
    "video/x-ogm"
    "video/x-ogm+ogg"
    "application/x-ogm-video"
    "video/mp2t"
    "video/3gp"
    "video/3gpp"
    "video/3gpp2"
    "video/dv"
    "application/mxf"
    "application/sdp"
    "application/smil"
    "application/x-smil"
    "application/streamingmedia"
    "application/x-streamingmedia"
    "application/vnd.rn-realmedia"
    "application/vnd.rn-realmedia-vbr"
    "application/x-mpegurl"
    "application/vnd.apple.mpegurl"
    "video/vnd.mpegurl"
  ];
in
{
  xdg.mimeApps.enable = true;

  xdg.mimeApps.defaultApplications = lib.genAttrs videoMimeTypes (_: "umpv.desktop") // {
    "x-scheme-handler/mailto" = "tutanota-desktop.desktop";
    "x-scheme-handler/tuta" = "tutanota-desktop.desktop";

    "x-scheme-handler/http" = "floorp.desktop";
    "x-scheme-handler/https" = "floorp.desktop";
    "x-scheme-handler/chrome" = "floorp.desktop";
    "text/html" = "floorp.desktop";
    "application/xhtml+xml" = "floorp.desktop";
    "application/x-extension-htm" = "floorp.desktop";
    "application/x-extension-html" = "floorp.desktop";
    "application/x-extension-shtml" = "floorp.desktop";
    "application/x-extension-xhtml" = "floorp.desktop";
    "application/x-extension-xht" = "floorp.desktop";

    "x-scheme-handler/cherrystudio" = "CherryStudio.desktop";
    "x-scheme-handler/ror2mm" = "r2modman.desktop";

    # Roblox player deep links. Was Sober, then nutmeg; ginrose took it on
    # 2026-11-07 -- the *macOS* client through its patched Rosemary. Coru still
    # runs Sober too and keeps it reachable in KDE's "Open with" without an entry
    # here: Sober's own .desktop declares both schemes. Unlike nutmeg's, this id
    # ships inside the ginrose package, so it cannot dangle. roblox-studio*/
    # place/model stay on Vinegar.
    "x-scheme-handler/roblox" = "me.daeese.apps.ginrose.player.desktop";
    "x-scheme-handler/roblox-player" = "me.daeese.apps.ginrose.player.desktop";
  };

  # Kept so "open with" ordering matches what KDE had written by hand.
  xdg.mimeApps.associations.added = {
    "x-scheme-handler/http" = [
      "floorp.desktop"
      "brave-origin.desktop"
    ];
    "x-scheme-handler/https" = [
      "floorp.desktop"
      "brave-origin.desktop"
    ];
    "text/html" = [
      "brave-origin.desktop"
      "floorp.desktop"
    ];
    "x-scheme-handler/chrome" = [ "floorp.desktop" ];
    "application/x-extension-htm" = [ "floorp.desktop" ];
    "application/x-extension-html" = [ "floorp.desktop" ];
    "application/x-extension-shtml" = [ "floorp.desktop" ];
    "application/xhtml+xml" = [ "floorp.desktop" ];
    "application/x-extension-xhtml" = [ "floorp.desktop" ];
    "application/x-extension-xht" = [ "floorp.desktop" ];
    "x-scheme-handler/ror2mm" = [ "r2modman.desktop" ];
    "x-scheme-handler/mailto" = [ "tutanota-desktop.desktop" ];
  };
}
