{ pkgs, ... }:

# One Discord client only (equibop).
{
  home.packages = with pkgs; [
    equibop
    signal-desktop
    telegram-desktop
    element-desktop
    session-desktop
  ];
}
