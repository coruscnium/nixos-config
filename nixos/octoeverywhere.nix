# =============================================================================
# OctoEverywhere Companion — Elegoo Centauri Carbon 2
#
# NixOS SYSTEM MODULE, not a home-manager module. Not imported by the flake yet.
# When the NixOS config exists:   imports = [ ./octoeverywhere.nix ];
#
# WHY THE CONTAINER: the old user unit ran a venv built by virtualenv against
# /usr/bin/python3.14, which cannot work on NixOS. Packaging natively would also
# need derivations for OctoEverywhere's two PyPI forks (octowebsocket_client,
# octoflatbuffers). The upstream image sidesteps both.
#
# HOW IT UPDATES: the image is fetched by dockerTools.pullImage into the Nix
# store, so its version is pinned in ./octoeverywhere-image.nix and changed by
# rerunning ./update-octoeverywhere.sh -- not by a floating `docker pull`.
# (`docker://` is not a supported flake input scheme; verified against Nix 2.35.)
#
# Replaces: ~/.config/systemd/user/octoeverywhere.service, ~/octoeverywhere-env
# =============================================================================

{ config, pkgs, lib, ... }:

let
  pin = import ./octoeverywhere-image.nix;

  # Docker-loadable tarball in the store: reproducible, no registry access at
  # unit start, and the digest is visible in the config.
  imageTarball = pkgs.dockerTools.pullImage {
    inherit (pin) imageName imageDigest finalImageName finalImageTag;
    inherit (pin) sha256;
  };
in
{
  virtualisation = {
    docker.enable = true;

    oci-containers = {
      backend = "docker";
      containers.octoeverywhere = {
        # BOTH are required. The oci-containers docs are explicit: `image` must
        # match the name and tag of the image inside the loaded file, because
        # that string is what is actually used to run the container. imageFile
        # just bypasses the registry pull.
        image = "${pin.finalImageName}:${pin.finalImageTag}";
        imageFile = imageTarball;

        # Come from the store, never from a registry.
        pull = "never";

        environment = {
          COMPANION_MODE = "elegoo_cc2";
          PRINTER_IP = "192.168.1.106";

          # The printer's access code is disabled, so this is the documented
          # default. IF YOU ENABLE IT ON THE PRINTER, move this out of here --
          # the Nix store is world-readable. Use a root-only env file:
          #   install -m600 /dev/null /etc/octoeverywhere.env
          #   environmentFiles = [ "/etc/octoeverywhere.env" ];
          ACCESS_CODE = "123456";

          # Combines all clients onto one connection to the printer so you do
          # not hit its connection limit. Needs port 1883 published.
          MQTT_RELAY_ENABLED = "true";
          MQTT_RELAY_REQUIRE_UPSTREAM_AUTH = "true";

          # Upstream's compose example says America/New_York; this machine is
          # America/Chicago. Only affects log timestamps.
          TZ = "America/Chicago";
        };

        # environmentFiles = [ "/etc/octoeverywhere.env" ];

        # Reuses the existing data directory so the account pairing and printer
        # state in octoeverywhere-store/ carry over. The container runs as root,
        # so new files it writes there will be root-owned.
        volumes = [ "/home/coru/.octoeverywhere-elegoo:/data" ];

        ports = [ "1883:1883" ];

        # If LAN clients cannot reach the relay, or the printer is not
        # discovered, switch to host networking:
        # extraOptions = [ "--network=host" ];
      };
    };
  };

  # networking.firewall.allowedTCPPorts = [ 1883 ];
}
