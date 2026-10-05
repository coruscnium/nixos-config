{
  config,
  lib,
  pkgs,
  ...
}:

# Identity, locale, nix daemon settings, admin tooling.
{
  networking.hostName = "coru";

  # Feeds NAME/PRETTY_NAME in /etc/os-release. ID stays "nixos" so fastfetch keeps
  # its snowflake logo. Drop for stock NixOS.
  system.nixos.distroName = "CoruscOS";

  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  system.stateVersion = "25.11";

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [
      "root"
      "coru"
    ];
    auto-optimise-store = true;
  };

  # REQUIRED: prebuilt binaries (AppImages, Resolve, LM Studio) need an FHS
  # dynamic loader NixOS does not provide.
  programs.nix-ld.enable = true;
  programs.appimage.enable = true;

  # Admin/system tooling only -- btop, ripgrep, duf, ... are per-user in modules/.
  environment.systemPackages = with pkgs; [
    btrfs-progs
    nvme-cli
    smartmontools
    hdparm
    dmidecode
    pciutils
    usbutils
    hwinfo
    lm_sensors
    efibootmgr
    dosfstools
    exfatprogs
    ntfs3g
    gptfdisk
    rsync
    git
    vim
    curl
    wget
    jq
    file
    lsof
    strace
    psmisc
    tcpdump
    bind.dnsutils
    inetutils
    screen
    tmux
  ];

  # sshd is deliberately off: a listening sshd is a decision, not a default.
  #   services.openssh = { enable = true; settings.PasswordAuthentication = false; };
  #   networking.firewall.allowedTCPPorts = [ 22 ];
}
