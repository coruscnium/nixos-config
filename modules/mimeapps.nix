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

    # Roblox player deep links. Was Sober; switched to nutmeg -- the *macOS*
    # client through rosemary (pkgs/nutmeg.nix) -- on 2026-10-13, so the browser
    # Play button goes through rosemary. Coru still runs Sober too while rosemary
    # matures, and keeps it reachable in KDE's "Open with" without an entry here:
    # Sober's own .desktop declares both schemes. The id below exists only because
    # `nutmeg install-desktop` wrote it to ~/.local/share/applications, so running
    # `nutmeg uninstall-desktop` dangles this association -- that is a nudge, not a
    # boot failure. roblox-studio*/place/model stay on Vinegar.
    "x-scheme-handler/roblox" = "io.github.frolleks.Nutmeg.desktop";
    "x-scheme-handler/roblox-player" = "io.github.frolleks.Nutmeg.desktop";
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
