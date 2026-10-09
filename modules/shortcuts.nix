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

  # force-paste is a script too, so it needs the same wrapper-backed .desktop.
  home.file.".local/share/applications/net.local.force-paste.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=force-paste
    Exec=${pkgs.script-force-paste}/bin/force-paste
    NoDisplay=true
    StartupNotify=false
    X-KDE-GlobalAccel-CommandShortcut=true
  '';

  home.file.".local/share/applications/net.local.autoclicker.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=autoclicker
    Exec=${pkgs.script-autoclicker}/bin/autoclicker
    NoDisplay=true
    StartupNotify=false
    X-KDE-GlobalAccel-CommandShortcut=true
  '';

  programs.plasma.shortcuts = {
    "services/net.local.toggle_pw_control_center.sh.desktop"._launch = "Meta+A";
    "services/net.local.force-paste.desktop"._launch = "Meta+Ctrl+V";
    "services/net.local.autoclicker.desktop"._launch = "Calculator";

    "services/floorp.desktop".new-window = "Meta+B";
    "services/org.kde.dolphin.desktop"._launch = "Meta+E";
    "services/org.kde.konsole.desktop"._launch = "Meta+X";

    kwin = {
      # "Num" is Qt's portable-text name for the keypad modifier, so "Meta+Num+1" is
      # Meta plus numpad 1 (NumLock on). Lists become tab-separated alternatives in
      # kglobalshortcutsrc; the row keeps its old binding alongside the numpad one.
      "Switch to Desktop 1" = [
        "Meta+1"
        "Meta+Num+1"
      ];
      "Switch to Desktop 2" = [
        "Meta+2"
        "Meta+Num+2"
      ];
      "Switch to Desktop 3" = [
        "Meta+3"
        "Meta+Num+3"
      ];
      "Switch to Desktop 4" = [
        "Meta+4"
        "Meta+Num+4"
      ];
      "Switch to Desktop 5" = [
        "Meta+5"
        "Meta+Num+5"
      ];
      "Window Fullscreen" = "Meta+F";

      # Our kwin-scripts/move-window-to-desktop (native actions do not follow).
      # Shifted symbols: KGlobalAccel canonicalises Shift+<digit>, so "Meta+Shift+1" never matches.
      "MoveWindowToDesktop1" = [
        "Meta+!"
        "Meta+Alt+Num+1"
      ];
      "MoveWindowToDesktop2" = [
        "Meta+@"
        "Meta+Alt+Num+2"
      ];
      "MoveWindowToDesktop3" = [
        "Meta+#"
        "Meta+Alt+Num+3"
      ];
      "MoveWindowToDesktop4" = [
        "Meta+$"
        "Meta+Alt+Num+4"
      ];
      "MoveWindowToDesktop5" = [
        "Meta+%"
        "Meta+Alt+Num+5"
      ];
    };
  };
}
