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

    # LE Audio roles, stated explicitly even though PipeWire 1.6.9's compiled
    # default (bluez5-dbus.c parse_roles) already enables the BAP set -- this
    # pins the intent so a future upstream default change cannot silently drop
    # it. HFP is not in that mask; it is governed by bluez5.headset-roles.
    wireplumber.extraConfig."51-le-audio" = {
      "monitor.bluez.properties" = {
        # Quoted: unquoted, Nix reads this as a nested { bluez5 = { roles }; }
        # and WirePlumber never sees the bluez5.roles property.
        "bluez5.roles" = [
          "a2dp_sink"
          "a2dp_source"
          "hfp_hf"
          "hfp_ag"
          "bap_sink"
          "bap_source"
          "bap_bcast_sink"
          "bap_bcast_source"
        ];
      };
    };
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

  # Bluetooth stack only (bluez); Plasma's applet is the manager.
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false;
    # LE Audio profiles (BAP/GMAP) are .experimental in bluez and
    # src/profile.c rejects them with -ENOTSUP unless the experimental
    # D-Bus flag is on. Runtime only -- there is no build flag for this.
    settings.General = {
      Experimental = true;
      # ISO socket, still a kernel experimental feature. Without it bluez
      # cannot create CIS: LE Audio connects and then never streams.
      KernelExperimental = "6fbaf188-05e0-496a-9885-d6ddfdb4e03e";
    };
  };

  # ---- LAN discovery --------------------------------------------------------
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # The module owns the firewall side: it opens 1714-1764 TCP+UDP, which is what
  # kdeconnectd actually listens on (1716) and what the phone dials back to. The
  # package itself moved here from modules/desktop.nix -- installing it in both
  # would duplicate it.
  programs.kdeconnect.enable = true;

  # Spotify Connect. The desktop client advertises itself on 57621 (TCP+UDP) and
  # the phone connects to that port; without it the desktop never shows up as a
  # device on the phone. mDNS (UDP 5353) is already covered by avahi above.
  networking.firewall = {
    allowedTCPPorts = [ 57621 ];
    allowedUDPPorts = [ 57621 ];
  };

  # ---- Printing and scanning ------------------------------------------------
  services.printing.enable = true;

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

  # ---- Screen capture -------------------------------------------------------
  # KMS capture grabs the framebuffer through gsr-kms-server, which needs
  # CAP_SYS_ADMIN. Without a setcap wrapper the recorder shells out to pkexec and
  # pops a polkit password prompt on every start. This installs the recorder
  # system-wide and creates /run/wrappers/bin/gsr-kms-server with cap_sys_admin,
  # making capture promptless. The GTK frontend stays per-user (modules/media.nix).
  programs.gpu-screen-recorder.enable = true;

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
