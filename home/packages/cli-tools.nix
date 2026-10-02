# General command-line tools.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    btop
    curl
    wget
    unzip
  ];
}
