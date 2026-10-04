{ ... }:

# The real configuration lives in ./modules (home-manager) and ./nixos (the
# system). This file carries only what home-manager needs to know about the
# user; everything else is a category module.
{
  home.username = "coru";
  home.homeDirectory = "/home/coru";

  # Do not change without reading the home-manager release notes.
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;
}
