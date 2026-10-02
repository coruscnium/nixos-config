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

  # Brave Origin has no nixpkgs package (Brave only ships the stable Origin
  # artifact for 1.97.53), so it is vendored in ../pkgs/brave-origin.nix.
  home.packages = [
    pkgs.braveOrigin
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
