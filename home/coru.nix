# Coru's user environment. Identity lives here; the actual programs are grouped
# by category under ./packages/ so each kind of app has an obvious home.
{ ... }:

{
  imports = [
    ./packages/browsers.nix
    ./packages/development.nix
    ./packages/cli-tools.nix
    ./packages/gaming.nix
    ./packages/media.nix
    ./packages/communication.nix
    ./packages/security.nix
    ./packages/productivity.nix
  ];

  home.username = "coru";
  home.homeDirectory = "/home/coru";
  home.stateVersion = "26.05";
}
