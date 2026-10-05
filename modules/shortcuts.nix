{ pkgs, ... }:

# Globalshortcut sections; plasma-manager merges, so unlisted keys keep KDE's value.
# Binding a *script* needs a wrapper-backed .desktop (X-KDE-GlobalAccel-CommandShortcut=true)
# plus its "services/<id>.desktop"._launch line, never `hotkeys.commands` (plasma-manager#526).
# Full rationale: vault 50-Flake/Shortcuts.md.
{
  # pipewire-control-center ships no desktop entry -- write one.
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

      # Our kwin-scripts/move-window-to-desktop (native actions do not follow).
      # Shifted symbols: KGlobalAccel canonicalises Shift+<digit>, so "Meta+Shift+1" never matches.
      "MoveWindowToDesktop1" = "Meta+!";
      "MoveWindowToDesktop2" = "Meta+@";
      "MoveWindowToDesktop3" = "Meta+#";
      "MoveWindowToDesktop4" = "Meta+$";
      "MoveWindowToDesktop5" = "Meta+%";
    };
  };
}
