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

  # MUST be "kde" on a Plasma desktop. This was set to "qt6ct", which makes
  # every Qt application read its palette, fonts and widget style from qt6ct's
  # own config instead of the Plasma colour scheme. Plasma's chrome (panels,
  # titlebars) is drawn by Plasma and stays dark while app widgets render
  # light -- the "half light, half dark" breakage.
  #
  # qt6ct stays installed (modules/desktop.nix) so it is available as a style
  # chooser, but it must not be the platform theme under KDE.
  environment.sessionVariables.QT_QPA_PLATFORMTHEME = "kde";

  # ---- Login screen theming ------------------------------------------------
  # The Plasma Login Manager greeter runs as its own user (`plasmalogin`, home
  # /var/lib/plasmalogin), so it cannot read anything in coru's home --
  # ~/.local/share/plasma/..., ~/.local/share/color-schemes/... and
  # /etc/profiles/per-user/coru are all invisible to it. Whatever the login
  # screen should show has to be in /run/current-system/sw instead.
  #
  # PLM has no colour-scheme or theme option of its own: its System Settings
  # module exposes only PreselectedSession and WallpaperPluginId. It draws the
  # greeter with Plasma, so it picks these up as ordinary system-wide assets.
  environment.systemPackages = with pkgs; [
    carl-theme     # colour scheme + Look-and-Feel + desktop theme + Aurorae
    beautysolar    # icon theme (see pkgs/beautysolar.nix)
    bibata-cursors # cursor theme
  ];

  # environment.systemPackages only links the share/ subdirectories named here,
  # and the defaults do NOT include any of these four -- which is why the icon
  # theme previously existed only in coru's per-user profile.
  environment.pathsToLink = [
    "/share/color-schemes"
    "/share/plasma"
    "/share/aurorae"
    # NOTE: /share/icons is deliberately absent -- another module already adds
    # it, and listing it twice puts a duplicate in the merged list.
  ];

  # System-wide fonts, so the login screen and anything outside the session
  # still renders. The user-level set came from the [fonts] package line.
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    nerd-fonts.jetbrains-mono
  ];
}
