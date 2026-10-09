{
  config,
  lib,
  pkgs,
  ...
}:

# Plasma 6 desktop and everything the session needs.
{
  # ---- Display manager ------------------------------------------------------
  services.displayManager."plasma-login-manager".enable = true;
  services.displayManager.defaultSession = "plasma";

  services.desktopManager.plasma6.enable = true;
  services.xserver.enable = true;

  # discover (Plasma's GUI package store) rides in on the plasma6 module whenever
  # flatpak is enabled. Packages here are declarative, so drop it.
  environment.plasma6.excludePackages = [ pkgs.kdePackages.discover ];

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

  # Logitech peripherals. programs.solaar supplies the udev rules (without them
  # the hidraw node is root-only) and a tray-only user service.
  programs.solaar = {
    enable = true;
    userService.enable = true;
    userService.window = "hide";
  };

  # Button remapping. enableUdevRules stays off (upstream input-remapper#140). The
  # preset is seeded by modules/hardware.nix.
  services.input-remapper.enable = true;

  # input-remapper can still own its D-Bus name for a moment after it is stopped, so
  # a restart can start the replacement too early: it exits with "Is the service
  # already running?" and the unit fails, which fails the whole activation. Give the
  # bus a moment to release the name before the start.
  systemd.services.input-remapper.serviceConfig.ExecStopPost = [
    "${pkgs.coreutils}/bin/sleep 1"
  ];

  # The G502 X LIGHTSPEED is a USB wakeup source, so any movement wakes suspend or
  # hibernate. Disable it on the device node (its parent hubs are already off).
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="046d", ATTR{idProduct}=="c098", ATTR{power/wakeup}="disabled"
  '';

  # Bluetooth stack only (bluez); Plasma's applet is the manager.
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

  # Brother ADS scanner.
  hardware.sane = {
    enable = true;
    brscan5.enable = true;
  };

  # ---- Portal / toolkit glue ------------------------------------------------
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];
  };
  environment.sessionVariables.NIXOS_OZONE_WL = "1"; # Wayland for Electron

  # MUST be "kde" on Plasma -- "qt6ct" makes app widgets read qt6ct's palette while
  # Plasma chrome stays dark (the half-light/half-dark bug).
  environment.sessionVariables.QT_QPA_PLATFORMTHEME = "kde";

  # ---- Login screen theming ------------------------------------------------
  # The Plasma Login Manager greeter runs as its own user (plasmalogin, home
  # /var/lib/plasmalogin) and cannot read coru's home or per-user profile, so
  # whatever it should show has to be in /run/current-system/sw.
  environment.systemPackages = with pkgs; [
    carl-theme # colour scheme + Look-and-Feel + desktop theme + Aurorae
    beautysolar # icon theme (see pkgs/beautysolar.nix)
    bibata-cursors # cursor theme (nixpkgs name -- not bibata-cursor-theme)
  ];

  # systemPackages links only the share/ subdirs named here. (/share/icons is
  # deliberately absent -- a module already adds it.)
  environment.pathsToLink = [
    "/share/color-schemes"
    "/share/plasma"
    "/share/aurorae"
  ];

  # System-wide fonts so the greeter and anything outside the session renders.
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
    nerd-fonts.meslo-lg
  ];

  # ---- Make the greeter match the desktop -----------------------------------
  # PLM's "Apply Plasma Settings" copies these files into the greeter's home at
  # runtime (PlasmaLoginAuthHelper::sync()); do the same at boot. Copies whatever
  # the last home-manager activation wrote and never fails the boot.
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

        # The greeter's XDG_DATA_DIRS is only the session desktops dir, NOT
        # /run/current-system/sw/share, so the Carl suite linked there is
        # invisible to it and it renders missing-SVG garbage. $HOME/.local/share
        # is always on Qt's search path, so link the theme/icon/cursor trees that
        # the synced kdeglobals + plasmarc name into there.
        sw=/run/current-system/sw/share
        for d in plasma/desktoptheme plasma/look-and-feel color-schemes aurorae/themes icons; do
          install -d -m 0755 -o plasmalogin -g plasmalogin "$dst/.local/share/$d"
        done
        ln -sfn "$sw/plasma/desktoptheme/Carl"    "$dst/.local/share/plasma/desktoptheme/Carl"
        ln -sfn "$sw/plasma/look-and-feel/Carl"   "$dst/.local/share/plasma/look-and-feel/Carl"
        ln -sfn "$sw/color-schemes/Carl.colors"   "$dst/.local/share/color-schemes/Carl.colors"
        ln -sfn "$sw/aurorae/themes/Carl"         "$dst/.local/share/aurorae/themes/Carl"
        ln -sfn "$sw/icons/BeautySolar"           "$dst/.local/share/icons/BeautySolar"
        ln -sfn "$sw/icons/Bibata-Modern-Classic" "$dst/.local/share/icons/Bibata-Modern-Classic"

        rm -rf "$dst/.cache"
      '';
    };
  };
}
