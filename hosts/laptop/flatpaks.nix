# The laptop's flatpak set. One app: Sober is the Roblox client and ships only
# as a Flatpak. `services.flatpak.enable` and the flathub default remote are
# shared policy (nixos/services.nix), so neither is repeated here.
{
  services.flatpak = {
    packages = [ "org.vinegarhq.Sober" ];

    # Same reason as the desktop (hosts/coru/flatpaks.nix): Sober needs the Discord
    # IPC socket + an input device or it comes up a black window.
    overrides.settings."org.vinegarhq.Sober".Context = {
      filesystems = [
        "xdg-run/app/com.discordapp.Discord:create"
        "xdg-run/discord-ipc-0"
      ];
      devices = [ "input" ];
    };
  };
}
