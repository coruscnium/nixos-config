# Coru's user environment. System-wide daemons/hardware live in ../modules;
# everything that is a *user's* program belongs here.
{ config, pkgs, ... }:

{
  home.username = "coru";
  home.homeDirectory = "/home/coru";
  home.stateVersion = "26.05";

  # Browsers.
  programs.floorp.enable = true;
  programs.firefox.enable = true;

  # Brave Origin comes from NUR (no nixpkgs package); see modules/packages.nix.
  home.packages = [
    pkgs.nur.repos.ymstnt."brave-origin"
  ]
  ++ (with pkgs; [
    kdePackages.kate
    btop
    ripgrep
    fd
    wget
    curl
    unzip
    vim
  ]);
}
