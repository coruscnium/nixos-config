{ pkgs, ... }:

{
  hardware.enableRedistributableFirmware = true;
  hardware.cpu.amd.updateMicrocode = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # SOF firmware for the AMD audio DSP on Strix Point.
  hardware.firmware = [ pkgs.sof-firmware ];

  # Rotation/tablet-mode sensor for the 360° convertible.
  environment.systemPackages = [ pkgs.iio-sensor-proxy ];
}
