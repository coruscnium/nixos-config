{ pkgs, ... }:

# Global keyboard shortcuts (kglobalshortcutsrc). Attribute names are the section
# names. plasma-manager merges, so anything not listed keeps whatever KDE has.
#
# To bind a key to a *script* -- KDE can only bind a desktop entry's action, not
# a bare command -- two pieces are needed:
#   - a home.file desktop entry at ~/.local/share/applications/<id>.desktop with
#     X-KDE-GlobalAccel-CommandShortcut=true, and
#   - a "services/<id>.desktop"._launch = "<key>" line in the block below.
# Exec must be a package wrapper: scripts/<name> starts with #!/bin/bash, which
# does not exist on NixOS. Do not reach for plasma-manager's `hotkeys.commands`
# module -- it writes the key to a top-level section that kglobalacceld does not
# read (upstream plasma-manager#526, #571).
{
  # pipewire-control-center ships no desktop entry of its own -- write one (see above).
  home.file.".local/share/applications/net.local.toggle_pw_control_center.sh.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=toggle_pw_control_center
    Exec=${pkgs.script-toggle-pw-control-center}/bin/toggle_pw_control_center.sh
    NoDisplay=true
    StartupNotify=false
    X-KDE-GlobalAccel-CommandShortcut=true
  '';

  programs.plasma.shortcuts = {
    "services/net.local.toggle_pw_control_center.sh.desktop"._launch = "Meta+A";

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
