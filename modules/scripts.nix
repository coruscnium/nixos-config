{ pkgs, ... }:

# The wrapper packages themselves are defined in pkgs/scripts.nix (the overlay),
# because modules/services.nix references them by store path.
{
  home.packages = with pkgs; [
    script-cover-extract
    script-embed-lyrics
    script-toggle-pw-control-center
    script-mpv-single
    script-force-paste
    script-autoclicker
    script-streamcontroller-watchdog
  ];
}
