{ pkgs, ... }:

# Password managers, 2FA, encrypted mail, privacy tooling.
# windscribe is deliberately absent: it is not in nixpkgs, nyx or NUR, and
# packaging it means owning its root helper, setgid GUI and self-updater.
# See PACKAGING-LEDGER.md.
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
