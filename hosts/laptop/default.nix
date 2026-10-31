# The laptop. Same user, different machine: it imports the shared modules it
# actually uses -- no printer container, no Steam, no desk peripherals, and no
# declared flatpak set.
{ pkgs, ... }:
let
  # The PX13's keyboard has its own OOBE state: on a cold boot the backlight
  # fades in and out by itself and ignores brightness reports. hid-asus has the
  # exact fix (asus_kbd_disable_oobe) but only runs it when DMI_PRODUCT_FAMILY
  # is "ProArt P16" (hid-asus.c:750), so the PX13 never gets it.
  #
  # These are that sequence, byte for byte (hid-asus.c:552): four feature
  # reports on 0x5a / usage page 0xff31, then the same brightness report
  # asus_kbd_backlight_work() sends, so the keyboard does not sit dark after the
  # OOBE state clears. --length 64 covers the report id plus the 63-byte payload.
  asusKbdOobe = pkgs.writeShellScriptBin "asus-kbd-oobe" ''
    set -eu
    level=''${1:-1}

    kbd() {
      hidapitester --quiet --vidpid 0B05:19B6 --usagePage 0xFF31 --open \
        --length 64 --send-feature "$1" --close
    }

    # The unit can start before the keyboard finishes enumerating.
    for _ in $(seq 40); do
      if hidapitester --quiet --vidpid 0B05:19B6 --usagePage 0xFF31 --open --close 2>/dev/null; then
        break
      fi
      sleep 0.5
    done

    kbd 0x5a,0x05,0x20,0x31,0x00,0x08
    kbd 0x5a,0xba,0xc5,0xc4
    kbd 0x5a,0xd0,0x8f,0x01
    kbd 0x5a,0xd0,0x85,0xff
    kbd "0x5a,0xba,0xc5,0xc4,$level"
  '';

  # The LED class caches the level it was last given, which is what makes the
  # resume hook restore it. A cold boot starts at -1, so sysfs reads 0 there and
  # this falls back to 1 -- deliberate, the keyboard should not come up dark.
  kbdOobeLevel = ''
    level=$(cat /sys/class/leds/asus::kbd_backlight/brightness 2>/dev/null || echo 1)
    case "$level" in 1|2|3) ;; *) level=1 ;; esac
  '';
in
{
  imports = [
    ../../nixos/boot.nix
    ../../nixos/desktop.nix
    ../../nixos/services.nix
    ../../nixos/system.nix
    ../../nixos/users.nix
    ../../nixos/windscribe.nix
    ./hardware.nix
    ./boot.nix
  ];

  networking.hostName = "coru-laptop";
  system.stateVersion = "26.05";

  # KDE's power applet drives this. There is no desktop equivalent.
  services.power-profiles-daemon.enable = true;

  systemd.services.asus-kbd-oobe = {
    description = "Clear the PX13 keyboard's OOBE state so the backlight works";
    wantedBy = [ "multi-user.target" ];
    before = [ "plasmalogin.service" ];
    path = [
      pkgs.coreutils
      pkgs.hidapitester
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${kbdOobeLevel}
      exec ${asusKbdOobe}/bin/asus-kbd-oobe "$level"
    '';
  };

  # OOBE comes back on resume, same as on a cold boot.
  powerManagement.resumeCommands = ''
    ${kbdOobeLevel}
    ${asusKbdOobe}/bin/asus-kbd-oobe "$level" || true
  '';
}
