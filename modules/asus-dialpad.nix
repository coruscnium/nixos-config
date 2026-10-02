# ASUS DialPad — the virtual dial in the touchpad's top-right corner.
#
# Linux has no native support for it; this is the community `asus-linux-drivers`
# userspace daemon that grabs the dial region of the touchpad and re-emits real
# dial / scroll / volume events. It ships its own NixOS module + overlay, so it
# integrates cleanly (user-level service — no root, no compositor involvement).
{ inputs, ... }:

{
  imports = [ inputs.asus-dialpad-driver.nixosModules.default ];
  nixpkgs.overlays = [ inputs.asus-dialpad-driver.overlays.default ];

  hardware.asus-dialpad-driver = {
    enable = true;
    # HN7306WU uses the "proartp16" layout (see the driver's supported list).
    # sessionTypes defaults to ["wayland" "x11"]; daemon.enable defaults to true.
    layout = "proartp16";
  };

  # The user-level daemon needs access to i2c, the raw input devices, and
  # uinput (to inject the dial events).
  users.users.coru.extraGroups = [ "i2c" "input" "uinput" ];
}
