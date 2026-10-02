{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    git
    vim
    btop
    ripgrep
    fd
    wget
    curl
    unzip
    pciutils
    usbutils
    lm_sensors
    brightnessctl
    inxi
  ];
}
