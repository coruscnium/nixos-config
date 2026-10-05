# Migrating `coru` to Limine, and removing systemd-boot

`coru` is Limine-only. Nothing in this repo enables systemd-boot — but the
*stock* NixOS install that this config replaces used it, and NixOS has no
option to uninstall a bootloader it previously installed. Removing the
leftovers is a manual step.

**Order matters.** Do not delete systemd-boot until Limine has booted this
machine at least once. Until then, systemd-boot's firmware entry is your way
back if something goes wrong.

---

## 0. Why the first build needs extra flags

Two things conspire:

- `trusted-users = root` on the *current* system, so a non-root build cannot
  add a substituter. (`nixos/system.nix:17` adds `coru` to `trusted-users`, but
  that only takes effect after activation.)
- The nyx cache — `https://nyx-cache.chaotic.cx` — is not in `/etc/nix/nix.conf`
  yet, because `nix.settings.substituters` only lands there on activation.

Without the flag, `linuxPackages_cachyos` and `proton-cachyos` build **from
source**. Verified with `nix build --dry-run`: 32 derivations, including the
CachyOS kernel.

So pass the substituter explicitly, as root, on the first run:

```bash
NYX_KEY="nyx-cache.chaotic.cx:dJxTrgMC3V3cFfyIiBQDQorG6k1LsqurH/srpMSq7qk="

sudo env NIX_CONFIG="experimental-features = nix-command flakes" \
  nixos-rebuild build \
  --flake /home/coru/Projects/NixClone/nixos-config#coru \
  --option extra-substituters https://nyx-cache.chaotic.cx/ \
  --option extra-trusted-public-keys "$NYX_KEY"
```

Those keys are the real ones, read out of this config's evaluated
`nix.settings.trusted-public-keys`.

After the first successful switch, `coru` is a trusted user and the nyx cache is
in `nix.conf`, so later rebuilds need neither flag:

```bash
nixos-rebuild switch --flake /home/coru/Projects/NixClone/nixos-config#coru
```

---

## 1. Build, then test, then switch

`build` compiles everything without touching the running system. Always do it
first.

```bash
# ... the build command from step 0 ...

# Activate for this boot only -- a reboot reverts it.
sudo env NIX_CONFIG="experimental-features = nix-command flakes" \
  nixos-rebuild test \
  --flake /home/coru/Projects/NixClone/nixos-config#coru \
  --option extra-substituters https://nyx-cache.chaotic.cx/ \
  --option extra-trusted-public-keys "$NYX_KEY"

# Make it permanent.
sudo env NIX_CONFIG="experimental-features = nix-command flakes" \
  nixos-rebuild switch \
  --flake /home/coru/Projects/NixClone/nixos-config#coru \
  --option extra-substituters https://nyx-cache.chaotic.cx/ \
  --option extra-trusted-public-keys "$NYX_KEY"
```

## 2. What the switch writes

From `limine-install.py` in nixpkgs, with this config's settings
(`efiInstallAsRemovable = false`, `canTouchEfiVariables = true`):

| Artefact | Path |
| --- | --- |
| Limine EFI binary | `<ESP>/efi/limine/BOOTX64.EFI` |
| Limine config + kernels | `<ESP>/limine/limine.conf`, `<ESP>/limine/` |
| NVRAM entry | label `Limine`, loader `\efi\limine\BOOTX64.EFI` |

The installer greps `efibootmgr` for an existing `Limine` entry. If none exists
it runs `efibootmgr -c`, which places the new entry **first** in `BootOrder`. So
Limine becomes the default boot target and systemd-boot drops to second.

## 3. Reboot and verify before deleting anything

```bash
sudo efibootmgr -v
```

You should see a `Limine` entry first in `BootOrder`, and a `Linux Boot Manager`
entry (that one is systemd-boot) still present but later. Reboot and confirm the
Limine menu appears and boots.

**Do not continue until that works.**

## 4. Remove systemd-boot

Look first — the ESP is mounted at `/boot` and only root can read it:

```bash
sudo ls -laR /boot
```

Expected systemd-boot leftovers:

```
/boot/EFI/systemd/systemd-bootx64.efi     systemd-boot's own binary
/boot/EFI/BOOT/BOOTX64.EFI                its removable-media fallback
/boot/loader/loader.conf                  its configuration
/boot/loader/entries/*.conf               per-generation entries
```

Then remove them and the NVRAM entry:

```bash
sudo rm -rf /boot/EFI/systemd
sudo rm -rf /boot/loader
sudo rm -f  /boot/EFI/BOOT/BOOTX64.EFI

# Substitute the real boot number for the "Linux Boot Manager" entry.
sudo efibootmgr -b XXXX -B
```

`nixos-rebuild` will **not** recreate any of these, because systemd-boot is
disabled in this config.

### Caveat on `/boot/EFI/BOOT/BOOTX64.EFI`

That is the firmware's removable-media fallback path, not a NixOS-specific file.
Deleting it is correct for "systemd-boot gone", but it also removes the safety
net that boots *something* if the NVRAM entries are ever cleared (CMOS reset,
firmware update). With Limine at `\efi\limine\` and a healthy NVRAM entry that
is fine — just know that a wiped NVRAM means booting from a USB to repair.

## 5. Rollback

Boot generations live in the Limine menu. To revert the *last* switch without
rebooting:

```bash
sudo nixos-rebuild switch --rollback
```

If Limine itself misbehaves, systemd-boot's entry is still in the firmware boot
menu (until step 4) — pick it there.
