{ pkgs, ... }:

# Password managers, 2FA, encrypted mail, privacy. windscribe is absent -- it is
# not in nixpkgs/nyx/NUR and would mean owning its root helper and self-updater.
{
  home.packages = with pkgs; [
    proton-pass
    proton-authenticator
    ente-auth
    tutanota-desktop
    spoofdpi
    redact
  ];
}
