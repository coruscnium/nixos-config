{ pkgs, ... }:

# Video, screen capture, image viewing/editing.
# mpv is driven by ~/.local/bin/mpv-single (see script-deps.nix for socat).
{
  home.packages = with pkgs; [
    mpv
    obs-studio
    handbrake
    gpu-screen-recorder
    gpu-screen-recorder-gtk
    gthumb
    easytag
    converseen
    linux-wallpaperengine
  ];
}
