{ ... }:

# Global keyboard shortcuts (kglobalshortcutsrc). Attribute names are the section
# names. plasma-manager merges, so anything not listed keeps whatever KDE has.
{
  programs.plasma.shortcuts = {
    "services/floorp.desktop".new-window = "Meta+B";
    "services/org.kde.dolphin.desktop"._launch = "Meta+E";
    "services/org.kde.konsole.desktop"._launch = "Meta+X";

    kwin = {
      "Switch to Desktop 1" = "Meta+1";
      "Switch to Desktop 2" = "Meta+2";
      "Switch to Desktop 3" = "Meta+3";
      "Switch to Desktop 4" = "Meta+4";
      "Switch to Desktop 5" = "Meta+5";
      "Window Fullscreen" = "Meta+F";

      # Move focused window to desktop N and follow. Our script (kwin-scripts/
      # move-window-to-desktop), since KWin's native actions do not follow.
      # Written as shifted symbols: KGlobalAccel canonicalises Shift+<digit> to
      # the symbol, so a literal "Meta+Shift+1" never matches.
      "MoveWindowToDesktop1" = "Meta+!";
      "MoveWindowToDesktop2" = "Meta+@";
      "MoveWindowToDesktop3" = "Meta+#";
      "MoveWindowToDesktop4" = "Meta+$";
      "MoveWindowToDesktop5" = "Meta+%";
    };
  };
}
