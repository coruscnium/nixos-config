# Gaming. Steam is *system*-level (programs.steam.enable lives in modules/),
# so put standalone launchers/tools that are plain packages here.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # lutris
    # heroic
    # mangohud
    # gamescope
  ];
}
