{ config, lib, pkgs, ... }:

# Identity, locale, nix daemon settings, and the admin tool set.
{
  # Pick whatever you like -- CachyOS called itself "CachyOS".
  networking.hostName = "coru";

  time.timeZone = "America/Chicago";       # verified against the running system
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  system.stateVersion = "25.11";

  # ---- Nix ------------------------------------------------------------------
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "coru" ];
    # The store is writable by coru on the CachyOS install, but NixOS runs the
    # daemon as root. `sudo systemctl start nix-daemon` is what unblocks builds.
    auto-optimise-store = true;
  };

  # ---- Foreign binaries -----------------------------------------------------
  # REQUIRED, not optional: your ~/.local/bin AppImages, DaVinci Resolve, LM
  # Studio and anything else prebuilt expect an FHS dynamic loader that NixOS
  # does not provide. nix-ld supplies it.
  programs.nix-ld.enable = true;

  # AppImage support (no /usr/lib/libfuse on NixOS).
  programs.appimage.enable = true;

  # ---- Admin / system tooling ----------------------------------------------
  # Deliberately NOT the same list as home.packages: btop, htop, ripgrep, duf,
  # compsize, plocate, trash-cli, gum, unzip, p7zip and friends are already
  # managed per-user in modules/. Installing them here too would double them up.
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

  # OpenSSH is installed on CachyOS but is not enabled here on purpose: a
  # listening sshd should be a decision, not a default. To turn it on:
  #   services.openssh = { enable = true; settings.PasswordAuthentication = false; };
  #   networking.firewall.allowedTCPPorts = [ 22 ];
}
