{
  config,
  lib,
  pkgs,
  ...
}:

# coru, uid 1000 -- matching the old CachyOS account so /home/coru ownership is
# already correct.
{
  users.users.coru = {
    isNormalUser = true;
    uid = 1000;
    home = "/home/coru";
    shell = pkgs.zsh;
    description = "coru";
    initialPassword = "changeme"; # set a real one with `passwd` after boot

    extraGroups = [
      "wheel"
      "video"
      "render"
      "audio"
      "input"
      "lp"
      "scanner"
      "networkmanager"
      "docker"
      "games"
      "i2c"
      "uucp"
      "storage"
      "plugdev"
      "ydotool"
    ];
  };

  programs.zsh.enable = true;

  # /etc/zshrc would otherwise run a duplicate compinit and the dead `prompt suse`
  # prompt (zsh-autocomplete and p10k own both).
  programs.zsh.enableGlobalCompInit = false;
  programs.zsh.promptInit = "";

  security.sudo = {
    enable = true;
    # sudoedit opens micro, by absolute store path so it can't fall back to a
    # system editor (nano/vim are gone) or depend on sudo's secure_path.
    extraConfig = ''
      Defaults editor = ${pkgs.micro}/bin/micro
    '';
    # Only this one helper is passwordless. pkgs.usb-port-power-cycle is defined
    # in the overlay so this rule and the watchdog wrapper pin the same path.
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
