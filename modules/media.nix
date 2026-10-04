{ pkgs, ... }:

# Video, screen capture, image viewing/editing.
# mpv is driven by the mpv-single wrapper (pkgs/scripts.nix supplies its socat).
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
