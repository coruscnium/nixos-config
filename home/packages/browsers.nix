# Web browsers.
{ pkgs, ... }:

{
  programs.firefox.enable = true;
  programs.floorp.enable = true;

  # Brave Origin has no nixpkgs package; it comes from NUR (see
  # modules/packages.nix, which adds the NUR overlay).
  home.packages = [ pkgs.nur.repos.ymstnt."brave-origin" ];
}
