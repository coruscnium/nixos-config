# Category modules for coru's home-manager configuration.
# Imported by flake.nix as a single module; add new categories to this list.
{
  imports = [
    ./desktop.nix
    ./mimeapps.nix
    ./browsing.nix
    ./messaging.nix
    ./media.nix
    ./audio.nix
    ./graphics.nix
    ./gaming.nix
    ./development.nix
    ./documents.nix
    ./net.nix
    ./files.nix
    ./shell.nix
    ./shortcuts.nix
    ./session.nix
    ./security.nix
    ./hardware.nix
    ./ai.nix
    ./scripts.nix
    ./services.nix
    ./theming.nix
  ];
}
