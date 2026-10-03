{ pkgs, lib, ... }:

# The wrappers themselves are defined in pkgs/scripts.nix (the overlay), because
# modules/services.nix needs to reference the same derivations by store path.
# This module is just the "install them" list.
#
# They land in the PROFILE's bin/, not ~/.local/bin. Remove the ~/.local/bin
# copies at switch time or PATH order decides which wins.
#
# NOT ported: phonecam, fleasion-launch, heroic-performance-off.sh, hyprpush.sh,
# gemini-mcp-wrapper.sh, obsidian-mcp*, paste-into-game.sh, lock-displays.sh
# (excluded), cheatengine + cehelper.sh (replaced by pkgs/default.nix).
{
  home.packages = with pkgs; [
    script-cover-extract
    script-embed-lyrics
    script-extract-here
    script-jan-clean
    script-toggle-pw-control-center
    script-mpv-single
    script-streamcontroller-watchdog
  ];
}
