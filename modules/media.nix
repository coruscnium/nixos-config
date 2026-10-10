{ pkgs, ... }:

# Video, screen capture, image viewing/editing.
{
  home.packages = with pkgs; [
    mpv
    obs-studio
    handbrake
    # gpu-screen-recorder itself is system-wide (nixos/desktop.nix): KMS capture
    # needs the setcap'd gsr-kms-server wrapper. Only the GTK frontend is per-user
    # -- its launcher already prefers /run/wrappers/bin, so it finds that wrapper.
    gpu-screen-recorder-gtk
    gthumb
    easytag
    converseen
  ];
}
