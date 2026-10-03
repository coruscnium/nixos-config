# Pinned OctoEverywhere container image.
#
# Regenerate with:   ./nixos/update-octoeverywhere.sh
# Then rebuild. `imageDigest` identifies the manifest; `sha256` is the hash of
# the docker-loadable tarball that dockerTools.pullImage produces, which is why
# the image lands in the Nix store instead of being pulled at runtime.
{
  imageName = "octoeverywhere/octoeverywhere";
  imageDigest = "sha256:15a0ed96f3d203df1ff0d96c23548b055549f32c8ea1533c554609f78d4d1045";
  sha256 = "sha256-FdOjb9AzkPdvnCmWJGEMSduHhb8mKVvaYjKPfb7RFNQ=";
  finalImageName = "octoeverywhere/octoeverywhere";
  finalImageTag = "latest";
}
