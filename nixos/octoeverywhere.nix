# OctoEverywhere Companion — Elegoo Centauri Carbon 2
#
# NixOS SYSTEM MODULE (imported by nixos/default.nix). The image is pinned in
# ./octoeverywhere-image.nix and fetched at build time, so there is no registry
# pull at unit start. Replaces the old ~/.config/systemd/user unit.

{
  config,
  pkgs,
  lib,
  ...
}:

let
  pin = import ./octoeverywhere-image.nix;

  imageTarball = pkgs.dockerTools.pullImage {
    inherit (pin)
      imageName
      imageDigest
      finalImageName
      finalImageTag
      ;
    inherit (pin) sha256;
  };
in
{
  virtualisation = {
    # docker.enable is set in nixos/services.nix, not here.
    oci-containers = {
      backend = "docker";
      containers.octoeverywhere = {
        # image must match the name:tag inside the loaded file; imageFile
        # bypasses the registry pull.
        image = "${pin.finalImageName}:${pin.finalImageTag}";
        imageFile = imageTarball;
        pull = "never";

        environment = {
          COMPANION_MODE = "elegoo_cc2";
          PRINTER_IP = "192.168.1.106";

          # The printer has its access code disabled, so this is the documented
          # default. Enable it on the printer and this must move to a root-only
          # env file -- the Nix store is world-readable.
          ACCESS_CODE = "123456";

          MQTT_RELAY_ENABLED = "true";
          MQTT_RELAY_REQUIRE_UPSTREAM_AUTH = "true";
          TZ = "America/Chicago";
        };

        # Reuses the existing data dir so the account pairing carries over. The
        # container runs as root, so files it writes are root-owned.
        volumes = [ "/home/coru/.octoeverywhere-elegoo:/data" ];
        ports = [ "1883:1883" ];
      };
    };
  };
}
