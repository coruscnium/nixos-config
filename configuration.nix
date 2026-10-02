# Core system definition. Machine-specific tuning lives in ./modules.
{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./modules/nix.nix
    ./modules/boot.nix
    ./modules/kernel.nix
    ./modules/hardware.nix
    ./modules/nvidia.nix
    ./modules/asus.nix
    ./modules/desktop.nix
    ./modules/networking.nix
    ./modules/power.nix
    ./modules/packages.nix
  ];

  networking.hostName = "nixos";

  time.timeZone = "America/Chicago";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  users.users.coru = {
    isNormalUser = true;
    description = "Coru";
    extraGroups = [ "networkmanager" "wheel" "video" "audio" ];
    packages = with pkgs; [ kdePackages.kate ];
  };

  programs.firefox.enable = true;
  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  services.printing.enable = true;

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  services.pulseaudio.enable = false;

  system.stateVersion = "26.05";
}
