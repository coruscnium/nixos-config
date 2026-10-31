# Category modules for coru's home-manager configuration. Both hosts import this
# whole set -- it is what the *user* wants on any machine. Desk-bound categories
# (peripherals, 3D printing, the desk's user units) are NOT listed here: they are
# imported by ../hosts/coru/hm.nix, so the laptop never carries them.
#
# Add a new shared category to this list; add a desk-only one to hosts/coru/hm.nix.
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
    ./ai.nix
    ./scripts.nix
    ./services.nix
    ./theming.nix
  ];
}
