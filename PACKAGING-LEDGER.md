# Packaging ledger

What is deliberately *not* in the category modules, and why. The point of this
file is that nothing gets forgotten and nothing gets installed twice.

## How updates work

| Thing | Update mechanism |
|---|---|
| nixpkgs, home-manager, chaotic-nyx, NUR | `nix flake update` (bumps flake.lock) |
| Cherry Studio | `nix run nixpkgs#nvfetcher` — re-resolves `_sources/generated.nix` |
| NUR packages (e.g. `forkprince.nuvio`) | ride the NUR input, so `nix flake update` |
| OctoEverywhere container image | `./nixos/update-octoeverywhere.sh --rebuild` |
| `reigntweak` | bump `url` + `hash` in `pkgs/default.nix` (upstream has no releases API) |
| `cheatengine` .exe | re-vendor the binary into `pkgs/` |
| `quadcast2s` | re-copy the project over `vendor/quadcast2s` (exclude `.git`, `.venv`, `dist`, `build`, `*.egg-info`) |
| `themes/` (Carl) | manual — pling.com serves a bot challenge, so there is no fetchable URL |
| Flatpaks | `flatpak update` |
| AppImages | manual (that is the cost of being an AppImage) |

## A. Becomes a NixOS system module (not a home package)

    plasma6            -> services.desktopManager.plasma6.enable
    sddm               -> services.displayManager.sddm.enable
    power-profiles     -> services.power-profiles-daemon.enable
    zram               -> zramSwap.enable
    limine             -> boot.loader.limine.enable      (maxGenerations matters:
                          the 2G ESP has ~482M free)
    pipewire           -> services.pipewire.enable
    networkmanager     -> networking.networkmanager.enable
    bluetooth/blueman  -> hardware.bluetooth.enable + programs.blueman
    printing           -> services.printing.enable
    brscan5            -> Brother scanner driver/udev (unfree .deb repack)
    v4l2loopback       -> boot.kernelModules=["v4l2loopback"] +
                          boot.extraModulePackages=[...v4l2loopback]
    kdePackages.kscreen-> supplies kscreen-doctor
    steam/mangohud/gamemode -> programs.steam / programs.mangohud / programs.gamemode
    ollama             -> services.ollama.enable
    syncthing          -> services.syncthing.enable
    ydotool            -> programs.ydotool.enable
    snapper            -> services.snapper.configs  (generations cover the
                          system; snapshots are still needed for data)
    rocm/hip/opencl    -> hardware.graphics + rocmPackages
    windows-drives     -> /mnt/ssd2 and /mnt/ssd3 must keep their exact paths
                          or the Steam libraries break

## B. Available from other repositories

