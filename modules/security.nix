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

  # Tuta runs its own desktop integration when this exact path is missing, and what
  # it writes pins the raw extracted AppImage -- no wrapper, no FHS env, dies on
  # libcups from the launcher. Every version bump changes the extracted store path,
  # so its "don't ask again" blacklist stops matching and it asks again. Owning the
  # path means it never finds it missing.
  xdg.dataFile."applications/tutanota-desktop.desktop".source =
    "${pkgs.tutanota-desktop}/share/applications/tutanota-desktop.desktop";
}
