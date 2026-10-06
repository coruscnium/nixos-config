{ ... }:

# Declarative MIME/URL-scheme defaults. home-manager owns ~/.config/mimeapps.list
# here, so KDE's System Settings can no longer persist a change to it -- edits go
# through this file. Desktop ids resolve via the profile's share/applications, so a
# rename upstream leaves a dangling association rather than a boot failure.
{
  xdg.mimeApps.enable = true;

  xdg.mimeApps.defaultApplications = {
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

    # Roblox player deep links. roblox-studio*/place/model stay on Vinegar.
    "x-scheme-handler/roblox" = "org.vinegarhq.Sober.desktop";
    "x-scheme-handler/roblox-player" = "org.vinegarhq.Sober.desktop";
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
