{ pkgs, ... }:

# Password managers, 2FA, encrypted mail, privacy. windscribe is NOT here -- it is
# the ParkerrDev flake input plus its own NixOS module (nixos/windscribe.nix),
# since it needs a root helper and a /opt bind mount a home package cannot give it.
{
  home.packages = with pkgs; [
    proton-pass
    ente-auth
    tutanota-desktop
    spoofdpi
    redact
  ];
}
