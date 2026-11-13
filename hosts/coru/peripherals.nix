{
  pkgs,
  ...
}:

# Peripherals on this desk and no other: the G502 X, two Keychron boards, and the
# input-remapper preset that rebinds the mouse wheel. Nothing here applies to a
# laptop.
{
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

  # Keychron keyboards (K0 Max, K3 v3) share vendor 3434. Upstream rules: uaccess on
  # the hidraw node so the seated user can open the 0xFF60 vendor channel (Keychron
  # Launcher / VIA over WebHID), and clear the joystick flag these NKRO boards get
  # mislabelled with. uaccess is per-seat, unlike a world-writable node.
  services.udev.packages = [ pkgs.keychron-udev-rules ];

  # The G502 X LIGHTSPEED is a USB wakeup source, so any movement wakes suspend or
  # hibernate. Disable it on the device node (its parent hubs are already off).
  # "change" as well as "add" so `udevadm trigger` (run by every rebuild) repairs a
  # node whose value was reset without needing a replug.
  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="046d", ATTR{idProduct}=="c098", ATTR{power/wakeup}="disabled"
  '';

  # The rule is in the running generation, yet the device still reported
  # wakeup=enabled on 2026-11-13 -- something re-arms it after the device node is
  # set. The value only matters at the instant the kernel suspends, so re-apply it
  # there rather than trusting the uevent. Id-based; the receiver's port can move.
  powerManagement.powerDownCommands = ''
    for dev in /sys/bus/usb/devices/*; do
      if [ "$(cat "$dev/idVendor" 2>/dev/null)" = 046d ] &&
         [ "$(cat "$dev/idProduct" 2>/dev/null)" = c098 ]; then
        echo disabled > "$dev/power/wakeup"
      fi
    done
  '';
}
