{ config, lib, pkgs, ... }:

# Plasma 6 desktop and everything the session needs.
{
  # ---- Display manager ------------------------------------------------------
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
  environment.sessionVariables.NIXOS_OZONE_WL = "1";       # Wayland for Electron

  # MUST be "kde" on Plasma -- "qt6ct" makes app widgets read qt6ct's palette while
  # Plasma chrome stays dark (the half-light/half-dark bug).
  environment.sessionVariables.QT_QPA_PLATFORMTHEME = "kde";

  # ---- Login screen theming ------------------------------------------------
  # The Plasma Login Manager greeter runs as its own user (plasmalogin, home
  # /var/lib/plasmalogin) and cannot read coru's home or per-user profile, so
  # whatever it should show has to be in /run/current-system/sw.
  environment.systemPackages = with pkgs; [
    carl-theme     # colour scheme + Look-and-Feel + desktop theme + Aurorae
    beautysolar    # icon theme (see pkgs/beautysolar.nix)
    bibata-cursors # cursor theme
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
        rm -rf "$dst/.cache"
      '';
    };
  };
}