**chaotic-nyx** (`github:chaotic-cx/nyx/nyxpkgs-unstable`) — the CachyOS bridge.
Provides the `linux-cachyos` family with per-variant configs including
**znver4** (this machine's target), `nvidia-cachyos`, `proton-bin` with the
CachyOS manifests, `ananicy-cpp-rules`, `bpftools-full`, `low-latency-layer`,
`luxtorpeda`, `vulkan-versioned`, and `*-git` builds.
Confirmed present in the merged pkgs: `proton-cachyos`, `linuxPackages_cachyos`.
Caveat: nyx issue #1158 — `linuxPackages_cachyos` was broken against *stable*
nixpkgs. This config is on nixos-unstable, which is the supported case.

**NUR** (`github:nix-community/NUR`) — verified by grepping the complete
`nur-combined` tree (57,558 paths, untruncated):
`mio.zen-browser`, `cmdorexe.waterfox`, `vladexa.proton-cachyos`,
`forkprince.nuvio` (in use), `ivar.ryujinx`.
NUR does **not** merge into pkgs — use `pkgs.nur.repos.<user>.<pkg>`.
It is user-contributed and unvetted: `ivar.ryujinx` currently **fails to
evaluate** because it needs `dotnet-sdk_5`, which nixpkgs removed. Probe each
package individually before trusting it.

**Not found in nixpkgs, nyx or NUR:** windscribe, cover-thumbnailer, mocktail,
weekbox, hd2arsenal, amethyst-mod-manager, cordial, silex-desktop, lobehub,
anvil-organizer.

**Not packages at all** — runtime artifacts:
- `kwin-karousel`, `kwin-effects-better-blur-dx` -> KWin scripts, installed
  into `~/.local/share/kwin/scripts`
- `spicetify-marketplace` -> installed by `spicetify-cli` into `~/.config/spicetify`
- `wallpaper-engine-kde-plugin`, `plasma6-wallpapers-smart-video-wallpaper-reborn`
  -> CMake/QML projects, buildable from source if wanted
- `btrfsmaintenance` -> covered natively by `services.btrfs.autoScrub`

## C. Custom packages written for this config

    quadcast2s   -> pkgs/default.nix. Built from the checkout via the
                    `quadcast2sSrc` flake input (`flake = false` path input, so
                    pure eval works and the space in the path is percent-encoded).
                    Ships the wheel, udev rule, desktop entry, icon and docs.
    reigntweak   -> pkgs/default.nix. Fetched from the upstream GitHub release;
                    the hash matches the binary in ~/.local/bin byte for byte.
    cheatengine  -> pkgs/default.nix. Vendored .exe plus a protontricks-launch
                    wrapper that replaces cehelper.sh and the Proton.SH script.
    octoeverywhere -> nixos/octoeverywhere.nix. Official container image, pinned
                    by digest via dockerTools.pullImage.
    cherry-studio -> pkgs/cherry-studio.nix. nixpkgs has it, but at 1.9.11
                    against our 2.1.4, and the 2.x bump there pins an insecure
                    Electron. We wrap upstream's AppImage with the version and
                    hash resolved by nvfetcher (nvfetcher.toml -> _sources/).
                    This is also the harness this config is developed in.

                    nvfetcher CANNOT replace the rest of the vendoring:
                      themes/             pling.com serves a bot challenge.
                      pkgs/cheatengine-*  Cheat Engine's GitHub releases carry
                                          no binary assets; cheatengine.org
                                          direct links are fragile.
                      scripts/            our own code.
                      vendor/quadcast2s   our own project, no remote yet. Once
                                          it has one, add a [quadcast2s] src.git
                                          entry and drop the vendored copy.

    windscribe   -> NOT PACKAGED, deferred. It is not "just an unpacked .deb":
                    Windscribe publishes its own Arch package, and the payload is
                    a root helper daemon + four more daemons + a systemd system
                    service + a system user/group + a setgid GUI + scripts that
                    take over resolv.conf / systemd-resolved / NetworkManager /
                    nftables + a self-updater. On NixOS the setgid step is
                    impossible (immutable store) and the self-updater fights
                    immutability. Options: (a) native WireGuard configs,
                    (b) ~60 lines of Nix + a system service, (c) keep it outside
                    Nix. Revisit later.

## D. Keep as AppImage in ~/.local/bin (inside $HOME, survives)

Requires `programs.appimage.enable = true;` — NixOS has no `/usr/lib/libfuse*`.
AmethystModManager, WeekBox, HD2Arsenal (your mod managers), bluestar,
elegooslicer, orcaslicer, F-Chat.Horizon, Cordial, Root, Mocktail.
Nuvio is no longer here — it comes from NUR now.

## E. Keep as Flatpak

    cherry-studio -> com.cherry_ai.CherryStudio  (nixpkgs is on 1.9.11, you run
                     2.1.4 — a full major version behind)
    Sober         -> org.vinegarhq.Sober  (Roblox; Flatpak-only)
    shelly        -> Flatpak-only, and you note it is ALPM/Arch-only
    plus your other 12 existing Flatpaks

## F. Deliberate opt-ins

    ventoy            -> nixpkgs marks ventoy insecure. To accept, add to the
                         `config` block in flake.nix:
                         permittedInsecurePackages = [ "ventoy-1.1.17" ];
    adwaita-qt / qgnomeplatform -> exist, but Kvantum + qt6ct already cover
                         Qt theming on Plasma.
    chromium Widevine -> do NOT use `chromium.override { enableWideVine = true; }`.
                         Changing an argument makes it a cache miss, i.e. a full
                         Chromium source build. brave-origin's .deb already
                         carries Widevine.

## G. Excluded on your instruction

    lock-displays.service, shelly-notifications.service (ALPM-only),
    pwctl-chain@.service (generated by PipeWire Controller), hyphen Hyprland
    remnants (hyprsunset, xdg-desktop-portal-hyprland, hyprpolkitagent), the
    voxtype/deepfilternet experiment, scrcpy/qtscrcpy.
