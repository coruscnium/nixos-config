#!/usr/bin/env bash
# Refresh the pinned OctoEverywhere image to the newest upstream release.
#
#   ./nixos/update-octoeverywhere.sh            # rewrite the pin only
#   ./nixos/update-octoeverywhere.sh --rebuild  # rewrite, then nixos-rebuild
#
# This is the container equivalent of `nix flake update`: Nix cannot resolve a
# `docker://` flake input (verified unsupported), so the digest pair is kept in
# octoeverywhere-image.nix and rewritten here by nix-prefetch-docker.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pin="$here/octoeverywhere-image.nix"

echo "==> resolving octoeverywhere/octoeverywhere:latest"
json="$(nix --extra-experimental-features 'nix-command flakes' run nixpkgs#nix-prefetch-docker -- \
  --image-name octoeverywhere/octoeverywhere \
  --image-tag latest \
  --final-image-name octoeverywhere/octoeverywhere \
  --final-image-tag latest)"

python3 -c '
import json, sys, pathlib
d = json.loads(sys.argv[1])
pathlib.Path(sys.argv[2]).write_text(
    "# Pinned OctoEverywhere image -- regenerate with ./nixos/update-octoeverywhere.sh.\n"
    "{\n"
    f"  imageName = \"{d['imageName']}\";\n"
    f"  imageDigest = \"{d['imageDigest']}\";\n"
    f"  sha256 = \"{d['hash']}\";\n"
    f"  finalImageName = \"{d['finalImageName']}\";\n"
    f"  finalImageTag = \"{d['finalImageTag']}\";\n"
    "}\n"
)
print("wrote", sys.argv[2])
print("  digest:", d["imageDigest"])
' "$json" "$pin"

if [ "${1:-}" = "--rebuild" ]; then
  echo "==> nixos-rebuild switch"
  exec nixos-rebuild switch
fi
echo "==> now run: sudo nixos-rebuild switch"
