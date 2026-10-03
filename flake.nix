{
  description = "Home Manager configuration of coru";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # quadcast2s is VENDORED at ./vendor/quadcast2s rather than being a
    # `path:` flake input. The old input pointed at an absolute path containing
    # a space ("AI Folder"), which meant the flake could only ever evaluate on
    # this machine -- fatal after a wipe. Vendoring makes the repo self-contained.
    #
    # To update it, re-copy the project over vendor/quadcast2s, EXCLUDING
    # .git, .venv, dist, build and *.egg-info. Those artifacts are what made the
    # build fail the first time (two wheels declaring the same console script).

    # Chaotic-Nyx — the CachyOS-on-NixOS bridge. Provides linux-cachyos
    # (incl. the znver4 config that matches this machine), nvidia-cachyos,
    # proton-bin with the CachyOS manifests, ananicy-cpp-rules, bpftools-full,
    # and the *-git package variants.
    # Use the nyxpkgs-* branches: they are the ones meant to follow nixpkgs.
    chaotic = {
      url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Nix User Repository. User-contributed and unvetted — pin it, and prefer a
    # dedicated flake where one exists. Consumed as pkgs.nur.repos.<user>.<pkg>.
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative KDE/Plasma settings. It applies values with kwriteconfig at
    # activation, which is exactly why it is needed: kdeglobals / kwinrc /
    # plasmarc are rewritten by KDE whenever a setting changes, so they cannot
    # be home.file symlinks into the read-only store.
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs =
    { nixpkgs, home-manager, chaotic, nur, plasma-manager, ... }:
    let
      system = "x86_64-linux";

      # NOTE: because we pass `pkgs` explicitly to homeManagerConfiguration,
      # home-manager IGNORES its own `nixpkgs.config` option. Any package
      # config (unfree, codecs, overlays) has to live HERE.
      # This is also why ~/.config/nixpkgs/config.nix is not enough on its own:
      # we fold it in here so it works with flakes.
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          (import ./pkgs { quadcast2sSrc = ./vendor/quadcast2s; })
          # nyx merges its packages into pkgs (e.g. proton-cachyos, and the
          # linuxPackages_cachyos kernel set for the NixOS side).
          chaotic.overlays.default
          # NUR only adds pkgs.nur.repos.<user>.<pkg>; it does not merge
          # packages to the top level.
          nur.overlays.default
        ];
        config = {
          allowUnfree = true;
        };
      };
    in
    {
      homeConfigurations."coru" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        # Specify your home configuration modules here, for example,
        # the path to your home.nix.
        modules = [
          ./home.nix
          ./modules
          # plasma-manager: applies KDE settings with kwriteconfig, so
          # kdeglobals/kwinrc/plasmarc stay writable.
          plasma-manager.homeModules.plasma-manager
        ];

        # Optionally use extraSpecialArgs
        # to pass through arguments to home.nix
      };

      # =======================================================================
      # NixOS SYSTEM
      #
      # The target of the migration. Build/eval with:
      #   nixos-rebuild build --flake .#coru
      #
      # This does NOT affect the CachyOS install until you boot it. The
      # standalone homeConfigurations."coru" above keeps working on CachyOS, and
      # both targets import the SAME ./home.nix + ./modules, so the two stay in
      # sync while you migrate.
      # =======================================================================
      nixosConfigurations =
        let
          # Shared by every NixOS target, so the desktop/laptop/USB builds can
          # never drift apart.
          common = [
            home-manager.nixosModules.home-manager

            # Enables https://nyx-cache.chaotic.cx. WITHOUT THIS, every nyx
            # package -- including the CachyOS KERNEL and proton-cachyos -- is
            # built from source instead of downloaded. Verified: both are 404 on
            # cache.nixos.org and 200 on nyx-cache.
            #
            # nyx's README warns the module must be enabled and the SYSTEM BUILT
            # before you add nyx derivations, which is exactly the order here.
            chaotic.nixosModules.nyx-cache

            {
              # The same overlays the standalone config uses. Passing them here
              # is what guarantees identical store paths -- notably
              # pkgs.usb-port-power-cycle, which the sudoers rule in
              # nixos/users.nix and the watchdog wrapper must agree on exactly.
              nixpkgs.overlays = [
                (import ./pkgs { quadcast2sSrc = ./vendor/quadcast2s; })
                chaotic.overlays.default
                nur.overlays.default
              ];
              nixpkgs.config.allowUnfree = true;

              home-manager = {
                # Build the user's packages with the system's pkgs (so the
                # overlays above apply).
                useGlobalPkgs = true;
                # Install them into /etc/profiles/per-user/coru rather than
                # imperatively managing ~/.nix-profile.
                useUserPackages = true;
                # Your ~/.local/bin scripts and gtk css are REAL files right
                # now; home-manager refuses to clobber, so it moves them aside
                # instead of aborting the activation.
                backupFileExtension = "hm-backup";

                users.coru.imports = [
                  ./home.nix
                  ./modules
                  plasma-manager.homeModules.plasma-manager
                ];
              };
            }
          ];

          mkNixos = extra: nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [ ./nixos ] ++ extra ++ common;
          };
        in
        {
          # The real machine.
          coru = mkNixos [ ];

          # The same system, configured to live entirely on a removable device
          # (see nixos/usb.nix). Build with nixos-generators, or install it with
          # `nixos-install --root /mnt/usb --flake ...#coru-usb`.
          coru-usb = mkNixos [ ./nixos/usb.nix ];

          # The full system as a live squashfs image, for a stick too small for
          # a real install (see nixos/iso.nix).
          coru-iso = mkNixos [ ./nixos/iso.nix ];
        };
    };
}
