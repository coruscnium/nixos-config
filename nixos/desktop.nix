{ config, lib, pkgs, ... }:

# Plasma 6 desktop, and everything the session needs to be usable.
{
  # ---- Display manager ------------------------------------------------------
  # You are currently running plasmalogin.service (Plasma Login Manager), not
  # sddm. nixpkgs has a module for it, so it matches rather than replacing it.
  # (The attribute name has dashes and must be quoted.)
  services.displayManager."plasma-login-manager".enable = true;
  services.displayManager.defaultSession = "plasma";

  services.desktopManager.plasma6.enable = true;
  services.xserver.enable = true;

  # ---- Audio ----------------------------------------------------------------
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };
  security.rtkit.enable = true;

  # ---- Power / input --------------------------------------------------------
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  services.libinput.enable = true;
  services.udisks2.enable = true;

  # ---- Bluetooth ------------------------------------------------------------
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false;
  };
  services.blueman.enable = true;

  # ---- Printing and scanning ------------------------------------------------
  services.printing.enable = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # Brother ADS scanner. brscan5 is a first-class option here, which is better
  # than an extraBackends hack -- it wires the driver, the udev rules and the
  # network config in one go.
  hardware.sane = {
    enable = true;
    brscan5.enable = true;
  };

  # ---- Portal / toolkit glue ------------------------------------------------
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];
  };
  environment.sessionVariables.NIXOS_OZONE_WL = "1";   # Wayland for Electron
  environment.sessionVariables.QT_QPA_PLATFORMTHEME = "qt6ct";

  # System-wide fonts, so the login screen and anything outside the session
  # still renders. The user-level set came from the [fonts] package line.
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    nerd-fonts.jetbrains-mono
  ];
}
