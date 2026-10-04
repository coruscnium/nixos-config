{ config, lib, pkgs, ... }:

# coru, uid 1000 -- matching the CachyOS account so /home/coru ownership stays
# correct and no chown is needed.
{
  users.users.coru = {
    isNormalUser = true;
    uid = 1000;
    home = "/home/coru";
    shell = pkgs.zsh;
    description = "coru";
    initialPassword = "changeme";   # set a real one with `passwd` after boot

    # Mapping from the CachyOS groups. Arch-only groups that do NOT exist on
    # NixOS are marked; the rest are the genuine equivalents.
    extraGroups = [
      "wheel"             # sudo
      "video"             # /dev/dri, backlight
      "render"            # GPU compute (ROCm)
      "audio"
      "input"             # evdev; replaces Arch's "uinput"
      "lp"                # printing
      "scanner"           # sane / brscan5
      "networkmanager"    # replaces Arch's "network"
      "docker"
      "games"
      "i2c"               # ddcutil / openrgb
      "uucp"
      "storage"           # replaces Arch's "sys" for removable media
      "plugdev"
      "ydotool"           # created by programs.ydotool.enable
    ];
  };

  programs.zsh.enable = true;

  # /etc/zshrc would otherwise run compinit AND set up the default `prompt suse`
  # prompt. Both are wasted work here: zsh-autocomplete runs its own compinit
  # (see modules/shell.nix) and p10k owns the prompt. Dropping them is roughly a
  # third of interactive shell startup.
  programs.zsh.enableGlobalCompInit = false;
  programs.zsh.promptInit = "";

  security.sudo = {
    enable = true;
    # Only this one helper may run passwordless: streamcontroller-watchdog calls
    # it to power-cycle the Stream Deck's USB port.
    #
    # pkgs.usb-port-power-cycle is defined in the OVERLAY precisely so that this
    # rule and the watchdog wrapper resolve to the identical store path.
    # (See pkgs/scripts.nix and PACKAGING-LEDGER.md.)
    extraRules = [
      {
        users = [ "coru" ];
        commands = [
          {
            command = "${pkgs.usb-port-power-cycle}/bin/usb-port-power-cycle";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };
}
