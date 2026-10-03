{ pkgs, ... }:

# One Discord client only (equibop). vesktop and legcord were dropped --
# three Vencord-family wrappers were doing the same job.
{
  home.packages = with pkgs; [
    equibop
    signal-desktop
    telegram-desktop
    element-desktop
    session-desktop
  ];
}
