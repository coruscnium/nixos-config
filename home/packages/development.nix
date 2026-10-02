# Editors and development tooling.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    kdePackages.kate # text/code editor
    vim
    ripgrep
    fd
  ];
}
