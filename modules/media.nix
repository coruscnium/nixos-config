{ pkgs, ... }:

# Video, screen capture, image viewing/editing.
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
  ];
}
