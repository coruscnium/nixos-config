{ ... }:

# Global keyboard shortcuts (kglobalshortcutsrc), via plasma-manager.
#
# Attribute names are the kglobalshortcutsrc section names. App-launch shortcuts
# live under "services/<app>.desktop" -- plasma-manager turns that into the
# [services][<app>.desktop] group and writes only the key list for those.
#
# Only the shortcuts Coru actually cares about are declared here; the rest of
# the file stays however KDE has it (plasma-manager merges, it does not wipe).
{
  programs.plasma.shortcuts = {
    # App actions. `_launch` is the "launch this app" action; `new-window` is
    # the app's own "new window" action.
    "services/floorp.desktop".new-window = "Meta+B";
    "services/org.kde.dolphin.desktop"._launch = "Meta+E";
    "services/org.kde.konsole.desktop"._launch = "Meta+X";

    # KWin window management. There are 5 virtual desktops (kwinrc [Desktops]).
    kwin = {
      "Switch to Desktop 1" = "Meta+1";
      "Switch to Desktop 2" = "Meta+2";
      "Switch to Desktop 3" = "Meta+3";
      "Switch to Desktop 4" = "Meta+4";
      "Switch to Desktop 5" = "Meta+5";
      "Window Fullscreen" = "Meta+F";

      # Move the focused window to desktop N and follow it there. KWin ships
      # native "Window to Desktop N" actions but they move the window without
      # following it, so this uses our own script (kwin-scripts/move-window-to-desktop),
      # which moves the window and activates it -- and KWin follows the active
      # window to its new desktop.
      #
      # Written in shifted-symbol form (Meta+!, Meta+@, ...). That is the same
      # physical keystroke as Meta+Shift+1..5, but KGlobalAccel canonicalises
      # Shift+<digit> to the symbol -- a literal "Meta+Shift+1" is stored yet
      # never matches the key event, so the shortcut silently does nothing.
      "MoveWindowToDesktop1" = "Meta+!";
      "MoveWindowToDesktop2" = "Meta+@";
      "MoveWindowToDesktop3" = "Meta+#";
      "MoveWindowToDesktop4" = "Meta+$";
      "MoveWindowToDesktop5" = "Meta+%";
    };
  };
}
