# The laptop's user profile. Everything desk-bound is left out on purpose:
# gaming, VR, the 3D-printing tools, the G502/ydotool stack, the desk scripts,
# and the user units that drive them.
{
  imports = [
    ../../modules/desktop.nix
    ../../modules/mimeapps.nix
    ../../modules/browsing.nix
    ../../modules/messaging.nix
    ../../modules/media.nix
    ../../modules/audio.nix
    ../../modules/graphics.nix
    ../../modules/development.nix
    ../../modules/documents.nix
    ../../modules/net.nix
    ../../modules/files.nix
    ../../modules/shell.nix
    ../../modules/shortcuts.nix
    ../../modules/session.nix
    ../../modules/security.nix
    ../../modules/ai.nix
    ../../modules/theming.nix
    ../../modules/services.nix
  ];
}
