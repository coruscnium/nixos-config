# Alternative app-distribution platforms (system-level).
{ pkgs, ... }:

{
  # AppImage: run AppImages directly (binfmt registration is system-wide).
  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  # Flatpak: escape hatch for GUI apps that aren't packaged in nixpkgs. This is
  # a system service plus the Flathub remote. Remove both options if you'd
  # rather stay nix-only. Flatpak apps are installed imperatively
  # (`flatpak install …`), so they never appear in this config.
  services.flatpak.enable = true;

  systemd.services.flatpak-add-flathub = {
    description = "Add the Flathub Flatpak remote";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    path = [ pkgs.flatpak ];
    serviceConfig.Type = "oneshot";
    script = "flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo";
  };
}
