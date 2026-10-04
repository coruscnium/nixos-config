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

  # ---- Logitech peripherals -------------------------------------------------
  # Solaar could not see the G502 X because nothing installed its udev rules:
  # without them the hidraw node is root-only. programs.solaar supplies the
  # package and the rules (it enables hardware.logitech.wireless); userService
  # starts it tray-only on login. On-board profiles get switched off in Solaar so
  # the buttons can be remapped instead of replaying what is stored on the mouse.
  programs.solaar = {
    enable = true;
    userService.enable = true;
    userService.window = "hide";
  };

  # Button remapping. enableUdevRules stays at its default (off) -- upstream
  # disables it over input-remapper#140, and the system service handles presets
  # without it. The preset file is seeded by modules/hardware.nix.
  services.input-remapper.enable = true;

  # ---- Bluetooth ------------------------------------------------------------
  # Stack only (bluez). Bluetooth is managed with Plasma's own applet, so the
  # GTK blueman manager is deliberately not enabled.
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false;
  };

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

  # ---- Make the greeter match the desktop -----------------------------------
  # The greeter runs as its own user (plasmalogin, home /var/lib/plasmalogin),
  # so it cannot read coru's ~/.config -- which is why "Apply Plasma Settings"
  # in the Login Screen KCM copies files across at runtime. Do the same at boot
  # so the look survives a wipe or rebuild with no manual step.
  #
  # The file list mirrors PlasmaLoginAuthHelper::sync():
  #   plasma-login-manager/src/frontend/kcm/auth/plasmaloginauthhelper.cpp
  # It writes kxkbrc, kdeglobals, plasmarc, plasma-localerc, kcminputrc,
  # kwinoutputconfig.json and fontconfig/fonts.conf into the greeter's
  # ~/.config, then clears its ~/.cache so the new colours are picked up.
  #
  # Only runs when coru actually has a config, never fails the boot, and copies
  # whatever the last home-manager activation wrote -- so a theme change shows
  # up on the greeter from the next boot after a switch.
  systemd.services.plasmalogin-sync-settings = {
    description = "Copy coru's Plasma settings into the plasmalogin greeter home";
    before = [ "plasmalogin.service" ];
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = "/home/coru/.config/kdeglobals";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "plasmalogin-sync-settings" ''
        set -eu
        src=/home/coru/.config
        dst=/var/lib/plasmalogin
        install -d -m 0750 -o plasmalogin -g plasmalogin "$dst/.config"
        for f in kxkbrc kdeglobals plasmarc plasma-localerc kcminputrc kwinoutputconfig.json; do
          if [ -f "$src/$f" ]; then
            install -m 0644 -o plasmalogin -g plasmalogin "$src/$f" "$dst/.config/$f"
          fi
        done
        if [ -f "$src/fontconfig/fonts.conf" ]; then
          install -d -m 0750 -o plasmalogin -g plasmalogin "$dst/.config/fontconfig"
          install -m 0644 -o plasmalogin -g plasmalogin \
            "$src/fontconfig/fonts.conf" "$dst/.config/fontconfig/fonts.conf"
        fi
        rm -rf "$dst/.cache"
      '';
    };
  };
}
