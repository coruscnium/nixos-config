{ ... }:

{
  powerManagement.enable = true;

  # Battery reporting in Plasma, and the profile backend KDE's power applet
  # drives. (asusd integrates with power-profiles-daemon rather than replacing
  # it; do not also enable TLP.)
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
}
