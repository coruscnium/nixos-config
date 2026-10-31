# Flatpak policy that is a property of the *app*, not of the machine. The app
# lists themselves are per-host (hosts/<name>/flatpaks.nix) -- what a sandboxed
# app needs to reach is not.
{
  services.flatpak = {
    # Sober (Roblox) comes up a black window without the Discord IPC socket and
    # an input device. Declared here once; both hosts install the app.
    overrides.settings."org.vinegarhq.Sober".Context = {
      filesystems = [
        "xdg-run/app/com.discordapp.Discord:create"
        "xdg-run/discord-ipc-0"
      ];
      devices = [ "input" ];
    };

    # Weekly upgrade timer. Policy, not per-host: any host with flatpak apps
    # wants them current, and nix-flatpak has no per-app scope.
    update.auto.enable = true;
  };
}
