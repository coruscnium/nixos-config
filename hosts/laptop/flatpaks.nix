# The laptop's flatpak set. One app: Sober is the Roblox client and ships only
# as a Flatpak. Enable, the flathub default remote, and Sober's sandbox override
# are all shared policy (nixos/services.nix, nixos/flatpaks.nix).
{
  services.flatpak.packages = [ "org.vinegarhq.Sober" ];
}
